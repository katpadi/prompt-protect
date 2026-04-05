import os
from .base import BaseBackend

# TODO: implement GLiNER backend
#
# GLiNER detects arbitrary entity types defined at query time — no per-type training needed.
# Recommended model: "urchade/gliner-small-v2.1" (~100 MB, CPU-friendly)
# Fallback:          "urchade/gliner-medium-v2.1" (~300 MB, better recall)
#
# Install: pip install gliner
#
# Label mapping — GLiNER uses free-text labels, map to spaCy conventions:
#   "person"       → PERSON
#   "organization" → ORG
#   "location"     → GPE
#
# Example usage:
#   from gliner import GLiNER
#   model = GLiNER.from_pretrained("urchade/gliner-small-v2.1")
#   entities = model.predict_entities(text, ["person", "organization", "location"])
#   # returns: [{ "text": ..., "label": ..., "start": ..., "end": ... }]


LABEL_MAP = {
    "person":       "PERSON",
    "organization": "ORG",
    "location":     "GPE",
}

ENTITY_TYPES = list(LABEL_MAP.keys())


class GlinerBackend(BaseBackend):
    """
    GLiNER NER backend — not yet implemented.

    Env vars:
      GLINER_MODEL — model to load (default: urchade/gliner-small-v2.1)
    """

    def __init__(self):
        self._model_name = os.getenv("GLINER_MODEL", "urchade/gliner-small-v2.1")
        self._model = None

    def load(self) -> None:
        raise NotImplementedError(
            "GlinerBackend is not yet implemented. "
            "Install gliner and implement this method."
        )

    def detect(self, text: str) -> list[dict]:
        raise NotImplementedError("GlinerBackend is not yet implemented.")

    def model_name(self) -> str:
        return self._model_name
