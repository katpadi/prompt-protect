# Design Document — Prompt Protect

## Architecture Overview

```
Backend Application
       ↓
Prompt Protect API (Rails)
  ├── TextNormalizer        — encoding evasion prevention
  ├── DetectionEngine       — regex + NER
  ├── RiskEngine            — combination-aware scoring + audit explanation
  ├── PolicyEngine          — allow / sanitize / block
  ├── MaskingEngine         — typed placeholder substitution
  └── Forwarder             — HTTP to LLM provider
       ↓   ↘
       ↓   spaCy NER Sidecar (Python/FastAPI) — internal only
       ↓
LLM Provider (OpenAI or compatible)
       ↓
Response scanning (same pipeline, reverse direction)
```

---

## Request Flow

```
POST /v1/chat/completions
       ↓
Parse request body
       ↓
Extract messages[].content
       ↓
TextNormalizer (per message)
  ├── Unicode NFKC normalisation
  ├── Zero-width character stripping
  └── Base64 decode-and-rescan
       ↓
Detection Engine (per message)
  ├── Regex detectors (EMAIL, PHONE, ADDRESS, ID, IP, SECRET, DOB)
  └── NER detector → spaCy sidecar → PERSON, ORG, LOCATION
       ↓
Risk Engine → Result { level, explanation }
       ↓
Policy Engine → allow / sanitize / block
       ↓
  ┌────────────────────────────────────────┐
  │ dry_run: true? → return analysis only  │
  └────────────────────────────────────────┘
       ↓
  block    → 422 (LLM never called) + risk_explanation
  sanitize → MaskingEngine → masked payload → Forwarder
  allow    → Forwarder
       ↓
LLM Provider
       ↓
Response scanning
  ├── DetectionEngine on choices[].message.content
  ├── MaskingEngine if findings present
  └── Set X-Prompt-Protect-Response-* headers
       ↓
Attach risk_explanation to response body
       ↓
Return to client
```

---

## Core Components

### TextNormalizer (`PromptProtect::TextNormalizer`)
Runs before every detection pass. Three normalisation layers:

1. **Unicode NFKC** — `String#unicode_normalize(:nfkc)`. Collapses fullwidth (`ｊｏｈｎ`), halfwidth, mathematical bold (`𝐣𝐨𝐡𝐧`), and decorative variants into ASCII. Single call handles the vast majority of lookalike attacks.

2. **Zero-width stripping** — removes U+200B, U+200C, U+200D, U+00AD, U+FEFF, U+2060. These are invisible in all UIs and break every regex by inserting hidden characters between matched chars.

3. **Base64 decode-and-rescan** — regex finds blobs matching `[A-Za-z0-9+/\-_]{20,}`. Each candidate is decoded; if the result is >80% printable ASCII it replaces the blob in-place. Downstream detectors then see the original sensitive value.

Without this layer, all regex and NER detectors can be evaded 100% of the time via encoding tricks (Palo Alto Unit 42, 2025).

### Detection Engine (`PromptProtect::DetectionEngine`)
- Runs `TextNormalizer` on input text first
- Runs all regex detectors then the NER detector
- Selects `NerDetector` or `PersonDetector` based on `SPACY_ENABLED` env var
- Returns findings sorted by `:start` position

### Regex Detectors
Each inherits from `BaseDetector`, uses `scan_findings(pattern, type)`:

| Detector | Type | Strategy |
|---|---|---|
| `EmailDetector` | `:email` | Standard email regex |
| `PhoneDetector` | `:phone` | US + international formats |
| `AddressDetector` | `:address` | Street address patterns |
| `IdDetector` | `:id` | SSN, credit card, passport (keyword), IBAN (keyword), AU TFN (keyword), AU Medicare (keyword) |
| `IpDetector` | `:ip` | IPv4 (octet-validated), IPv6 (full + compressed) |
| `SecretDetector` | `:secret` | Bearer tokens, API key assignments, OpenAI sk- keys, AWS AKIA keys, password assignments |
| `DobDetector` | `:dob` | Keyword-required: `DOB:`, `date of birth:`, `born on`, numeric + ISO + written-month formats |

Keyword-gating is applied to ambiguous formats (IBAN, TFN, Medicare, Passport, DOB) to prevent false positives on bare dates, long numbers, and alphanumeric codes.

### NER Detector (`Detectors::NerDetector`)
- Calls spaCy sidecar via `POST /detect`
- `LABEL_MAP`: `PERSON → :person`, `ORG → :org`, `GPE → :location`, `LOC → :location`
- Falls back to `PersonDetector` on any `Faraday::Error`
- Timeouts: 5s total, 2s open

### Person Detector (`Detectors::PersonDetector`)
- Fallback when spaCy is disabled or unavailable
- Handles honorifics, full names, initial pairs (Kat P., J. Smith)
- `NON_NAME_WORDS` exclusion set suppresses legal/contract false positives

### Risk Engine (`PromptProtect::RiskEngine`)
Returns `Result { level:, explanation: }` — not just a symbol.

Decision tree (evaluated in order):

| Rule | Level | Condition |
|---|---|---|
| `critical_type` | HIGH | Any `:id` or `:secret` |
| `identity_reconstruction` | HIGH | `:dob` + `:person` |
| `mosaic_profile` | HIGH | 3+ of `MOSAIC_TYPES` (person/org/location/email/phone/dob) |
| `multiple_sensitive` | HIGH | 2+ `SENSITIVE_TYPES` (email/phone/address/ip/dob) |
| `single_sensitive` | MEDIUM | 1 sensitive type |
| `person_with_context` | MEDIUM | `:person` + `:org` or `:location` |
| `person_only` | LOW | Only `:person` |
| `clean` | LOW | No findings |

`explanation` includes: `rule`, `reason` (human-readable string), `triggered_by` (type names), `detected_values`, `threshold`.

### Policy Engine (`PromptProtect::PolicyEngine`)
- Maps risk level → action: `allow` / `sanitize` / `block`
- Defaults: low→allow, medium→sanitize, high→block
- Overridable via `PROMPT_PROTECT_POLICY_{LOW,MEDIUM,HIGH}` env vars

### Masking Engine (`PromptProtect::MaskingEngine`)
- Right-to-left replacement to preserve string offsets
- Drops overlapping findings (keeps leftmost)
- Returns `{ masked_text:, mapping: }` — mapping is `"[TYPE_N]" → original_value`
- Typed, numbered placeholders are stable even if the LLM rephrases surrounding text

### Forwarder (`PromptProtect::Forwarder`)
- `POST OPENAI_API_BASE_URL/v1/chat/completions`
- Injects `Authorization: Bearer {OPENAI_API_KEY}`
- Raises `UpstreamError` on non-2xx or network failure
- Timeouts: 30s total, 5s open

### Response Scanner (`ProxyController#scan_and_sanitize_response`)
- Extracts `choices[].message.content` from LLM response
- Runs full `DetectionEngine` + `MaskingEngine` on each
- Sets `X-Prompt-Protect-Response-*` headers
- Merges `risk_explanation` into response body

---

## spaCy Sidecar Service

**Location:** `services/spacy/`
**Stack:** Python 3.12, FastAPI, spaCy

**Endpoints:**
- `GET /health` — liveness check
- `POST /detect` — `{ text }` → `{ entities: [{ text, label, start, end }] }`

**Model selection:** Build arg + runtime env var `SPACY_MODEL`.

| Model | Image size | Notes |
|---|---|---|
| `en_core_web_sm` | ~200 MB | Default. Fast build, good accuracy. |
| `en_core_web_trf` | ~2–3 GB | Opt-in. Transformer-based (RoBERTa). Set `SPACY_MODEL=en_core_web_trf` at build and runtime. Installs CPU-only torch automatically. |

**Fallback:** Sidecar unavailable → `NerDetector` delegates to `PersonDetector`. ORG and LOCATION findings are lost in fallback mode; pipeline continues uninterrupted.

---

## Transparency Headers

| Header | Values |
|---|---|
| `X-Prompt-Protect-Risk-Level` | `low` / `medium` / `high` |
| `X-Prompt-Protect-Action` | `allow` / `sanitize` / `block` |
| `X-Prompt-Protect-Detected-Types` | comma-separated input types, e.g. `email,person` |
| `X-Prompt-Protect-Masked` | `true` / `false` |
| `X-Prompt-Protect-Response-Risk-Level` | risk level of LLM response |
| `X-Prompt-Protect-Response-Detected-Types` | types found in LLM response |
| `X-Prompt-Protect-Response-Masked` | whether LLM response was masked |

---

## Dry Run Mode

`dry_run: true` — full pipeline without forwarding. Returns:

```json
{
  "dry_run": true,
  "risk_level": "high",
  "action": "block",
  "risk_explanation": {
    "rule": "critical_type",
    "reason": "Prompt contains a critical-risk entity (id) that is blocked by policy.",
    "triggered_by": ["id"],
    "detected_values": ["523-45-6789"],
    "threshold": null
  },
  "messages": [
    {
      "role": "user",
      "original_text": "...",
      "masked_text": "...",
      "mapping": { "[ID_1]": "523-45-6789" },
      "findings": [...]
    }
  ]
}
```

---

## Deployment

```yaml
services:
  app:    # Rails API — port 3000
  spacy:  # Python NER sidecar — internal only, port 5001
```

`docker compose up` — Rails waits for spaCy health check before accepting traffic.

---

## Tech Stack

| Layer | Technology |
|---|---|
| API | Ruby 3.4 / Rails 8 (API mode) |
| NER sidecar | Python 3.12 / FastAPI / spaCy |
| HTTP client | Faraday |
| API docs | rswag (OpenAPI 3.0) |
| Tests | RSpec, WebMock |
| Linting | RuboCop (omakase) |
| Deployment | Docker + docker compose |

---

## V3 (planned)

- VehicleDetector — VIN and registration plate detection
- Multi-provider support (Anthropic, Cohere, etc.)
- Multilingual spaCy models
- Data exfiltration intent detection

## Future (unplanned)

- Multi-turn session risk accumulation
- User-defined custom entity types (GLiNER)
- Per-tenant policy configuration
- gRPC transport for spaCy sidecar
