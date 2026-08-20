#!/usr/bin/env python3
"""Analyze DartCodeAI gateway telemetry using only the standard library."""

from __future__ import annotations

import argparse
import csv
import json
import math
from pathlib import Path
from typing import Any, Iterable


def nearest_rank_percentile(values: list[float], percentile: float) -> float:
    """Return the nearest-rank percentile for non-empty, sorted-input values.

    Nearest-rank method: rank = ceil(P/100 * N), return value at that rank
    (1-indexed). This always returns an actual observed value from the dataset,
    unlike linear-interpolation methods.
    """
    if not values:
        raise ValueError("Cannot compute percentile of empty list.")
    if not (0 < percentile <= 100):
        raise ValueError(f"Percentile must be in (0, 100], got {percentile}")

    sorted_vals = sorted(values)
    n = len(sorted_vals)
    # Nearest-rank: rank = ceil(P/100 * N), 1-indexed
    rank = math.ceil(percentile / 100.0 * n)
    # Clamp to valid range (rank is always >= 1 from ceil on positive inputs)
    rank = min(rank, n)
    return sorted_vals[rank - 1]


def _require_int(row: dict[str, str], field: str, row_num: int) -> int:
    """Parse a required integer field, raising ValueError with row context."""
    raw = row.get(field)
    if raw is None or raw.strip() == "":
        raise ValueError(
            f"Row {row_num}: required field '{field}' is missing or empty."
        )
    try:
        return int(raw)
    except (ValueError, TypeError):
        raise ValueError(
            f"Row {row_num}: field '{field}' is not a valid integer: {raw!r}"
        )


def _require_str(row: dict[str, str], field: str, row_num: int) -> str:
    """Parse a required string field, raising ValueError if missing/empty."""
    raw = row.get(field)
    if raw is None or raw.strip() == "":
        raise ValueError(
            f"Row {row_num}: required field '{field}' is missing or empty."
        )
    return raw.strip()


def summarize(rows: Iterable[dict[str, str]]) -> dict[str, Any]:
    """Validate trace rows and return the required deterministic summary.

    Rejects malformed required numeric fields with a useful row number.
    Does not silently treat missing data as zero.
    Output is deterministic: same input produces byte-identical JSON output.
    """
    request_count = 0
    error_count = 0
    status_counts: dict[str, int] = {}
    latencies: list[float] = []
    total_prompt_tokens = 0
    total_completion_tokens = 0
    fallback_count = 0
    elapsed_values: list[int] = []

    # Per-tenant counters
    tenants: dict[str, dict[str, int]] = {}

    for row in rows:
        request_count += 1
        row_num = request_count  # 1-indexed row number (data rows only)

        # Parse and validate all required numeric fields
        elapsed_ms = _require_int(row, "elapsed_ms", row_num)
        status_code = _require_int(row, "status_code", row_num)
        latency_ms = _require_int(row, "latency_ms", row_num)
        prompt_tokens = _require_int(row, "prompt_tokens", row_num)
        completion_tokens = _require_int(row, "completion_tokens", row_num)

        # Required string fields
        tenant_id = _require_str(row, "tenant_id", row_num)
        fallback_used = _require_str(row, "fallback_used", row_num)

        # Track elapsed for observed_rps
        elapsed_values.append(elapsed_ms)

        # Status code counting
        status_key = str(status_code)
        status_counts[status_key] = status_counts.get(status_key, 0) + 1

        # Error detection: non-2xx is an error
        is_error = status_code < 200 or status_code >= 300
        if is_error:
            error_count += 1

        # Latency
        latencies.append(float(latency_ms))

        # Tokens
        total_prompt_tokens += prompt_tokens
        total_completion_tokens += completion_tokens

        # Fallback
        if fallback_used.lower() == "true":
            fallback_count += 1

        # Per-tenant tracking
        if tenant_id not in tenants:
            tenants[tenant_id] = {"requests": 0, "errors": 0}
        tenants[tenant_id]["requests"] += 1
        if is_error:
            tenants[tenant_id]["errors"] += 1

    if request_count == 0:
        raise ValueError("Trace file contains no data rows.")

    # Compute rates
    success_count = request_count - error_count
    success_rate = success_count / request_count
    error_rate = error_count / request_count
    fallback_rate = fallback_count / request_count

    # Latency percentiles (nearest-rank, integer output)
    p50 = int(nearest_rank_percentile(latencies, 50))
    p95 = int(nearest_rank_percentile(latencies, 95))
    p99 = int(nearest_rank_percentile(latencies, 99))
    max_latency = int(max(latencies))

    # Observed requests per second
    # Time span is max(elapsed) - min(elapsed) in milliseconds
    if len(elapsed_values) <= 1:
        observed_rps = 0.0
    else:
        time_span_ms = max(elapsed_values) - min(elapsed_values)
        if time_span_ms == 0:
            observed_rps = 0.0
        else:
            time_span_s = time_span_ms / 1000.0
            observed_rps = round(request_count / time_span_s, 4)

    # Sort status_counts and tenants by key for deterministic output
    sorted_status_counts = dict(sorted(status_counts.items()))
    sorted_tenants = dict(sorted(tenants.items()))

    return {
        "request_count": request_count,
        "success_rate": success_rate,
        "error_rate": error_rate,
        "status_counts": sorted_status_counts,
        "latency_ms": {
            "p50": p50,
            "p95": p95,
            "p99": p99,
            "max": max_latency,
        },
        "tokens": {
            "prompt": total_prompt_tokens,
            "completion": total_completion_tokens,
            "total": total_prompt_tokens + total_completion_tokens,
        },
        "fallback_count": fallback_count,
        "fallback_rate": fallback_rate,
        "observed_rps": observed_rps,
        "tenants": sorted_tenants,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("trace", type=Path)
    args = parser.parse_args()

    with args.trace.open(newline="", encoding="utf-8") as handle:
        summary = summarize(csv.DictReader(handle))
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
