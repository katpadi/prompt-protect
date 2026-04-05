#!/usr/bin/env python3
"""
NER backend benchmark.

Loads the configured backend, runs it against fixtures/ner_fixtures.json,
and reports precision, recall, F1 per entity type and overall, plus latency.

Usage:
  NER_BACKEND=spacy  python benchmark.py
  NER_BACKEND=gliner python benchmark.py
  NER_BACKEND=spacy  SPACY_MODEL=en_core_web_trf python benchmark.py

  # Compare two backends:
  NER_BACKEND=spacy  python benchmark.py > results_spacy.txt
  NER_BACKEND=gliner python benchmark.py > results_gliner.txt
  diff results_spacy.txt results_gliner.txt
"""

import json
import os
import sys
import time
from collections import defaultdict
from pathlib import Path

from backends.spacy_backend import SpacyBackend
from backends.gliner_backend import GlinerBackend
from backends.hf_backend import HuggingFaceBackend

BACKENDS = {
    "spacy":  SpacyBackend,
    "gliner": GlinerBackend,
    "hf":     HuggingFaceBackend,
}

FIXTURES_PATH = Path(__file__).parent / "fixtures" / "ner_fixtures.json"

# Labels the proxy cares about — others are ignored in scoring
RELEVANT_LABELS = {"PERSON", "ORG", "GPE", "LOC"}


def load_backend():
    name = os.getenv("NER_BACKEND", "spacy").lower()
    if name not in BACKENDS:
        print(f"Unknown NER_BACKEND '{name}'. Available: {', '.join(BACKENDS.keys())}")
        sys.exit(1)
    backend = BACKENDS[name]()
    print(f"Loading backend: {name} / {backend.model_name()}...")
    t = time.time()
    backend.load()
    print(f"Loaded in {time.time() - t:.2f}s\n")
    return name, backend


def normalise_label(label: str) -> str:
    """Collapse LOC → GPE so label comparison is consistent with proxy mapping."""
    return "GPE" if label == "LOC" else label


def score_example(predicted: list[dict], expected: list[dict]) -> dict:
    """
    Compute TP, FP, FN for a single example.
    Matching is text-based (case-insensitive) + label-based.
    """
    pred_set = {(e["text"].lower(), normalise_label(e["label"])) for e in predicted
                if normalise_label(e["label"]) in RELEVANT_LABELS}
    exp_set  = {(e["text"].lower(), normalise_label(e["label"])) for e in expected
                if normalise_label(e["label"]) in RELEVANT_LABELS}

    tp = pred_set & exp_set
    fp = pred_set - exp_set
    fn = exp_set  - pred_set

    return {"tp": tp, "fp": fp, "fn": fn}


def run_benchmark(backend, fixtures: list[dict]) -> dict:
    per_label = defaultdict(lambda: {"tp": 0, "fp": 0, "fn": 0})
    totals    = {"tp": 0, "fp": 0, "fn": 0}
    latencies = []
    failures  = []

    for fixture in fixtures:
        text     = fixture["text"]
        expected = fixture["entities"]

        t0 = time.time()
        try:
            predicted = backend.detect(text)
        except Exception as e:
            failures.append({"id": fixture["id"], "error": str(e)})
            continue
        latencies.append((time.time() - t0) * 1000)

        result = score_example(predicted, expected)

        for entity in result["tp"]:
            per_label[entity[1]]["tp"] += 1
            totals["tp"] += 1
        for entity in result["fp"]:
            per_label[entity[1]]["fp"] += 1
            totals["fp"] += 1
        for entity in result["fn"]:
            per_label[entity[1]]["fn"] += 1
            totals["fn"] += 1

        # Print misses and false positives for debugging
        if result["fn"]:
            failures.append({
                "id":     fixture["id"],
                "missed": [f"{t} ({l})" for t, l in result["fn"]],
            })
        if result["fp"]:
            failures.append({
                "id":    fixture["id"],
                "false_positives": [f"{t} ({l})" for t, l in result["fp"]],
            })

    return {
        "per_label": dict(per_label),
        "totals":    totals,
        "latencies": latencies,
        "failures":  failures,
    }


def prf(tp, fp, fn) -> tuple[float, float, float]:
    precision = tp / (tp + fp) if (tp + fp) > 0 else 0.0
    recall    = tp / (tp + fn) if (tp + fn) > 0 else 0.0
    f1        = 2 * precision * recall / (precision + recall) if (precision + recall) > 0 else 0.0
    return precision, recall, f1


def print_results(backend_name: str, model: str, results: dict):
    print("=" * 60)
    print(f"Backend : {backend_name}")
    print(f"Model   : {model}")
    print(f"Examples: {len(results['latencies']) + len([f for f in results['failures'] if 'error' in f])}")
    print("=" * 60)

    print("\nPer-label scores:")
    print(f"  {'Label':<10} {'Precision':>10} {'Recall':>10} {'F1':>10}  TP   FP   FN")
    print(f"  {'-'*10} {'-'*10} {'-'*10} {'-'*10}  {'--':>4} {'--':>4} {'--':>4}")
    for label in sorted(results["per_label"].keys()):
        s  = results["per_label"][label]
        p, r, f = prf(s["tp"], s["fp"], s["fn"])
        print(f"  {label:<10} {p:>10.1%} {r:>10.1%} {f:>10.1%}  {s['tp']:>4} {s['fp']:>4} {s['fn']:>4}")

    t  = results["totals"]
    p, r, f = prf(t["tp"], t["fp"], t["fn"])
    print(f"\nOverall:")
    print(f"  Precision : {p:.1%}")
    print(f"  Recall    : {r:.1%}")
    print(f"  F1        : {f:.1%}")
    print(f"  TP={t['tp']}  FP={t['fp']}  FN={t['fn']}")

    if results["latencies"]:
        lats = results["latencies"]
        lats_sorted = sorted(lats)
        p95 = lats_sorted[int(len(lats_sorted) * 0.95)]
        print(f"\nLatency (ms):")
        print(f"  Mean : {sum(lats)/len(lats):.1f}")
        print(f"  Min  : {min(lats):.1f}")
        print(f"  Max  : {max(lats):.1f}")
        print(f"  p95  : {p95:.1f}")

    misses = [f for f in results["failures"] if "missed" in f]
    fps    = [f for f in results["failures"] if "false_positives" in f]
    errors = [f for f in results["failures"] if "error" in f]

    if misses:
        print(f"\nMissed entities ({len(misses)} examples):")
        for f in misses:
            print(f"  [{f['id']}] missed: {', '.join(f['missed'])}")

    if fps:
        print(f"\nFalse positives ({len(fps)} examples):")
        for f in fps:
            print(f"  [{f['id']}] flagged: {', '.join(f['false_positives'])}")

    if errors:
        print(f"\nErrors ({len(errors)}):")
        for f in errors:
            print(f"  [{f['id']}] {f['error']}")

    print()


def main():
    fixtures = json.loads(FIXTURES_PATH.read_text())
    backend_name, backend = load_backend()
    results = run_benchmark(backend, fixtures)
    print_results(backend_name, backend.model_name(), results)


if __name__ == "__main__":
    main()
