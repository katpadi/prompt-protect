# Prompt Protect

A drop-in safety proxy for LLM calls.

Sits between your backend and an LLM provider to detect sensitive data, assess risk, and enforce policy — before the prompt leaves your infrastructure.

```
Your App  →  Prompt Protect  →  OpenAI (or any compatible API)
```

## How it works

Every request through `/v1/chat/completions` is run through a pipeline:

1. **Normalize** — collapses Unicode tricks and decodes Base64 so encoding evasion doesn't bypass detection
2. **Detect** — scans message content for PII using a hybrid engine (regex + spaCy NER)
3. **Assess** — assigns a risk level: `low`, `medium`, or `high`
4. **Enforce** — applies policy: `allow`, `sanitize`, or `block`
5. **Forward** — sends the (possibly masked) request to the LLM provider
6. **Scan response** — runs the same detection pass on what the LLM sends back
7. **Respond** — returns the provider response with transparency headers attached

## Quick start

```bash
cp .env.example .env
# Fill in OPENAI_API_KEY in .env

docker compose up
```

The proxy is now running on `http://localhost:3000`.

## Integration

Change your OpenAI client's base URL to point at the proxy. That's the entire integration.

**Python**
```python
from openai import OpenAI

client = OpenAI(
    api_key="not-needed",  # Prompt Protect injects OPENAI_API_KEY when forwarding
    base_url="http://localhost:3000/v1"
)

response = client.chat.completions.create(
    model="gpt-4o",
    messages=[{"role": "user", "content": "Hello!"}]
)
```

**Node.js**
```js
import OpenAI from "openai";

const client = new OpenAI({
  apiKey: "not-needed",
  baseURL: "http://localhost:3000/v1",
});

const response = await client.chat.completions.create({
  model: "gpt-4o",
  messages: [{ role: "user", content: "Hello!" }],
});
```

**curl**
```bash
curl http://localhost:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-4o","messages":[{"role":"user","content":"Hello!"}]}'
```

No auth token needed from your client — Prompt Protect injects `OPENAI_API_KEY` when forwarding to the provider.

## Dry run mode

Add `"dry_run": true` to any request to run the full protection pipeline without forwarding to OpenAI. Returns findings, risk level, action, and masked text. No API key required.

```bash
curl http://localhost:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4o",
    "dry_run": true,
    "messages": [{"role":"user","content":"My SSN is 123-45-6789 and I live at 12 Main St"}]
  }'
```

## Playground

Try it interactively without an OpenAI key:

```
http://localhost:3000/playground.html
```

Paste any prompt and see what gets detected, what risk level is assigned, what action is taken, and what the masked output looks like — all in real time.

## Detection

Prompt Protect uses a hybrid detection pipeline:

| Detector | Type | Examples |
|---|---|---|
| EmailDetector | `:email` | `user@example.com` |
| PhoneDetector | `:phone` | `555-123-4567`, `+1 (800) 555 0100` |
| AddressDetector | `:address` | `12 Main St, Springfield` |
| IdDetector | `:id` | SSN `123-45-6789`, credit card `4111 1111 1111 1111` |
| IpDetector | `:ip` | `192.168.1.1`, `2001:db8::1` |
| SecretDetector | `:secret` | Bearer tokens, API keys, `sk-...`, AWS keys |
| DobDetector | `:dob` | `DOB: 01/15/1990`, `born January 15, 1990` |
| NerDetector | `:person` | Names via spaCy |
| NerDetector | `:org` | Company names via spaCy |
| NerDetector | `:location` | Places, countries, cities via spaCy |

The spaCy service runs as a sidecar container and is called automatically. If it is unavailable, detection falls back to heuristic regex-based person detection.

## Risk levels

| Level | Condition |
|---|---|
| `high` | Any `:id` or `:secret` type |
| `high` | `:dob` + `:person` together (identity reconstruction) |
| `high` | 3+ types from `{person, org, location, email, phone, dob}` (mosaic profile) |
| `medium` | 2+ sensitive types (email, phone, address, ip) |
| `medium` | Single sensitive type (email, phone, address, ip) |
| `low` | Person name only, or no findings |

## Policy

Each risk level maps to a policy action, configurable via environment variables:

| Risk | Default action | What it does |
|---|---|---|
| `low` | `allow` | Request forwarded as-is |
| `medium` | `sanitize` | Sensitive values masked with typed placeholders, then forwarded |
| `high` | `block` | Request rejected, 422 returned |

## Placeholder masking

When policy is `sanitize`, sensitive values are replaced with stable typed placeholders:

```
James Carter         → [PERSON_1]
john@example.com     → [EMAIL_1]
555-123-4567         → [PHONE_1]
123-45-6789          → [ID_1]
192.168.1.1          → [IP_1]
sk-abc123...         → [SECRET_1]
```

Placeholders are stable — the same value always maps to the same placeholder within a request, so the LLM response remains coherent.

## Response headers

Every response includes transparency headers:

| Header | Example | Description |
|---|---|---|
| `X-Prompt-Protect-Risk-Level` | `medium` | Computed risk level |
| `X-Prompt-Protect-Action` | `sanitize` | Policy action taken |
| `X-Prompt-Protect-Detected-Types` | `email,person` | Detected PII types |
| `X-Prompt-Protect-Masked` | `true` | Whether content was masked |

## Environment variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `OPENAI_API_KEY` | Yes | — | Forwarded to the LLM provider |
| `OPENAI_API_BASE_URL` | No | `https://api.openai.com` | LLM provider base URL |
| `CORS_ORIGINS` | No | `*` | Allowed CORS origins |
| `PROMPT_PROTECT_POLICY_LOW` | No | `allow` | Action for low risk |
| `PROMPT_PROTECT_POLICY_MEDIUM` | No | `sanitize` | Action for medium risk |
| `PROMPT_PROTECT_POLICY_HIGH` | No | `block` | Action for high risk |
| `SPACY_ENABLED` | No | `true` | Set to `false` to use regex-only detection |
| `SPACY_SERVICE_URL` | No | `http://spacy:5001` | spaCy sidecar URL |
| `SPACY_MODEL` | No | `en_core_web_sm` | `en_core_web_sm` (default, fast) or `en_core_web_trf` (higher accuracy, ~2 GB RAM) |

Policy actions: `allow` · `sanitize` · `block`

## Endpoints

| Method | Path | Description |
|---|---|---|
| `GET` | `/health` | Health check |
| `POST` | `/v1/chat/completions` | OpenAI-compatible proxy (supports `dry_run: true`) |

## Running tests

```bash
SPACY_ENABLED=false bundle exec rspec
```

## Tech stack

- Ruby 3.4 / Rails 8 API
- Python 3.12 / FastAPI / spaCy (NER sidecar)
- Faraday (HTTP client)
- Docker + docker compose
