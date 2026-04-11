
# Prompt Protect

![Ruby](https://img.shields.io/badge/Ruby-3.4-CC342D?logo=ruby&logoColor=white)
![Rails](https://img.shields.io/badge/Rails-8-D30001?logo=rubyonrails&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.12-3776AB?logo=python&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-green)

Small drop-in proxy that checks and scores prompts before they hit LLMs.

Works with OpenAI-compatible clients. Just change the base URL.

Prompt Protect is a generic privacy proxy. Downstream applications call it to anonymize requests, forward to the LLM, and restore the output — without any sensitive data touching the provider.

## How it works

We're already sending real data to LLMs:

1. **Normalize** — collapses Unicode tricks and decodes Base64 so encoding evasion doesn't bypass detection
2. **Detect** — scans message content for PII using a hybrid engine (regex + NER sidecar)
3. **Assess** — assigns a risk level: `low`, `medium`, or `high`
4. **Enforce** — applies policy: `allow`, `sanitize`, or `block` (overridable per profile)
5. **Forward** — sends the (possibly masked) request to the LLM provider
6. **Scan response** — runs the same detection pass on what the LLM sends back
7. **Restore** — if `restore_output` is enabled, replaces placeholders in the LLM reply with original values
8. **Respond** — returns the provider response with transparency headers attached

Most of the time, no one checks what actually goes out.

This sits in front of your LLM calls and acts as a *pre-flight check*.

## What it does

Before a request goes out:

- normalizes text (unicode tricks, base64, etc.)
- detects sensitive data (regex + spaCy)
- scores risk (low / medium / high)
- either:
  - allows  
  - sanitizes  
  - blocks  

Then forwards the request if allowed.

Also checks responses on the way back.

## Run it

```bash
docker compose up
```

## Try it

### Playground

Open:

http://localhost:3000/playground.html

Paste:

John Smith john@email.com lives in Sydney

---

### Or curl (dry-run)

```bash
curl http://localhost:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-4o","messages":[{"role":"user","content":"Hello!"}]}'
```

Set `OPENAI_API_KEY` (or `ANTHROPIC_API_KEY`) in the proxy's `.env`. The proxy injects it when forwarding — your client code doesn't need to send auth.

To route to Anthropic, set `PROMPT_PROTECT_PROVIDER=anthropic` in `.env`, or pass `"provider": "anthropic"` in any request body. The proxy translates the OpenAI message format to Anthropic's Messages API automatically.

## Playground

```json
{
  "risk": "HIGH",
  "action": "SANITIZE",
  "reason": "identity profile (name + email + location)",
  "sanitized": "[PERSON_1] [EMAIL_1]"
}
```


## Example

Input:

John Smith from ACME in Sydney

Output:

Risk: HIGH  
Reason: identity profile (name + org + location)  
Sanitized: [PERSON_1] from [ORG_1] in [LOCATION_1]


## Integration (drop-in)

```ruby
client = OpenAI::Client.new(
  api_key: ENV['OPENAI_API_KEY'],
  uri_base: "http://localhost:3000/v1"
)
```

## Scope

- Public API is OpenAI-style (`/v1/chat/completions`)
- Works as a drop-in for OpenAI-compatible clients
- Internally can route to different providers

## Out of Scope

- being a universal LLM API gateway  
- trying to support every provider's native format  
- being a full data classification system  

This focuses on one thing:

**preventing sensitive data from being sent to LLMs**

## Detection

### Regex layer

- email, phone, address  
- IDs, tokens, API keys  
- financial + medical data  

### NER (spaCy)

- person names  
- organizations  
- locations  

## Risk model

- HIGH
  - IDs, secrets, financial, medical  
  - identity reconstruction (e.g. name + DOB)  
  - 3+ identity signals  

- MEDIUM
  - multiple signals (email + phone)

- LOW
  - weak signals (name only)

## Technical Details

### Request flow

Client → Prompt Protect → LLM

## Usage modes

### 1. Firewall

Block the request before it reaches the LLM when high-risk PII is detected. No LLM call is made, 422 returned.

This is the default behavior for high-risk content — no configuration needed.

```bash
curl http://localhost:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-4o","messages":[{"role":"user","content":"My SSN is 123-45-6789"}]}'
# → 422 blocked
```

### 2. Sanitize

Mask PII, forward to the LLM, return the reply with placeholders intact. The LLM never sees real values. Neither does the caller.

```json
{
  "model": "gpt-4o",
  "messages": [{"role": "user", "content": "Contact jane@example.com"}],
  "prompt_protect": { "policy_overrides": { "high": "sanitize" } }
}
```

Reply contains `[EMAIL_1]` — original stays on your side.

### 3. Transparent proxy

Mask PII before the LLM, restore originals in the reply. The LLM works blind; your app gets natural output.

```json
{
  "model": "gpt-4o",
  "messages": [{"role": "user", "content": "Contact jane@example.com"}],
  "prompt_protect": {
    "policy_overrides": { "high": "sanitize" },
    "restore_output": true
  }
}
```

Reply contains `jane@example.com` — restored before returning to the caller.

### 4. Dry run

Run the full detection and policy pipeline without forwarding to the LLM. Returns findings, risk level, action, and masked text. No API key required — useful for testing.

```json
{
  "model": "gpt-4o",
  "dry_run": true,
  "messages": [{"role": "user", "content": "My SSN is 123-45-6789"}]
}
```

### 5. Anonymize (no LLM)

Detect and mask PII in a text snippet with no LLM involved. Use this to preprocess text before storing, indexing, or logging it.

```bash
curl http://localhost:3000/v1/anonymize \
  -H "Content-Type: application/json" \
  -d '{"text": "Contact jane@example.com for details."}'
```

## Configuration reference

### `prompt_protect` request options

Passed per-request inside the `prompt_protect` key. Omitting it entirely is valid — the `default` profile applies with no behavior change.

| Option | Type | Default | Description |
|---|---|---|---|
| `profile` | string | `"default"` | Named profile to apply |
| `policy_overrides` | object | `{}` | Per risk-level action overrides — `"low"`, `"medium"`, `"high"` → `"allow"`, `"sanitize"`, or `"block"` |
| `restore_output` | boolean | `false` | Restore original values in the LLM reply |
| `include_findings` | boolean | `false` | Attach detection metadata to the response body |

### Policy

Each risk level maps to an action, configurable globally via env vars or per-request via `policy_overrides`:

| Risk | Default | Available actions |
|---|---|---|
| `low` | `allow` | `allow` · `sanitize` · `block` |
| `medium` | `sanitize` | `allow` · `sanitize` · `block` |
| `high` | `block` | `allow` · `sanitize` · `block` |

### Profiles

Named presets that bundle `policy_overrides` and a `restore_output` default:

| Profile | Policy overrides | `restore_output` default |
|---|---|---|
| `default` | none | `false` |
| `lenient` | `high` → `sanitize` | `true` |

Add profiles in `app/services/prompt_protect/profiles/registry.rb`. Each profile is visible via `GET /v1/profiles`.

### Precedence

```
inline policy_overrides  >  profile  >  env vars  >  defaults
```

### `include_findings` response shape

```json
{
  "choices": [...],
  "prompt_protect": {
    "profile": "default",
    "action": "sanitize",
    "restored": false,
    "findings_summary": { "email": 1, "person": 1 }
  }
}
```

Raw values are never included in findings metadata.

### Cross-field risk

Most tools look at entities individually.

This looks at combinations:

- name → low  
- email → medium  
- name + org + location → high  

### Handles obfuscation

Every response includes transparency headers:

| Header | Example | Description |
|---|---|---|
| `X-Prompt-Protect-Risk-Level` | `medium` | Computed risk level for the request |
| `X-Prompt-Protect-Action` | `sanitize` | Policy action taken |
| `X-Prompt-Protect-Detected-Types` | `email,person` | Detected PII types |
| `X-Prompt-Protect-Masked` | `true` | Whether request content was masked |
| `X-Prompt-Protect-Response-Risk-Level` | `low` | Risk level of the LLM's reply |
| `X-Prompt-Protect-Response-Detected-Types` | `person` | PII types found in the reply |
| `X-Prompt-Protect-Response-Masked` | `false` | Whether reply content was masked |

## Environment variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `OPENAI_API_KEY` | Yes (OpenAI) | — | Injected when forwarding to OpenAI |
| `OPENAI_API_BASE_URL` | No | `https://api.openai.com` | OpenAI base URL override |
| `ANTHROPIC_API_KEY` | Yes (Anthropic) | — | Injected when forwarding to Anthropic |
| `ANTHROPIC_API_BASE_URL` | No | `https://api.anthropic.com` | Anthropic base URL override |
| `GEMINI_API_KEY` | Yes (Gemini) | — | Injected when forwarding to Gemini |
| `GEMINI_API_BASE_URL` | No | `https://generativelanguage.googleapis.com/v1beta/openai` | Gemini base URL override |
| `PROMPT_PROTECT_PROVIDER` | No | `openai` | LLM provider: `openai`, `anthropic`, or `gemini`. Can also be set per-request via `"provider"` field |
| `PROMPT_PROTECT_MODEL` | No | — | Model name to forward to the provider. Can also be set per-request via `"model"` field |
| `CORS_ORIGINS` | No | `*` | Allowed CORS origins |
| `PROMPT_PROTECT_POLICY_LOW` | No | `allow` | Action for low risk |
| `PROMPT_PROTECT_POLICY_MEDIUM` | No | `sanitize` | Action for medium risk |
| `PROMPT_PROTECT_POLICY_HIGH` | No | `block` | Action for high risk |
| `NER_ENABLED` | No | `true` | Set to `false` to use regex-only detection |
| `NER_SERVICE_URL` | No | `http://spacy:5001` | NER sidecar URL |
| `SPACY_MODEL` | No | `en_core_web_sm` | spaCy model — `en_core_web_sm` (fast) or `en_core_web_trf` (accurate, ~2 GB RAM) |

## Endpoints

| Method | Path | Description |
|---|---|---|
| `GET` | `/health` | Health check |
| `POST` | `/v1/chat/completions` | OpenAI-compatible proxy — see [Usage modes](#usage-modes) |
| `GET` | `/v1/profiles` | List available profiles |
| `POST` | `/v1/anonymize` | Standalone anonymization — see [Anonymize](#5-anonymize-no-llm) |

## Running tests

```bash
NER_ENABLED=false bundle exec rspec
```

## Tech stack

- Ruby 3.4 / Rails 8 API
- Python 3.12 / FastAPI (NER sidecar — backends: spaCy, GLiNER, HuggingFace)
- Faraday (HTTP client)
- Docker + docker compose

## Limitations

- OpenAI-style API only  
- Detection is structured (not semantic)  
- Response inspection is best-effort  
- Does not classify full documents or business context  

## Using Prompt Protect as a privacy proxy for downstream apps

Prompt Protect is intentionally generic. Any product that needs to send user-generated text to an LLM without exposing PII can sit a Prompt Protect instance in front of the provider.

```
Your App  →  Prompt Protect (/v1/chat/completions, policy_overrides, restore_output)  →  LLM
```

The downstream app controls its own privacy policy via `policy_overrides` and `restore_output` per request. Prompt Protect stays domain-agnostic — it knows nothing about the application using it.

This pattern works for HR tools, customer support platforms, legal document drafting, education products, and any other domain where user-generated text may contain PII.

## Roadmap

- **Streaming support** — pass through SSE chunks from the LLM provider
- **Proxy auth** — shared secret or API key to restrict access to the proxy
- **Custom detectors** — register domain-specific detectors without forking
- **Metrics endpoint** — Prometheus-compatible `/metrics` for observability
- **FastAPI rewrite** — the NER sidecar is already Python; collapsing the proxy into the same stack would eliminate the inter-service HTTP hop, simplify deployment, and make streaming and ML extensibility first-class

## Contributing

## Roadmap

### Short term

- [ ] Reason engine improvements  
- [ ] Better dry-run output consistency  
- [ ] Improve normalization coverage  
- [ ] Basic request logging  

### Medium term

- [ ] Multi-provider support  
- [ ] Response-side enforcement improvements  
- [ ] Configurable policies  

### Longer term

- [ ] Better NLP detection  
- [ ] Domain-specific rules  
- [ ] Optional SDKs  

## Notes

- runs locally, no data leaves your infra  
- no database  
- playground is for demo only  
---
MIT
