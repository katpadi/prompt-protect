FROM python:3.12-slim

WORKDIR /app

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Backend-specific dependencies
ARG NER_BACKEND=spacy
ARG SPACY_MODEL=en_core_web_sm

# spaCy backend: optionally install transformer support and download model
RUN if [ "$NER_BACKEND" = "spacy" ]; then \
      if [ "$SPACY_MODEL" = "en_core_web_trf" ]; then \
        pip install --no-cache-dir torch --index-url https://download.pytorch.org/whl/cpu && \
        pip install --no-cache-dir spacy-transformers; \
      fi && \
      python -m spacy download ${SPACY_MODEL}; \
    fi

# GLiNER backend
RUN if [ "$NER_BACKEND" = "gliner" ]; then \
      pip install --no-cache-dir gliner; \
    fi

# HuggingFace backend
RUN if [ "$NER_BACKEND" = "hf" ]; then \
      pip install --no-cache-dir transformers torch --index-url https://download.pytorch.org/whl/cpu; \
    fi

COPY . .

EXPOSE 5001

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "5001"]
