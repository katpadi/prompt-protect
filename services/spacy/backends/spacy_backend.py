import os
import spacy
from .base import BaseBackend


class SpacyBackend(BaseBackend):
    """
    spaCy NER backend.

    Env vars:
      SPACY_MODEL — model to load (default: en_core_web_sm)
                    use en_core_web_trf for higher accuracy (~2 GB RAM, needs torch)
    """

    def __init__(self):
        self._model_name = os.getenv("SPACY_MODEL", "en_core_web_sm")
        self._nlp = None

    def load(self) -> None:
        try:
            self._nlp = spacy.load(self._model_name)
        except OSError:
            raise RuntimeError(
                f"spaCy model '{self._model_name}' not found. "
                f"Run: python -m spacy download {self._model_name}"
            )

    def detect(self, text: str) -> list[dict]:
        doc = self._nlp(text)
        return [
            {"text": ent.text, "label": ent.label_, "start": ent.start_char, "end": ent.end_char}
            for ent in doc.ents
        ]

    def model_name(self) -> str:
        return self._model_name
