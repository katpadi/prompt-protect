# Prompt Protect

A drop-in safety proxy for LLM calls.

Sits between your backend and an LLM provider to detect sensitive data, assess risk, and enforce policy — before the prompt leaves your infrastructure.

```
Your App  →  Prompt Protect  →  OpenAI (or any compatible API)
```

## How it works

Every request through `/v1/chat/completions` is run through a pipeline:

1. **Detect** — scans message content for PII using a hybrid engine (NER + regex)
2. **Assess** — assigns a risk level: `low`, `medium`, or `high`
3. **Enforce** — applies policy: `allow`, `sanitize`, or `block`
4. **Forward** — sends the (possibly masked) request to the LLM provider
5. **Respond** — returns the provider response with transparency headers attached

## Quick start

```bash
cp .env.example .env
# Fill in OPENAI_API_KEY in .env

docker compose up
```

The proxy is now running on `http://localhost:3000`.

Point your existing OpenAI client at it by changing the base URL:

```bash
curl http://localhost:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4o",
    "messages": [{ "role": "user", "content": "Hello!" }]
  }'
```

No auth token needed from your client — Prompt Protect injects `OPENAI_API_KEY` when forwarding to the provider.

## Playground

Try it interactively without an OpenAI key:

```
http://localhost:3000/playground.html
```

Paste any prompt and see what gets detected, what risk level is assigned, what action is taken, and what the masked output looks like — all in real time.

## API docs

Swagger UI is available at:

```
http://localhost:3000/api-docs
```

## Dry run mode

Add `"dry_run": true` to any request to run the full protection pipeline without forwarding to OpenAI. Returns findings, risk level, action, and masked text. No API key required.

```bash
curl http://localhost:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4o",
    "dry_run": true,
    "messages": [{ "role": "user", "content": "My SSN is 123-45-6789" }]
  }'
```

## Detection

Prompt Protect uses a hybrid detection pipeline:

| Layer | Handles | Technology |
|---|---|---|
| Regex | EMAIL, PHONE, ADDRESS, ID (SSN, credit card) | Ruby regex |
| NER | PERSON names | spaCy `en_core_web_sm` sidecar |

The spaCy service runs as a sidecar container and is called automatically. If it is unavailable, detection falls back to heuristic regex-based person detection.

## Risk levels

| Risk | Triggers |
|---|---|
| `high` | Any ID number (SSN, credit card), or 2+ sensitive types |
| `medium` | One sensitive type (email, phone, or address) |
| `low` | Person name only, or no findings |

## Placeholder masking

When policy is `sanitize`, sensitive values are replaced with typed placeholders:

```
James Carter     → [PERSON_1]
john@example.com → [EMAIL_1]
555-123-4567     → [PHONE_1]
123-45-6789      → [ID_1]
```

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
| `SPACY_ENABLED` | No | `true` | Set to `false` to use regex-only person detection |
| `SPACY_SERVICE_URL` | No | `http://spacy:5001` | spaCy sidecar URL |
| `SPACY_MODEL` | No | `en_core_web_sm` | spaCy model. `en_core_web_sm` (default, ~200 MB) or `en_core_web_trf` (higher accuracy, ~2–3 GB, needs ~2 GB RAM). |

Policy actions: `allow` · `sanitize` · `block`

## Endpoints

| Method | Path | Description |
|---|---|---|
| `GET` | `/health` | Health check |
| `GET` | `/api-docs` | Swagger UI |
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
