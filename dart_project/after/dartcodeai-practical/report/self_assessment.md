# Self-Assessment

> **⚠️ YOU MUST REVIEW AND PERSONALIZE THIS FILE.** Update the sections below to honestly reflect your own assessment of the submission. The live review will probe these answers.

## Strongest part of the submission

- The incident analysis (Part C) is grounded entirely in observable trace data: every claim about queue_depth correlation, tenant-a error concentration, and fallback latency is traceable to specific rows in gateway_trace.csv. The causal chain distinguishes facts from hypotheses and identifies unknowns rather than speculating.

## Weakest or least certain part

- The experience reflection (Part E) — [REPLACE: state honestly which section you feel least confident about and why].
- The nearest-rank percentile implementation: while the formula is standard (ceil-based ranking), edge cases around very small N or percentiles near 0 could behave unexpectedly. I validated against known test vectors but did not exhaustively test boundary conditions.

## Incomplete work and why

- [REPLACE: list anything you didn't finish within the timebox and explain what remains].

## First improvement with one more day

- Add property-based tests for the Dart normalizer using a fuzzing library, especially for malformed payloads with unexpected types, missing keys, and deeply nested structures. The current tests cover the supplied fixtures and key boundaries, but production providers return surprising payloads that fixture-based tests may not anticipate.

## One decision you would want reviewed before production

- The structural detection strategy for provider response formats (checking for `choices` key vs `output` key in `normalizeSuccess`). In production with more than two providers, this heuristic could break if a new provider's response happens to contain a `choices` key with different semantics. A more robust approach would be to pass the provider type explicitly and dispatch to format-specific parsers — but this wasn't available in the method signature.
