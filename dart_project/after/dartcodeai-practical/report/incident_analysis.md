# Incident Analysis

## Observed facts

- The trace contains 20 requests over a 2.15-second window (elapsed_ms 0–2150) at an observed rate of 9.3 req/s.
- queue_depth ramps from 2 (r001) to a peak of 45 (r014), then subsides back to 4 (r020).
- Two HTTP 503 errors occur at r006 (queue_depth=19, latency=1850ms) and r009 (queue_depth=31, latency=1990ms), both from tenant-a targeting `stable-chat`.
- Two HTTP 429 (rate-limited) errors occur at r011 (queue_depth=38, latency=740ms) and r014 (queue_depth=45, latency=690ms), both from tenant-a targeting `stable-chat`.
- All four errors belong exclusively to tenant-a, which accounts for 12 of 20 requests (60% of traffic).
- Seven requests used fallback routing to `hosted-fallback` (r007, r008, r010, r012, r013, r015, r016), all with latencies between 2290ms and 2960ms.
- Non-fallback requests during the high-queue-depth window also show elevated latency (r006=1850ms, r009=1990ms) compared to baseline (r001–r005 range: 420–590ms).
- After queue_depth peaks at r014 and begins subsiding, latencies recover: r017=1710ms, r018=1210ms, r019=820ms, r020=610ms.
- Completion tokens are 0 for all four error requests (r006, r009, r011, r014), confirming no useful generation occurred.
- p95 latency across the trace is 2810ms, exceeding the system design target of 2000ms.
- Fallback requests account for 35% of all requests during this window.

## Most likely causal chain

1. The primary provider (`stable-chat`) became overloaded, evidenced by queue_depth climbing from 2 to 19 when the first 503 appeared (r006).
2. The 503 errors triggered fallback routing to `hosted-fallback`. Fallback requests succeeded but at high latency (2290–2960ms), consuming gateway concurrency slots for longer and further inflating queue_depth.
3. As queue_depth continued rising (31→38→45), the provider or gateway began returning 429 (rate-limited) responses (r011, r014), rejecting tenant-a requests outright.
4. tenant-a's disproportionate 60% traffic share meant it was both the primary driver of queue pressure and the tenant most affected by rate limiting—a positive feedback loop.
5. Once queue_depth peaked and load naturally subsided (fewer new arrivals or completion of inflight requests), latencies recovered within ~700ms of the peak (r017–r020).

## Plausible alternative explanation

The primary provider experienced a brief internal degradation (e.g., GC pause, node failover, or upstream dependency hiccup) unrelated to tenant-a's traffic volume. The 503s were a provider-side issue, and the subsequent 429s were the provider's own rate-limiting kicking in protectively. In this scenario, tenant-a's dominance is a correlation (it generated most requests, so it hit most errors) rather than the cause. The queue_depth rise would be a symptom of slow-draining inflight requests, not a cause of provider failure.

## Unknowns that matter

- Whether queue_depth reflects the gateway's own queue or is a metric forwarded from the provider — this determines whether backpressure is a gateway concern or a provider concern.
- What caused the initial queue_depth increase from 2 to 19 before the first 503 — was it a burst from tenant-a, or were responses already slowing before errors appeared?
- Whether the 429s are gateway-enforced rate limits or provider-returned rate limits — this determines whether the gateway's own admission control participated in mitigation.
- Whether there are retry loops: did failed requests generate retries that amplified queue pressure?
- The hosted-fallback provider's baseline latency under normal conditions — the 2290–2960ms range may be its normal performance, not a sign of stress.
- Whether other tenants' requests were affected (tenant-b and tenant-c show 0 errors, but they may have experienced elevated latency during the window).

## First three production checks

1. **Check primary provider health dashboard and status page** for the timestamp window — look for reported degradation, elevated error rates, or capacity alerts on the `stable-chat` model endpoint.
2. **Query gateway metrics for tenant-a's request rate** in the 30 seconds preceding r001 — determine whether tenant-a's traffic was a burst above its normal baseline or steady-state load that the provider could not absorb.
3. **Examine whether the 429 responses originated from the gateway's own rate limiter or from the upstream provider** — check gateway logs for internal rate-limit decisions vs passthrough of upstream 429s.

## Immediate mitigation and rollback trigger

- **Immediate mitigation:** Enable per-tenant admission control for tenant-a, capping its inflight concurrency to prevent one tenant from saturating the provider queue. If not already in place, activate a circuit breaker on the primary provider that trips after two consecutive 503s within a sliding window, routing all traffic to `hosted-fallback` early rather than letting queue_depth climb to 45.
- **Rollback trigger:** If fallback error rate exceeds 10% or fallback p95 latency exceeds 4000ms, halt fallback routing and return errors directly to callers with retry-after headers — the fallback provider may also be at risk of overload if the primary remains down.

## Durable correction

- Implement per-tenant concurrency quotas proportional to entitlement, so that no single tenant can consume more than its fair share of provider capacity (e.g., tenant-a capped at 40% of max concurrency despite producing 60% of requests).
- Add adaptive load shedding at the gateway layer: when queue_depth exceeds a threshold (e.g., 20), begin rejecting lowest-priority requests with 429 + Retry-After before the provider itself fails with 503.
- Instrument a fallback latency budget: if fallback requests consistently exceed the p95 SLO (2000ms), log a warning and include fallback latency in SLO calculations rather than masking it as a "success."
- Establish a queue_depth alert at threshold 15 (below the first 503 at depth 19) to enable proactive investigation before errors begin.

## Recovery proof

- **Metrics:** p95 latency, error rate (503 + 429), fallback rate, and queue_depth — all measured per-tenant and globally.
- **Comparison window:** Compare the 24-hour period after deploying the fix against the 24-hour period containing the incident, and against a 7-day historical baseline (same day-of-week).
- **Success criteria:**
  - p95 latency ≤ 2000ms (within SLO target) sustained for 24 hours.
  - Error rate < 1% (vs the 20% observed during the incident).
  - Fallback rate < 5% (vs the 35% observed).
  - queue_depth remains below 20 under equivalent or higher load.
  - No single tenant accounts for more than 50% of errors.
