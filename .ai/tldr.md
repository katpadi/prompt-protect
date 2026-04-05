# Prompt Protect — TL;DR

## What it is

A drop-in HTTP proxy that sits between your app and any LLM provider. You change one URL. Everything else stays the same.

## The problem

When teams use LLMs in production, engineers routinely send sensitive data in prompts — SSNs, credit cards, API keys, patient records, internal emails — directly to third-party APIs like OpenAI. There is no visibility into what's being sent, no safety net, and no easy way to stop it without rewriting every integration.

Existing tools don't fit. PII libraries are language-specific and require code changes everywhere. Enterprise DLP gateways are expensive, not LLM-aware, and SaaS-only. Neither scans LLM responses.

## How it works

Every request passes through a 7-stage pipeline before reaching the LLM — and the response is scanned on the way back.

```
Your app → Prompt Protect → OpenAI (or any compatible API)
```

1. **Normalise** — strip encoding tricks (Unicode lookalikes, zero-width chars, Base64) that would bypass all detectors
2. **Detect** — regex for 7 structured types (email, phone, address, ID numbers, IP, secrets, DOB) + spaCy NER for names, organisations, locations
3. **Score** — combination-aware risk engine: not just "is there a credit card?" but "do these fragments together identify a person?"
4. **Explain** — every decision produces a structured audit log: which rule fired, which values triggered it, why
5. **Enforce** — allow, sanitize (mask and forward), or block — configurable per risk level
6. **Mask** — sensitive values replaced with stable typed placeholders: `[EMAIL_1]`, `[ID_1]`, `[SECRET_1]`
7. **Scan reply** — the LLM's response is also scanned and masked before it reaches your client

## Why it matters

Most tools score PII fields in isolation. Prompt Protect scores combinations — a name alone is low risk, but name + employer + location together is a complete identity profile and gets blocked. No competitor does this.

Most tools only guard the request. Prompt Protect also scans the LLM's response — catching hallucinated PII, regurgitated training data, or identity details reconstructed from context.

All encoding-based evasion techniques (fullwidth Unicode, zero-width characters, Base64) achieve 100% bypass against every other guardrail tested (Palo Alto Unit 42, 2025). Prompt Protect normalises text before detection runs.

Every risk decision includes a structured explanation — which rule fired, which entity types triggered it, and the detected values. No black box. Directly addresses GDPR Article 22 explainability requirements.

## Deployment

```bash
docker compose up
```

One command. Self-hosted. Nothing leaves your infrastructure.
