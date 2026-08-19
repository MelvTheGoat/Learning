# Machine Learning Systems Engineering — Primer
This document covers the core concepts tested by the DartCodeAI assignment. The role sits at the intersection of backend systems engineering and ML infrastructure — you're not training models, you're building the platform that serves them reliably at scale.
---
## 1. What is ML Systems Engineering?
ML Systems Engineering is about everything *around* the model: how requests reach it, how responses come back, how failures are handled, how costs are controlled, and how the whole thing stays up at 3 AM. Think of it as **backend engineering where the "database" is a non-deterministic, expensive, rate-limited third-party API** that occasionally hallucinates, times out, or costs $0.15 per call.
**Key distinction from ML Engineering / Data Science:**
- ML Engineer: "How do I make the model more accurate?"
- ML Systems Engineer: "How do I serve this model to 10,000 users per minute without going broke or dropping requests?"
---
## 2. The AI Gateway Pattern
This is the central architectural pattern in this assignment. An **AI Gateway** sits between your product applications and one or more LLM providers (OpenAI, Anthropic, internal models, etc.).
### Why not just call the provider directly?
- **Provider abstraction:** Your product code shouldn't care whether the response came from OpenAI or your internal model. The gateway normalizes everything into one canonical format.
- **Failover:** If OpenAI goes down, the gateway silently routes to a fallback provider. The product app never knows.
- **Rate limiting & tenant fairness:** One noisy customer shouldn't exhaust your shared API quota.
- **Cost control:** You can route cheaper requests to cheaper models.
- **Security:** API keys stay in the gateway. Product apps never see provider credentials.
- **Observability:** One place to log every request, measure latency, count tokens, track errors.
### Request flow:
```
Product App → AI Gateway → Provider A (primary)
                         ↘ Provider B (fallback, if A fails)
                         → Normalize response → Return to Product App
```
### What "normalization" means:
Every provider returns data in a different shape. OpenAI uses `choices[0].message.content` for the text. Another provider might use `output.text`. The gateway's job is to map all of these into one standard envelope (`AiRuntimeSuccess`) so the product app has a single, stable interface.
---
## 3. Error Taxonomy & Canonical Error Codes
In production ML systems, you can't just return raw HTTP errors to the caller. A 429 from OpenAI means something different than a 429 from your own rate limiter. The gateway maps every upstream error to a **canonical error code** that the product app can act on without knowing which provider was involved.
### Why order of error checks matters:
```
1. Payload-level error codes  (e.g., content_filtered)
2. Timeout signals            (timedOut flag, HTTP 504)
3. HTTP status codes          (429, 413, 401, 5xx)
4. Fallthrough                (invalid_provider_response)
```
Payload codes come first because a provider might return `content_filtered` as an HTTP 400, 403, or 422 depending on its implementation. If you check HTTP status first, you'll misclassify it.
### The canonical codes and what they mean:
|
 Code 
|
 Meaning 
|
 Retryable? 
|
 Can Fallback? 
|
|
---
|
---
|
---
|
---
|
|
`rate_limited`
|
 Your quota is exhausted 
|
 Yes (after backoff) 
|
 No — quota problem, not outage 
|
|
`context_length_exceeded`
|
 Input too long for model 
|
 No — same input will always fail 
|
 No 
|
|
`auth_error`
|
 Bad or expired API key 
|
 No — config problem 
|
 No 
|
|
`content_filtered`
|
 Model refused (safety filter) 
|
 No — same input will always be refused 
|
 No 
|
|
`timeout`
|
 Provider didn't respond in time 
|
 Yes 
|
**
Yes
**
 — transient outage 
|
|
`provider_unavailable`
|
 Provider returned 5xx 
|
 Yes 
|
**
Yes
**
 — transient outage 
|
|
`invalid_provider_response`
|
 Response was garbage/unparseable 
|
 No 
|
 No 
|
### Key insight: only transient outages get fallback
Fallback is expensive (you're now paying two providers) and limited (the fallback provider has finite capacity too). You only want to use it when the primary is genuinely down, not when:
- You've exhausted your rate limit (fallback won't help — it's your problem)
- The model refused the content (fallback will also refuse it)
- Your API key is wrong (you need to fix your config, not switch providers)
---
## 4. Fallback & Failover Strategy
### Single-attempt fallback:
The assignment uses a **single-attempt failover** model: if the primary fails with an eligible error, try the fallback once. If the fallback also fails, return the error. No retry chains, no cascading fallback to a third provider.
### The three gates:
Every fallback decision must pass three checks:
1. **Is a fallback configured?** (Not all routes have one)
2. **Has it already been tried?** (At most one attempt — prevents infinite loops)
3. **Is the error eligible?** (Only timeout and provider_unavailable)
### Fallback budget:
In a real system, you'd also enforce a **circuit breaker** or **budget cap**. If the primary is fully down and 100% of traffic floods the fallback, the fallback will also go down → cascading failure. A 20% budget cap means you sacrifice 80% of requests during a total outage, but the system stays alive.
---
## 5. Capacity Planning
Capacity planning for ML systems follows the same principles as any web service, but with one crucial difference: **LLM calls are slow** (1-3 seconds vs. 50ms for a typical database query). This means you need far more concurrency slots.
### The formula:
```
Concurrency = Request Rate × Response Time
```
Example:
- 300 req/s burst × 2s p95 response time = 600 concurrent connections
- Add 30% headroom = 780 slots needed
- At 100 slots per gateway instance = 8 instances
### Why use p95 response time, not median:
Capacity planning is about **worst realistic case**. If you plan for the median (e.g., 500ms), then during a slow period, your system overloads because half the requests take longer. The p95 SLO target (2s) ensures you can handle the load even when responses are slow.
### The gateway is rarely the bottleneck:
The gateway is stateless HTTP routing — it's just shuffling JSON. The real bottleneck is **upstream provider concurrency limits**. Providers like OpenAI limit how many requests you can have in-flight simultaneously. When you hit that limit, requests queue up, queue depth rises, latency spikes, and eventually you get 429s and 503s. This is exactly what the trace data shows.
---
## 6. Multi-Tenancy & Tenant Fairness
When multiple teams or customers share one AI gateway, you need **tenant isolation** to prevent one noisy tenant from starving the others.
### Token bucket / concurrency quotas:
- High-tier tenant (50% of traffic): max 50% of concurrent slots
- Standard tenants: max 25% each
- These are **soft limits** — unused capacity spills to other tenants
- Only enforced **under contention** (when total demand > capacity)
### Why soft limits:
Hard limits waste capacity. If tenant-b is idle, tenant-a should be able to use that capacity. But the moment tenant-b sends traffic, tenant-a gets throttled back to its fair share.
### Per-tenant observability:
You need to track error rates, latency, and token usage **per tenant**, not just globally. A global 95% success rate might hide the fact that one tenant has a 50% error rate while others are at 100%.
---
## 7. Observability & Trace Analysis
### What a trace is:
A **trace** is a log of every request that passed through the system, with timing and outcome data. Each row typically includes:
- `elapsed_ms`: when the request arrived (relative to trace start)
- `request_id`: unique identifier
- `tenant_id`: who sent it
- `status_code`: HTTP response code
- `latency_ms`: how long it took
- `prompt_tokens` / `completion_tokens`: LLM-specific cost metrics
- `fallback_used`: whether the fallback provider was involved
- `queue_depth`: how congested the system was at that moment
### What you look for in traces:
1. **Correlation, not causation:** "Queue depth was high AND errors occurred" ≠ "Queue depth caused errors". Could be a common upstream cause.
2. **Tenant concentration:** Are errors evenly distributed or concentrated on one tenant?
3. **Time ordering:** Did queue_depth spike before or after the first error?
4. **Recovery pattern:** Did the system self-heal, or did it require intervention?
### Percentile calculations:
Latency is always reported as percentiles, not averages. Averages hide outliers.
- **p50 (median):** Half of requests are faster than this. Represents typical experience.
- **p95:** 95% of requests are faster. This is usually the SLO target. If your p95 is 2s, then 1 in 20 requests takes longer than 2s.
- **p99:** 99% of requests are faster. Represents worst-case for most users.
**Nearest-rank method:** `rank = ceil(P/100 × N)`, then take the value at that rank from the sorted array. This always returns an actual observed value, not an interpolated synthetic one.
---
## 8. SLOs, SLAs, and Error Budgets
### SLO (Service Level Objective):
An internal target. "p95 latency < 2000ms" or "99.9% availability". This is what you engineer towards.
### SLA (Service Level Agreement):
A contractual promise to customers. Usually weaker than the SLO (you build margin). "99.5% availability or we give you credits."
### Error Budget:
The acceptable amount of failure. If your SLO is 99.9% availability, your error budget is 0.1% — roughly 43 minutes of downtime per month. Once you've burned your error budget, you freeze deployments and focus on reliability.
### How SLOs relate to this assignment:
The trace shows p95 latency at 2810ms during the incident, breaching a 2000ms SLO. But this is an **incident window**, not steady-state. The right response is to prevent the incident from recurring (capacity controls, queue limits), not to relax the SLO.
---
## 9. Cost Engineering for LLM Systems
LLM inference is expensive compared to traditional APIs. Key cost drivers:
### Token-based pricing:
- **Prompt tokens:** The input (user's question + context). You control this via prompt engineering and context window management.
- **Completion tokens:** The output (model's response). Harder to control — depends on the model's verbosity.
- Typical pricing: $0.01–$0.10 per 1K tokens (varies wildly by model and provider).
### Cost per business action:
Don't think in tokens — think in business units:
- Cost per PR review = tokens per review × price per token × retries per review
- $0.18 per run × 2.5 runs per PR = $0.45 per PR
- At 30,000 PRs/month = $13,500/month
### Hidden costs people forget:
1. **False positive cost:** If the model gives bad suggestions, engineers waste time investigating them. This human time cost can easily exceed the inference cost.
2. **Retry cost:** Failed requests that get retried still consume tokens on the first attempt.
3. **Infrastructure cost:** The gateway, logging, storage, monitoring — none of this is free.
4. **Self-hosted compute:** GPU instances for self-hosted models have ongoing costs beyond the initial setup.
### Hosted vs. Self-hosted decision:
- **Hosted (API):** Low upfront cost, pay-per-use, fast to start, but ongoing variable cost scales linearly.
- **Self-hosted:** High upfront cost (GPUs, setup, ops), but amortized cost per request is lower at scale.
- **Rule of thumb:** Use hosted for pilots and validation. Switch to self-hosted when monthly hosted costs exceed the amortized self-hosted cost and you have the ops team to manage it.
---
## 10. Security in ML Systems
### Credential isolation:
Provider API keys (Bearer tokens, API keys) must never leak to:
- Product application logs
- Error messages returned to users
- Monitoring dashboards
- Trace data
The gateway is the only component that knows the provider credentials. Error messages use static, hardcoded strings — never content from the upstream response.
### Prompt injection & content filtering:
Models can refuse requests that violate safety policies. The gateway must handle this gracefully (return a clean `content_filtered` error) without exposing the model's internal reasoning or the user's original prompt in the error response.
### Data residency:
When using hosted providers, your data (prompts and completions) transits through their infrastructure. For sensitive workloads, this may require self-hosted models or specific contractual guarantees.
---
## 11. Key Terminology Quick Reference
|
 Term 
|
 Meaning 
|
|
---
|
---
|
|
**
AI Gateway
**
|
 Reverse proxy between your app and LLM providers 
|
|
**
Normalization
**
|
 Converting provider-specific responses to a standard format 
|
|
**
Canonical error
**
|
 A provider-agnostic error code your app can act on 
|
|
**
Failover
**
|
 Routing to a backup provider when the primary fails 
|
|
**
Circuit breaker
**
|
 Automatically stopping requests to a failing service 
|
|
**
Fallback budget
**
|
 Cap on how much traffic the backup provider handles 
|
|
**
Token
**
|
 Basic unit of LLM input/output (roughly 4 characters) 
|
|
**
p95 latency
**
|
 95th percentile — 95% of requests are faster than this 
|
|
**
SLO
**
|
 Internal reliability target (e.g., "p95 < 2s") 
|
|
**
SLA
**
|
 Contractual reliability promise to customers 
|
|
**
Error budget
**
|
 Acceptable amount of SLO violation before action is taken 
|
|
**
Tenant isolation
**
|
 Preventing one customer from degrading others' experience 
|
|
**
Queue depth
**
|
 Number of requests waiting to be processed 
|
|
**
Nearest-rank
**
|
 Percentile method that returns actual observed values 
|
|
**
Cosine similarity
**
|
 Measures angle between two vectors; used for semantic search 
|
|
**
Embedding
**
|
 Vector representation of text for similarity comparison 
|
|
**
Inference
**
|
 Running a trained model to get predictions/completions 
|
---
## 12. How This Assignment Maps to Real-World ML Platform Work
|
 Assignment Part 
|
 Real-World Equivalent 
|
|
---
|
---
|
|
 Part A: normalizeSuccess 
|
 Building the data mapping layer in an API gateway (like Kong, Envoy, or a custom reverse proxy) 
|
|
 Part A: normalizeFailure 
|
 Implementing error classification in a service mesh or API gateway 
|
|
 Part A: decideFallback 
|
 Designing failover policies (similar to Envoy's retry/circuit-breaker config) 
|
|
 Part A: cosineSimilarity 
|
 Core primitive for vector search / RAG (Retrieval-Augmented Generation) systems 
|
|
 Part B: Trace analysis 
|
 Writing observability tooling (like custom Datadog/Grafana dashboards) 
|
|
 Part C: Incident analysis 
|
 Writing a post-incident review (PIR) / post-mortem after a production outage 
|
|
 Part D: System design 
|
 Capacity planning for a new service (standard staff/principal engineer work) 
|
|
 Part F: Business case 
|
 Pitching a new platform capability to engineering leadership / CTO 
|
---
## 13. Concepts You Should Be Ready to Discuss
### "What happens when a provider goes down?"
Walk through the full flow: request arrives → gateway tries primary → gets 503 → normalizeFailure maps to provider_unavailable → decideFallback checks three gates → routes to fallback → normalizeSuccess on fallback response → product app gets normal response, never knows fallback happened.
### "How do you prevent cascading failures?"
Three layers of defense:
1. **Circuit breaker:** After N consecutive failures, stop sending to the failing provider entirely (let it recover).
2. **Fallback budget:** Cap fallback at 20% of total traffic so the backup doesn't also collapse.
3. **Tenant quotas:** Prevent one tenant's retry storm from consuming all capacity.
### "How do you decide between hosted and self-hosted?"
Compare monthly costs at target scale:
- Hosted: `volume × cost_per_call` (linear, no setup cost)
- Self-hosted: `setup_cost / amortization_months + monthly_compute` (high fixed, low marginal)
- Crossover point is where these lines intersect. Below it, hosted wins. Above it, self-hosted wins.
- But also consider: ops burden, data residency requirements, and time-to-market.
### "How do you measure if an ML feature is actually working?"
You need multiple signals:
- **Speed:** Did review times decrease? (Easy to measure in a pilot)
- **Quality:** Did escaped defects decrease? (Hard to measure — needs 3-6 months of post-merge data)
- **Adoption:** Are engineers actually using it? (Track opt-out rates)
- **Cost:** Is the ROI positive when you include false positive costs? (Track false positive rate and engineer time wasted)
