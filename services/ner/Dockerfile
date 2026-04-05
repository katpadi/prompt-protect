FROM python:3.12-slim

WORKDIR /app

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

ARG SPACY_MODEL=en_core_web_sm

RUN if [ "$SPACY_MODEL" = "en_core_web_trf" ]; then \
      pip install --no-cache-dir torch --index-url https://download.pytorch.org/whl/cpu && \
      pip install --no-cache-dir spacy-transformers; \
    fi

RUN python -m spacy download ${SPACY_MODEL}

COPY . .

EXPOSE 5001

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "5001"]
