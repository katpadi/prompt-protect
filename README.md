# Prompt Protect

A drop-in safety proxy for LLM calls.

Sits between your backend and an LLM provider to detect sensitive data, assess risk, and enforce policy — before the prompt leaves your infrastructure.

```
Your App  →  Prompt Protect  →  OpenAI / Anthropic (Claude)
```

## How it works

Every request through `/v1/chat/completions` is run through a pipeline:

1. **Normalize** — collapses Unicode tricks and decodes Base64 so encoding evasion doesn't bypass detection
2. **Detect** — scans message content for PII using a hybrid engine (regex + NER sidecar)
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

Point any OpenAI-compatible client at the proxy by changing the base URL. The request format is identical to OpenAI's API — no other changes needed.

```bash
curl http://localhost:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-4o","messages":[{"role":"user","content":"Hello!"}]}'
```

Set `OPENAI_API_KEY` (or `ANTHROPIC_API_KEY`) in the proxy's `.env`. The proxy injects it when forwarding — your client code doesn't need to send auth.

To route to Anthropic, set `PROMPT_PROTECT_PROVIDER=anthropic` in `.env`, or pass `"provider": "anthropic"` in any request body. The proxy translates the OpenAI message format to Anthropic's Messages API automatically.

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
| IdDetector | `:id` | SSN `123-45-6789`, credit card `4111 1111 1111 1111`, passport, IBAN, driver's license, AU Medicare/TFN |
| IpDetector | `:ip` | `192.168.1.1`, `2001:db8::1` |
| SecretDetector | `:secret` | Bearer tokens, `sk-...` OpenAI keys, AWS keys, GitHub (`ghp_`, `github_pat_`), GitLab (`glpat-`), Slack (`xoxb-`, webhooks), Azure (`AccountKey=`) |
| DobDetector | `:dob` | `DOB: 01/15/1990`, `born January 15, 1990` |
| MedicalDetector | `:medical` | MRN, ICD-10 codes, NHS numbers, medications with dosage, insurance member IDs |
| FinancialDetector | `:financial` | Bank routing numbers, account numbers, UK sort codes, SWIFT/BIC codes |
| VehicleDetector | `:vehicle` | VINs (keyword-gated, 17-char ISO), registration plates (keyword-gated) |
| NerDetector | `:person` | Names via NER sidecar |
| NerDetector | `:org` | Company and org names via NER sidecar |
| NerDetector | `:location` | Places, countries, cities via NER sidecar |

The NER sidecar runs as a separate container and is called automatically. If it is unavailable, detection falls back to heuristic regex-based person detection.

### NER backend

The sidecar uses spaCy (`en_core_web_sm` by default). Switch to the transformer model for higher accuracy at the cost of ~2 GB RAM:

```bash
SPACY_MODEL=en_core_web_trf docker compose up
```

**Why spaCy:** We benchmarked spaCy against GLiNER (a generalist zero-shot NER model) on 52 labeled examples covering names, orgs, locations, and false positive traps. GLiNER has better recall (93.8% vs 79.2%) but produces twice as many false positives (30 vs 15) and is 27× slower (41ms vs 1.5ms). In a privacy proxy, false positives cause legitimate prompts to be masked or blocked unnecessarily — that's the worse failure mode. spaCy wins on F1 (75.2% vs 73.2%) and is the better fit.

Benchmark fixtures are in `services/ner/fixtures/ner_fixtures.json`. To re-run:

```bash
docker build -t ner-bench services/ner
docker run --rm ner-bench python benchmark.py
```

## Risk levels

| Level | Condition |
|---|---|
| `high` | Any `:id`, `:secret`, `:medical`, or `:financial` type |
| `high` | `:dob` + `:person` together (identity reconstruction) |
| `high` | 3+ types from `{person, org, location, email, phone, dob}` (mosaic profile) |
| `medium` | 2+ sensitive types (email, phone, address, ip, vehicle) |
| `medium` | Single sensitive type (email, phone, address, ip, dob, vehicle) |
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
| `OPENAI_API_KEY` | Yes (OpenAI) | — | Injected when forwarding to OpenAI |
| `OPENAI_API_BASE_URL` | No | `https://api.openai.com` | OpenAI base URL override |
| `ANTHROPIC_API_KEY` | Yes (Anthropic) | — | Injected when forwarding to Anthropic |
| `ANTHROPIC_API_BASE_URL` | No | `https://api.anthropic.com` | Anthropic base URL override |
| `PROMPT_PROTECT_PROVIDER` | No | `openai` | LLM provider: `openai` or `anthropic`. Can also be set per-request via `"provider"` field |
| `CORS_ORIGINS` | No | `*` | Allowed CORS origins |
| `PROMPT_PROTECT_POLICY_LOW` | No | `allow` | Action for low risk |
| `PROMPT_PROTECT_POLICY_MEDIUM` | No | `sanitize` | Action for medium risk |
| `PROMPT_PROTECT_POLICY_HIGH` | No | `block` | Action for high risk |
| `NER_ENABLED` | No | `true` | Set to `false` to use regex-only detection |
| `NER_SERVICE_URL` | No | `http://spacy:5001` | NER sidecar URL |
| `SPACY_MODEL` | No | `en_core_web_sm` | spaCy model — `en_core_web_sm` (fast) or `en_core_web_trf` (accurate, ~2 GB RAM) |

Policy actions: `allow` · `sanitize` · `block`

## Endpoints

| Method | Path | Description |
|---|---|---|
| `GET` | `/health` | Health check |
| `POST` | `/v1/chat/completions` | OpenAI-compatible proxy (supports `dry_run: true`) |

## Running tests

```bash
NER_ENABLED=false bundle exec rspec
```

## Tech stack

- Ruby 3.4 / Rails 8 API
- Python 3.12 / FastAPI (NER sidecar — backends: spaCy, GLiNER, HuggingFace)
- Faraday (HTTP client)
- Docker + docker compose
