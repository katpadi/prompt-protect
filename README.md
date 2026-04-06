
# Prompt Protect

![Ruby](https://img.shields.io/badge/Ruby-3.4-CC342D?logo=ruby&logoColor=white)
![Rails](https://img.shields.io/badge/Rails-8-D30001?logo=rubyonrails&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.12-3776AB?logo=python&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-green)

Small drop-in proxy that checks and scores prompts before they hit LLMs.

Works with OpenAI-compatible clients. Just change the base URL.

## Why I built this

We're already sending real data to LLMs:

- customer info in support tools  
- logs with emails / tokens  
- internal data from dashboards  

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
curl http://localhost:3000/v1/chat/completions   -H "Content-Type: application/json"   -d '{
    "model": "gpt-4o-mini",
    "messages": [
      { "role": "user", "content": "John Smith john@email.com" }
    ],
    "dry_run": true
  }'
```

### Example output

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

Pipeline:

1. Normalize
2. Detect
3. Score
4. Enforce
5. Forward

## What's interesting here

### Cross-field risk

Most tools look at entities individually.

This looks at combinations:

- name → low  
- email → medium  
- name + org + location → high  

### Handles obfuscation

- fullwidth unicode  
- zero-width characters  
- base64 encoded text  

## Limitations

- OpenAI-style API only  
- Detection is structured (not semantic)  
- Response inspection is best-effort  
- Does not classify full documents or business context  

## Stack

- Rails 8 (proxy)  
- Python / FastAPI (spaCy)  
- Docker  

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
