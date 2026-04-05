import os
from .base import BaseBackend

# TODO: implement HuggingFace NER backend
#
# Runs any HF token-classification model via the transformers pipeline.
# Recommended models (balance of size vs accuracy):
#   "dslim/bert-base-NER"                              — ~400 MB, fast, good PII precision
#   "elastic/distilbert-base-uncased-finetuned-conll03-english" — ~250 MB, distilled, very fast
#   "Jean-Baptiste/roberta-large-ner-english"           — ~1.3 GB, high accuracy
#
# Install: pip install transformers torch
# For CPU-only torch: pip install torch --index-url https://download.pytorch.org/whl/cpu
#
# Label mapping — CoNLL-03 labels to spaCy conventions:
#   PER → PERSON
#   ORG → ORG
#   LOC → GPE
#
# Example usage:
#   from transformers import pipeline
#   ner = pipeline("ner", model="dslim/bert-base-NER", aggregation_strategy="simple")
#   results = ner(text)
#   # returns: [{ "entity_group": "PER", "word": ..., "start": ..., "end": ..., "score": ... }]


LABEL_MAP = {
    "PER": "PERSON",
    "ORG": "ORG",
    "LOC": "GPE",
}


class HuggingFaceBackend(BaseBackend):
    """
    HuggingFace transformers NER backend — not yet implemented.

    Env vars:
      HF_NER_MODEL — model to load (default: dslim/bert-base-NER)
    """

    def __init__(self):
        self._model_name = os.getenv("HF_NER_MODEL", "dslim/bert-base-NER")
        self._pipeline = None

    def load(self) -> None:
        raise NotImplementedError(
            "HuggingFaceBackend is not yet implemented. "
            "Install transformers and torch, then implement this method."
        )

    def detect(self, text: str) -> list[dict]:
        raise NotImplementedError("HuggingFaceBackend is not yet implemented.")

    def model_name(self) -> str:
        return self._model_name
