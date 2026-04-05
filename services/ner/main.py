import os
from fastapi import FastAPI
from pydantic import BaseModel

from backends.spacy_backend import SpacyBackend
from backends.gliner_backend import GlinerBackend
from backends.hf_backend import HuggingFaceBackend

app = FastAPI(title="Prompt Protect — NER Service")

BACKENDS = {
    "spacy":  SpacyBackend,
    "gliner": GlinerBackend,
    "hf":     HuggingFaceBackend,
}

NER_BACKEND = os.getenv("NER_BACKEND", "spacy").lower()

if NER_BACKEND not in BACKENDS:
    raise RuntimeError(
        f"Unknown NER_BACKEND '{NER_BACKEND}'. "
        f"Available: {', '.join(BACKENDS.keys())}"
    )

backend = BACKENDS[NER_BACKEND]()
backend.load()


class DetectRequest(BaseModel):
    text: str


class Entity(BaseModel):
    text: str
    label: str
    start: int
    end: int


class DetectResponse(BaseModel):
    entities: list[Entity]


@app.get("/health")
def health():
    return {
        "status":  "ok",
        "backend": NER_BACKEND,
        "model":   backend.model_name(),
    }


@app.post("/detect", response_model=DetectResponse)
def detect(body: DetectRequest):
    if not body.text.strip():
        return DetectResponse(entities=[])

    entities = [Entity(**e) for e in backend.detect(body.text)]
    return DetectResponse(entities=entities)
