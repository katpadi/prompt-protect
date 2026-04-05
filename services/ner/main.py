import os
from fastapi import FastAPI
from pydantic import BaseModel

from backends.spacy_backend import SpacyBackend

app = FastAPI(title="Prompt Protect — NER Service")

backend = SpacyBackend()
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
        "backend": "spacy",
        "model":   backend.model_name(),
    }


@app.post("/detect", response_model=DetectResponse)
def detect(body: DetectRequest):
    if not body.text.strip():
        return DetectResponse(entities=[])

    entities = [Entity(**e) for e in backend.detect(body.text)]
    return DetectResponse(entities=entities)
