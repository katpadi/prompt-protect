from abc import ABC, abstractmethod


class BaseBackend(ABC):
    """
    Interface all NER backends must implement.

    The /detect endpoint calls detect(text) and expects a list of:
      { "text": str, "label": str, "start": int, "end": int }

    Labels must use spaCy conventions: PERSON, ORG, GPE, LOC.
    The proxy maps these to its internal types (:person, :org, :location).
    """

    @abstractmethod
    def load(self) -> None:
        """Load the model into memory. Called once at startup."""
        ...

    @abstractmethod
    def detect(self, text: str) -> list[dict]:
        """Run NER on text. Returns list of entity dicts."""
        ...

    @abstractmethod
    def model_name(self) -> str:
        """Human-readable model identifier for the /health endpoint."""
        ...
