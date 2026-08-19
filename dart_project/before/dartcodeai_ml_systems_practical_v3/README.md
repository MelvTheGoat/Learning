# DartCodeAI Level 4 ML Systems Practical - Candidate Brief v3

## Purpose

This assessment evaluates whether you can own a production ML system boundary and help turn an AI Lab idea into a defensible product experiment. You must normalize provider behavior, reason from telemetry, protect a multi-tenant service under failure, connect technical choices to business outcomes, and explain decisions with evidence.

DartCodeAI provides model-agnostic AI capabilities to Dart and Flutter products. Product code calls an AI gateway rather than model providers directly. The gateway is responsible for stable response and error contracts, provider routing, entitlement and quota enforcement, usage metering, and observable fallback behavior.

## Assessment format

- Take-home implementation: target 3 hours; hard stop at 4 hours.
- Live engineering and business review: 45 minutes after submission.
- Submit incomplete work when the timebox ends. Explain what remains and how you would finish it.
- Do not include employer-confidential code, data, credentials, or incident details.

### Tool and AI policy

Documentation, search, IDE assistance, and AI tools are allowed. Tool use is not penalized. You must:

1. record material assistance in `report/tool_use_log.md`;
2. validate every accepted suggestion yourself;
3. be able to explain, run, debug, and change every submitted line during the live review; and
4. work independently - do not outsource the assessment to another person.

We score demonstrated ownership, critical thinking, business judgment, and adaptability. Polished prose without reproducible evidence does not receive credit.

## What to submit

Preserve this layout:

```text
dart/
  lib/gateway_normalizer.dart
  test/gateway_normalizer_test.dart
python/
  analyze_trace.py
fixtures/
report/
  incident_analysis.md
  system_design.md
  ai_lab_business_case.md
  experience_reflection.md
  self_assessment.md
  tool_use_log.md
  run_evidence.txt
```

Do not submit `.env` files, API keys, credentials, build output, or package caches.

## Part A - Harden the gateway boundary

Implement the TODOs in `dart/lib/gateway_normalizer.dart`.

### A1. Normalize successful provider responses

Support both supplied success fixtures while returning the provider-neutral `AiRuntimeSuccess` envelope already defined in the starter. The normalized output must include:

- request ID and provider ID supplied by the gateway;
- `output.text`;
- standardized prompt, completion, and total token counts;
- finish reason when present;
- routing metadata supplied by the gateway; and
- UTC completion time.

Do not expose provider-specific response objects outside the normalizer.

### A2. Normalize failures

Map upstream failures into the canonical error codes in the starter:

| Upstream condition | Canonical code | HTTP | Retryable | Failover eligible |
| --- | --- | ---: | --- | --- |
| 429 | `rate_limited` | 429 | yes | no |
| 413 | `context_length_exceeded` | 413 | no | no |
| 401/403 | `auth_error` | 401 | no | no |
| explicit content filter | `content_filtered` | 422 | no | no |
| explicit unsupported capability | `capability_unsupported` | 422 | no | no |
| timeout/504 | `timeout` | 504 | yes | yes |
| upstream 5xx | `provider_unavailable` | 503 | yes | yes |
| malformed or unrecognized response | `invalid_provider_response` | 502 | no | no |

Return safe messages. Do not leak credentials, authorization headers, or full upstream bodies.

### A3. Decide fallback safely

Fallback is permitted only when all of these are true:

- a different fallback provider/model is configured;
- fallback has not already been attempted; and
- the canonical error is `timeout` or `provider_unavailable` caused by upstream 5xx.

Do not fallback for rate limits, authentication, invalid input, content filters, unsupported capability, or malformed provider responses. The decision must include a machine-readable reason.

### A4. Validate embedding similarity

Implement cosine similarity and fail clearly for empty vectors, dimension mismatch, zero-norm vectors, and non-finite values. Never pad or truncate vectors to make dimensions match.

### A5. Tests

Keep the visible tests passing and add tests that demonstrate the most important boundaries you found. We will run additional tests that are not included in the candidate bundle.

## Part B - Analyze production telemetry

Implement `python/analyze_trace.py` using only the Python standard library.

For `fixtures/gateway_trace.csv`, output JSON containing request count; success/error rates; status-code counts; latency p50, p95, p99, and maximum using nearest-rank percentiles; total prompt, completion, and combined tokens; fallback count/rate; observed requests/second; and request/error counts per tenant.

Use this stable output shape. Rates are fractions from `0.0` to `1.0`; round `observed_rps` to four decimal places and leave integer percentiles as integers.

```json
{
  "request_count": 2,
  "success_rate": 0.5,
  "error_rate": 0.5,
  "status_counts": {"200": 1, "503": 1},
  "latency_ms": {"p50": 400, "p95": 900, "p99": 900, "max": 900},
  "tokens": {"prompt": 20, "completion": 5, "total": 25},
  "fallback_count": 1,
  "fallback_rate": 0.5,
  "observed_rps": 2.0,
  "tenants": {
    "tenant-a": {"requests": 1, "errors": 0},
    "tenant-b": {"requests": 1, "errors": 1}
  }
}
```

The numbers above illustrate the schema only; they are not the expected result for the supplied trace.

Reject malformed required numeric fields with a useful row number, do not silently treat missing data as zero, make output deterministic, and add focused tests or equivalent repeatable validation. Put exact commands and outputs in `report/run_evidence.txt`.

## Part C - Incident reasoning

Use the trace and analyzer output to complete `report/incident_analysis.md`. Separate observations from hypotheses. Identify the likely causal chain, an alternative explanation, first three checks, immediate mitigation and rollback trigger, durable correction, and recovery metrics. Generic technology lists receive no credit without trace evidence.

## Part D - Practical system design

Complete `report/system_design.md` for this scenario:

- 10,000 requests/minute sustained, with a two-minute burst to 18,000/minute;
- p95 gateway latency target under 2 seconds outside provider outages;
- three tenants, where one tenant may produce 50% of traffic;
- chat and embedding capabilities with different provider support;
- a self-hosted candidate provider and a hosted fallback provider;
- usage must remain metered even for zero-rated internal brands; and
- provider credentials must never reach product applications.

Include concrete capacity arithmetic, admission/backpressure behavior, tenant fairness, fallback budget protection, observability, rollout, and rollback.

## Part E - Experience and ownership

Complete the experience reflection and self-assessment honestly. You may anonymize organizations and systems. Clearly label hypothetical experience as hypothetical.

A passing result requires evidence of personal ownership in at least one relevant engineering delivery, incident, or high-stakes technical decision. You must be able to discuss your own actions, evidence, changed assumptions, and measured outcome.

## Part F - AI Lab problem framing and business experiment

Complete `report/ai_lab_business_case.md` for this intentionally incomplete scenario:

An AI Lab is considering a pull-request risk briefing capability for engineering teams. The proposed system reviews a code change and produces a short risk summary before human review.

Known information:

- the pilot covers three product teams and about 1,200 pull requests per month;
- current median time from pull-request opening to first meaningful review is 18 hours;
- stakeholders believe the capability could reduce review delay, but no trustworthy baseline connects review delay to escaped defects;
- a hosted model is estimated at `$0.18` per run and early prototypes average `2.5` runs per pull request;
- a self-hosted option may reduce variable inference cost but adds operational ownership and an estimated `$30,000` setup effort;
- false confidence, noisy recommendations, source-code privacy, and reviewer disengagement are material risks; and
- the lab has six weeks and a `$25,000` pilot budget to produce a go, pivot, or stop recommendation.

Your response must:

1. define the target user, job-to-be-done, and business decision the pilot enables;
2. distinguish known facts, assumptions, and important unknowns;
3. select one primary business outcome, model/product quality measures, and safety/adoption guardrails;
4. propose a falsifiable pilot with a baseline or control, sample/segment plan, and evidence collection method;
5. estimate hosted-model unit cost for the pilot and at 30,000 pull requests per month, then discuss what is missing from that estimate;
6. compare hosted, self-hosted, and a credible non-ML baseline without pretending uncertain inputs are known;
7. prioritize the first three activities and explain what you deliberately defer;
8. define numerical or observable go, pivot, and stop thresholds; and
9. make a recommendation that a product and finance leader could challenge.

We are not looking for a predetermined product pitch. Strong answers identify uncertainty, avoid vanity metrics, connect model behavior to user and business impact, and design the cheapest credible test of the riskiest assumption.

## Live review

In the live review you will run one happy and one failure path, trace a request, receive a requirement change/new incident signal/business constraint, defend a technical tradeoff and business assumption, and revise a decision after new evidence.

The live change is not a speed contest. We evaluate how you inspect evidence, test assumptions, and protect system and business outcomes.

## Submission checklist

- [ ] Dart implementation and tests run.
- [ ] Python analyzer runs without third-party packages.
- [ ] `run_evidence.txt` contains commands and unedited output.
- [ ] Incident analysis distinguishes facts, hypotheses, and unknowns.
- [ ] System design includes capacity arithmetic and failure policy.
- [ ] AI Lab business case includes a falsifiable pilot, unit economics, and go/pivot/stop thresholds.
- [ ] Experience reflection and self-assessment are complete.
- [ ] Material tool/AI assistance is recorded.
- [ ] No secrets, proprietary data, or generated build output are included.
