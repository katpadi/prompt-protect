import os
from .base import BaseBackend

# Maps GLiNER free-text labels to spaCy conventions expected by the proxy.
LABEL_MAP = {
    "person":       "PERSON",
    "organization": "ORG",
    "location":     "GPE",
}

ENTITY_TYPES = list(LABEL_MAP.keys())


class GlinerBackend(BaseBackend):
    """
    GLiNER NER backend.

    Detects arbitrary entity types defined at query time — no per-type training.
    Recommended for better recall on short names, non-Western names, and ambiguous orgs.

    Env vars:
      GLINER_MODEL — model to load (default: urchade/gliner-small-v2.1)
                     urchade/gliner-medium-v2.1 for better recall (~300 MB)
    """

    def __init__(self):
        self._model_name = os.getenv("GLINER_MODEL", "urchade/gliner_small-v2.1")
        self._model = None

    def load(self) -> None:
        from gliner import GLiNER
        self._model = GLiNER.from_pretrained(self._model_name)

    def detect(self, text: str) -> list[dict]:
        entities = self._model.predict_entities(text, ENTITY_TYPES)
        return [
            {
                "text":  e["text"],
                "label": LABEL_MAP.get(e["label"], e["label"].upper()),
                "start": e["start"],
                "end":   e["end"],
            }
            for e in entities
            if len(e["text"].strip()) > 1  # filter single-char noise ("I", "i")
        ]

    def model_name(self) -> str:
        return self._model_name
