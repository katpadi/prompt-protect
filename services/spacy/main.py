import os
import spacy
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI(title="Prompt Protect — spaCy NER Service")

MODEL_NAME = os.getenv("SPACY_MODEL", "en_core_web_sm")

try:
    nlp = spacy.load(MODEL_NAME)
except OSError:
    raise RuntimeError(
        f"spaCy model '{MODEL_NAME}' not found. "
        f"Run: python -m spacy download {MODEL_NAME}"
    )


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
    return {"status": "ok", "model": MODEL_NAME}


@app.post("/detect", response_model=DetectResponse)
def detect(body: DetectRequest):
    if not body.text.strip():
        return DetectResponse(entities=[])

    doc = nlp(body.text)

    entities = [
        Entity(text=ent.text, label=ent.label_, start=ent.start_char, end=ent.end_char)
        for ent in doc.ents
    ]

    return DetectResponse(entities=entities)
