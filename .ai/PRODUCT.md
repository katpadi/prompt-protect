# Prompt Protect

## Overview

Prompt Protect is a **drop-in safety proxy for LLM calls**.

It sits between your backend and LLM providers to detect sensitive data, assess risk, sanitize or block requests, and scan responses — before anything leaves your infrastructure.

No UI required. No major refactor. Just point your existing LLM client at it.

---

## Problem

Teams want to use LLMs in production, but:

- Engineers routinely send raw data — PII, credentials, internal documents — in prompts
- No visibility into what is actually being sent to the LLM provider
- Risk of accidental data leakage to third-party APIs
- Existing tools are either too low-level (PII libraries — language-specific, require code changes) or too heavy (enterprise DLP gateways — expensive, not LLM-aware, SaaS-only)

---

## Solution

Prompt Protect acts as a **pre-flight + post-flight safety layer** for LLM requests.

```
App → Prompt Protect → LLM Provider
```

Every request goes through a pipeline:

1. **Normalise** — strip encoding tricks (Unicode obfuscation, zero-width chars, Base64) so detectors can't be bypassed
2. **Detect** — scan message content for sensitive data using regex + NER
3. **Score** — assign a risk level with a full explanation of what fired and why
4. **Enforce** — apply policy: allow, sanitize, or block
5. **Forward** — send the (possibly masked) request to the LLM provider
6. **Scan response** — inspect the LLM's reply for leaked PII before returning it to the client
7. **Explain** — attach a structured audit explanation to every response

---

## What Makes It Different

| | Most tools | Prompt Protect |
|---|---|---|
| Scores fields in isolation | Yes | No — combination + mosaic risk |
| Scans LLM responses | Rarely | Yes — both directions |
| Encoding evasion | 100% bypass | Normalised before detection |
| Structured audit explanation | No | Yes — every response |
| Placeholder masking | Breaks on rephrase | Typed tokens, stable |
| Self-hostable | Sometimes | Yes — single `docker compose up` |
| Language | SDK-specific | Any — change one URL |

---

## Key Features

### 1. Drop-in Proxy
- OpenAI-compatible endpoint (`/v1/chat/completions`)
- Change base URL only — no code changes required
- Language agnostic

### 2. Encoding/Obfuscation Normalizer
Runs before any detector. Three passes:
- Unicode NFKC — collapses fullwidth, halfwidth, mathematical Unicode variants to ASCII (`ｊｏｈｎ` → `john`)
- Zero-width character stripping — removes invisible characters injected to break regex patterns
- Base64 decode-and-rescan — detects and decodes Base64-encoded sensitive values before detection runs

Without this, all regex and NER detectors can be bypassed 100% of the time via encoding tricks (documented by Palo Alto Unit 42 research across every major guardrail).

### 3. Hybrid Detection Engine

**Layer 1 — Regex (structured PII):**

| Detector | Type | Examples |
|---|---|---|
| EmailDetector | `:email` | john@example.com |
| PhoneDetector | `:phone` | 415-555-0192 |
| AddressDetector | `:address` | 123 Main St |
| IdDetector | `:id` | SSN, credit card, passport, IBAN, AU TFN, AU Medicare |
| IpDetector | `:ip` | 192.168.1.1, ::1 |
| SecretDetector | `:secret` | API keys, Bearer tokens, AWS keys, hardcoded passwords |
| DobDetector | `:dob` | DOB: 15/03/1985 (keyword-required) |

**Layer 2 — NER via spaCy sidecar:**

| Type | Examples |
|---|---|
| `:person` | Jane Smith, Dr. John K., Kat P. |
| `:org` | Acme Corp, Google |
| `:location` | Sydney, United Kingdom |

Falls back to regex-based PersonDetector if sidecar is unavailable.

### 4. Risk Engine (Combination-Aware)

| Rule | Risk | Fires when |
|---|---|---|
| `critical_type` | HIGH | Any `:id` or `:secret` |
| `identity_reconstruction` | HIGH | `:dob` + `:person` |
| `mosaic_profile` | HIGH | 3+ of: person, org, location, email, phone, dob |
| `multiple_sensitive` | HIGH | 2+ sensitive types |
| `single_sensitive` | MEDIUM | One sensitive type |
| `person_with_context` | MEDIUM | `:person` + `:org` or `:location` |
| `person_only` | LOW | Only a person name |
| `clean` | LOW | Nothing detected |

Mosaic risk is unique to Prompt Protect — every competitor scores fields in isolation.

### 5. Policy Engine
- `allow` → forward as-is
- `sanitize` → mask sensitive data, forward masked payload
- `block` → reject, LLM never called
- Configurable per risk level via env vars

### 6. Stable Placeholder Masking
```
Jane Smith       → [PERSON_1]
john@example.com → [EMAIL_1]
555-123-4567     → [PHONE_1]
123-45-6789      → [ID_1]
192.168.1.1      → [IP_1]
sk-proj-abc...   → [SECRET_1]
DOB: 01/15/1990  → [DOB_1]
Acme Corp        → [ORG_1]
Sydney           → [LOCATION_1]
```

Typed placeholders remain stable even if the LLM rephrases surrounding text — unlike Presidio and LLM Guard which fail when output is paraphrased.

### 7. Bidirectional Scanning
- **Request scan** — prompt is inspected before forwarding
- **Response scan** — LLM reply is inspected before returning to client
- Response headers: `X-Prompt-Protect-Response-Risk-Level`, `X-Prompt-Protect-Response-Detected-Types`, `X-Prompt-Protect-Response-Masked`

### 8. Structured Audit Explanation
Every response includes a `risk_explanation` object:
```json
{
  "rule": "mosaic_profile",
  "reason": "3 profile fragments (person, org, location) combine into a complete identity profile.",
  "triggered_by": ["person", "org", "location"],
  "detected_values": ["Jane Smith", "Acme Corp", "Sydney"],
  "threshold": 3
}
```
No other proxy tool provides structured, machine-readable explanations of risk decisions. Directly addresses GDPR Article 22 explainability requirements.

### 9. Transparency Headers
```
X-Prompt-Protect-Risk-Level
X-Prompt-Protect-Action
X-Prompt-Protect-Detected-Types
X-Prompt-Protect-Masked
X-Prompt-Protect-Response-Risk-Level
X-Prompt-Protect-Response-Detected-Types
X-Prompt-Protect-Response-Masked
```

### 10. Dry Run Mode
`"dry_run": true` — runs the full pipeline without forwarding. Returns findings, risk level, explanation, masked text, and placeholder mapping. Powers the playground. No API key required.

### 11. Playground
`/playground.html` — 14 pre-built scenarios across LOW / MEDIUM / HIGH risk, inline results, no OpenAI key needed.

### 12. API Docs
Swagger UI at `/api-docs`.

### 13. Stateless + Self-hosted
- No database required
- No raw prompt persistence
- Single command: `docker compose up`

---

## Tech Stack

- Ruby 3.4 / Rails 8 (API mode)
- Python 3.12 / FastAPI / spaCy `en_core_web_sm` (NER sidecar)
  - Opt-in: `en_core_web_trf` (transformer-based, higher accuracy, ~2–3 GB image)
- Faraday (HTTP client)
- Docker + docker compose
- rswag (OpenAPI 3.0 / Swagger UI)

---

## Roadmap

### V3 (planned)
- VehicleDetector — VIN and registration plate detection
- Multi-provider support (Anthropic, Cohere, etc.)
- Multilingual spaCy models
- Data exfiltration intent detection — flag prompts that *request* PII extraction even without containing any

### Future (unplanned)
- Multi-turn session risk accumulation
- User-defined custom entity types (GLiNER)
- Per-tenant policy configuration
- gRPC transport for spaCy sidecar
