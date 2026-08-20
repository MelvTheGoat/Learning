# System Design — 10,000 requests/minute

## Assumptions

- "Request" means one AI gateway call (chat completion or embedding), which results in one upstream provider call (or two, if fallback triggers).
- Provider response latency is the dominant component of end-to-end latency; gateway overhead (routing, metering, serialization) is ≤ 20ms.
- The self-hosted candidate provider and the hosted fallback provider are independently scaled; the gateway does not control their internal capacity.
- Fallback is used at most once per request; cascading multi-provider fallback chains are not in scope.
- Credential rotation is handled by a secrets manager; the gateway fetches credentials at startup and on rotation events, never from product applications.
- "Zero-rated internal brands" still generate metering records; the billing layer decides whether to charge, not the gateway.

## Capacity arithmetic

### Sustained load

- 10,000 requests/minute = **167 requests/second** sustained.
- At p95 provider latency ~2s, each inflight request occupies a concurrency slot for ~2s.
- Concurrent requests at steady state: 167 req/s × 2s = **334 concurrent requests**.
- With 30% headroom for variance: provision for **~435 concurrent slots**.

### Burst load

- 18,000 requests/minute for 2 minutes = **300 requests/second** burst.
- At 2s response time: 300 × 2 = **600 concurrent requests** during burst.
- With 30% headroom: **~780 concurrent slots**.
- Burst produces 36,000 requests in 2 minutes vs 20,000 at sustained rate — an additional 16,000 requests that must either be served, queued, or shed.

### Bottleneck expectation

The first bottleneck is **upstream provider concurrency limits**. The gateway itself is stateless HTTP routing (horizontally scalable), but if the primary provider only supports N concurrent requests, requests queue at the gateway once N is exceeded. The trace data confirms this: queue_depth climbing to 45 preceded 503/429 errors.

### Gateway instance sizing

- If each gateway instance handles ~100 concurrent connections (conservative, async I/O): 780 / 100 = **8 instances minimum** during burst.
- At sustained load: 435 / 100 = **5 instances minimum**.
- Recommend **8 instances** with auto-scaling from 5 to 12 based on active connection count.

## Request path and ownership boundaries

```
Product App → Gateway (LB) → [Auth + Entitlement] → [Admission Control] → [Provider Router]
                                                                              ↓
                                                               Primary Provider (self-hosted)
                                                                    ↓ (on failure)
                                                               Fallback Provider (hosted)
                                                                              ↓
                                                              ← [Normalize Response] ←
                                                              ← [Meter Usage] ←
                                                              ← [Return to Product App] ←
```

**Ownership boundaries:**
- **Product teams** own the application and request semantics; they never see provider credentials or raw provider responses.
- **Gateway team** owns routing, normalization, admission control, metering, and fallback policy.
- **Provider team** (for self-hosted) owns model serving, scaling, and health; the gateway treats it as a black box behind an HTTP contract.
- **Platform/security team** owns the secrets manager and credential rotation lifecycle.

## Admission control, backpressure, and tenant fairness

### Per-tenant concurrency quotas

- Three tenants; one produces ~50% of traffic.
- Assign per-tenant concurrency limits proportional to entitlement, with a cap so no single tenant exceeds 50% of total provider capacity:
  - High-traffic tenant: max 50% × 780 = **390 concurrent slots** during burst.
  - Two remaining tenants: max 25% each = **195 concurrent slots** each.
- These are soft limits; unused capacity from one tenant is available to others. The limit only enforces when contention exists.

### Backpressure mechanism

- When a tenant's inflight count reaches its limit, return **429 with Retry-After header** immediately — do not queue indefinitely.
- When global queue_depth exceeds 80% of capacity (e.g., >624 during burst), begin shedding lowest-priority requests across all tenants.
- Priority tiers: paid tenants > free/internal tenants > batch/async requests (if applicable).

### Queue depth circuit breaker

- If queue_depth exceeds a sustained threshold (e.g., >500 for >10 seconds), trip the circuit breaker: reject new requests with 503 and a machine-readable reason, rather than allowing unbounded queue growth.

## Provider routing and fallback budget

### Routing strategy

- Default route: self-hosted candidate provider for chat; select by capability for embeddings (not all providers support both).
- Fallback route: hosted fallback provider, used only when the primary returns 5xx or times out (per the canonical fallback rules in Part A).
- Fallback is attempted at most once per request.

### Fallback budget protection

- Cap fallback usage at **20% of total request volume** over a 1-minute sliding window. Beyond this, return errors to callers rather than overwhelming the fallback provider.
- Rationale: during a sustained primary outage, routing 100% of traffic to the fallback can cause the fallback to degrade too (cascading failure). The budget forces graceful degradation.
- Monitor fallback rate with a 1-minute tumbling window; alert at 10%, enforce at 20%.

### Fallback cost awareness

- The hosted fallback has per-token costs. The budget also protects against unexpected cost spikes during primary outages.

## Metering, auditability, and credential boundaries

### Metering

- Every request — successful, failed, fallback, zero-rated — generates a metering event containing: request ID, tenant ID, model requested, model served, prompt tokens, completion tokens, latency, status code, fallback_used, timestamp.
- Metering events are written to an append-only event stream (e.g., Kafka topic, Cloud Pub/Sub) for downstream billing and analytics.
- Zero-rated internal brands produce identical metering events; the billing service applies pricing rules, not the gateway.
- Token counts come from the provider response (for successes) or are estimated from the request (for failures where no provider response was received).

### Credential boundaries

- Provider API keys and credentials are stored in a secrets manager (e.g., HashiCorp Vault, AWS Secrets Manager, GCP Secret Manager).
- The gateway fetches credentials at startup and caches them in memory; it refreshes on a rotation signal or TTL expiry.
- Credentials never appear in logs, error messages, metering events, or responses to product applications.
- Product applications authenticate to the gateway via their own tenant-scoped tokens (e.g., API keys or JWTs); they have no mechanism to specify or discover provider credentials.
- The `CanonicalFailure` contract (Part A) ensures upstream error payloads are never forwarded verbatim — only safe, static messages are returned.

## Observability and SLOs

### SLOs

| Metric | Target | Measurement window |
| --- | --- | --- |
| Gateway availability (non-5xx responses) | 99.9% | 30-day rolling |
| p95 end-to-end latency (excluding provider outages) | ≤ 2,000ms | 1-hour rolling |
| Metering completeness (events emitted / requests received) | 99.99% | 24-hour |
| Fallback success rate (when invoked) | ≥ 95% | 1-hour rolling |

### Key metrics to instrument

- **Request rate** (per tenant, per model, per provider) — detect traffic shifts and potential abuse.
- **Error rate** (per canonical error code) — distinguish provider issues from gateway issues.
- **Latency percentiles** (p50, p95, p99) per provider and per tenant.
- **Queue depth** — leading indicator of saturation; alert at threshold before errors begin (e.g., alert at depth 15, the trace showed errors starting around depth 19).
- **Fallback rate** — early warning of primary provider degradation.
- **Token throughput** — capacity planning and cost forecasting.
- **Concurrent connections per gateway instance** — auto-scaling signal.

### Alerting

- queue_depth > 15 sustained for 30s → page on-call.
- Error rate > 5% over 1 minute → page on-call.
- Fallback rate > 10% over 1 minute → warn.
- p95 latency > 2000ms over 5 minutes → warn; > 3000ms → page.

## Rollout, rollback, and failure drills

### Rollout strategy

- **Canary deployment:** Route 5% of traffic to the new gateway version for 15 minutes. Compare error rate, latency, and fallback rate against the stable version.
- **Progressive rollout:** If canary metrics are within SLO, expand to 25% → 50% → 100% over 1 hour.
- **Feature flags:** New routing logic, admission control rules, and fallback policies behind feature flags that can be toggled without redeployment.

### Rollback

- **Automated rollback trigger:** If error rate exceeds 2× the baseline or p95 latency exceeds 3000ms during canary/rollout, automatically revert to the previous version.
- **Manual rollback:** One-command rollback to the previous known-good deployment via CI/CD pipeline. Target rollback time: < 2 minutes.
- **Credential rollback:** If a credential rotation causes auth failures (401/403 spike), the secrets manager must support reverting to the previous credential version.

### Failure drills

- **Monthly chaos test:** Simulate primary provider outage (inject 503s) and verify that fallback routing activates correctly, fallback budget is enforced, metering continues, and alerting fires within expected thresholds.
- **Tenant isolation test:** Simulate one tenant sending 5× normal traffic and verify that per-tenant admission control protects the other tenants' latency and error rate.
- **Queue saturation test:** Inject artificial latency into provider responses and verify that the gateway sheds load gracefully via 429s rather than queueing indefinitely.
