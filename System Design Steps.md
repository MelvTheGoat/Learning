# How to Solve "Design X" Questions — A General Method

The panic with "Design a ___" is that it feels infinite — no clear start, no clear end, and every direction seems equally arbitrary. The fix is to stop treating it as an open-ended essay and treat it as a **fixed sequence of smaller, bounded decisions**. Every good design answer, no matter the system, walks the same path. Below is that path, with the Embedding & Classification API as the running example.

---

## Step 0: Resist the urge to start drawing boxes

The biggest mistake is jumping straight to "okay, load balancer, then service, then database" before you know what the service even needs to guarantee. Boxes-and-arrows is the *output* of design thinking, not the starting point. Start with words, not diagrams.

---

## Step 1: Ask what you don't know before assuming it

Every design prompt hides ambiguity on purpose (in interviews) or by nature (in real work). Your first move is always: **find the one or two ambiguities that would change the shape of the whole system, and either ask or explicitly state your assumption.**

How to spot which ambiguities matter: ask "if this were answered the other way, would my architecture actually look different?" If yes, it's load-bearing — resolve it first. If no, don't bother asking, just proceed.

**In our example**: "Can callers supply their own embeddings?" This is load-bearing — it determines whether the service controls preprocessing/caching/versioning end-to-end, or has to trust and validate external vectors. Everything else (batching, caching keys, compatibility checks) depends on the answer. So it's the very first thing addressed, explicitly, before any architecture.

Things that are *not* usually load-bearing enough to block progress: exact QPS, exact text length. You don't need these numbers — you need to know *which knobs in your design they'd turn* (see Step 5).

---

## Step 2: Define the contract before the internals

Before you design how something works, define what it promises. This means: **API shape, inputs, outputs, error semantics, identifiers.** This step is boring and people skip it to get to the "interesting" architecture — but skipping it is why designs fall apart under follow-up questions. If you don't know what a batch response looks like when half the items fail, you can't design retry logic later.

Ask yourself, in order:
1. What does a single request look like, and what does a single response look like?
2. What happens when it's partially wrong (some fields bad, some items in a batch bad)?
3. What identifiers does a caller need to track a thing across time (idempotency, job status, retries)?
4. What has to be **explicit and versioned** rather than inferred, because getting it wrong silently produces wrong answers instead of a visible error?

**In our example**: This is Part 1 — request/batch/item IDs, sync vs. async threshold, per-item errors, and explicit embedding/classifier versions. Notice the versioning point in particular: it wasn't guessed, it fell directly out of asking "what happens if this is wrong?" — a wrong version pairing doesn't crash, it silently mis-classifies. That's the kind of failure mode contract design exists to catch.

---

## Step 3: Trace one request all the way through

Now, and only now, draw the path. Pick the simplest, most common request and walk it step by step from arrival to response. At each step ask: *what does this stage need to do, and why can't the previous or next stage do it instead?*

This naturally produces your components — you're not inventing a load balancer because "systems have load balancers," you're discovering you need one because you found a reason (e.g., stateless request handling must scale independently of expensive model-serving workers).

Two things to actively look for while tracing:
- **Where is state introduced?** (caches, queues, model weights loaded in memory) — state is where most complexity and most bugs live.
- **Where is expensive work happening, and can it be shared across requests?** — this is usually where batching or caching enters the design.

**In our example**: This is Part 2. Tracing the request from gateway → validation → cache lookup → batching → GPU inference → classification → response is what *reveals* the need for a model registry, a compatibility table, and cache keys that include every version that affects the output — not something bolted on afterward.

---

## Step 4: Ask "what breaks, and what do we do about it?"

Every system eventually fails partially. A good design doesn't wait to be asked about failure — you should proactively walk through:
- Component crashes mid-work — what state is lost, what's recoverable?
- Load exceeds capacity — who gets rejected, who gets slowed down, who gets starved?
- One tenant's traffic pattern threatens to hurt everyone else — how are they isolated?
- A retry happens — does it duplicate completed work, or resume?

The general heuristic: **anything that can be retried, must be retried at the smallest unit that makes sense, not the largest.** Retrying a whole batch because one item failed is almost always wrong; the question is always "what's the smallest checkpoint I can resume from?"

**In our example**: This is Part 3 — item-level checkpointing so a 50,000-item batch retry doesn't redo 49,000 successful items; separate capacity pools so batch traffic can't starve interactive traffic; bounded queues with fast, honest rejection instead of silent overload.

---

## Step 5: Connect the ignored numbers to specific design knobs

You were told not to assume specific numbers (QPS, latency targets, batch size). That doesn't mean numbers don't matter — it means **your job is to say which decisions change as a function of them**, rather than picking a number out of the air and designing around it.

For every "we don't know X" in the prompt, ask: "what part of my design is a dial that X would turn?"

**In our example**:
- Text length → affects token-count-based batch sizing, not just item-count batch sizing.
- Label count → affects whether classification is cheap enough to always run vs. needing its own scaling tier.
- Latency target → sets the synchronous/async threshold and the dynamic-batching wait window.
- Freshness target → determines whether caching is even viable and for how long.

This shows a grader/reviewer that you understand *why* the numbers matter, which is more valuable than guessing correct-sounding numbers.

---

## Step 6: Design for "is it still correct?", not just "is it still running?"

This is the step almost everyone forgets, and it's usually what separates a mediocre answer from a strong one, especially for ML/data systems. A system can return 200 OK, low latency, no errors — and be silently wrong (serving stale cache entries, misclassifying because an incompatible model pairing slipped through, drifting label distributions because upstream data shifted).

Ask explicitly: **how would we know if this system were healthy but wrong?** This forces you to design evaluation, monitoring of output distributions (not just latency/error rate), and staged rollout (shadow/canary) — separate from ordinary infra observability.

**In our example**: This is Part 4 — the whole point of "separate service health from model quality" as a design principle. Latency dashboards will never catch a classifier silently degrading because it was paired with a slightly different embedding model version.

---

## Step 7: Anticipate the two or three follow-up questions

By the time you've done Steps 1-6, follow-ups are rarely new territory — they're usually "now change one assumption and re-derive." Practice this by picking your own load-bearing assumption from Step 1 and asking "what if the opposite were true?" This is exactly what "how would the contract change if callers supply their own embeddings" is testing — it's not a new problem, it's Step 1's fork revisited.

---

## The Compressed Checklist

When you see "Design a ___," run through this in order:

1. **What's the one ambiguity that would reshape the whole system?** State your assumption and move on.
2. **What's the contract?** Request/response shape, identifiers, partial-failure behavior, what must be explicit vs. inferred.
3. **Trace one request end-to-end.** Let components emerge from that trace, don't invent them from memory.
4. **What breaks, and how do we recover at the smallest unit possible?** Crashes, overload, retries, tenant isolation.
5. **Which unstated numbers act as dials, and what do they turn?** Don't guess numbers — name the knobs.
6. **How do we know if it's healthy but wrong?** Evaluation, drift, staged rollout — separate from uptime/latency monitoring.
7. **What's the natural follow-up if I flip my Step 1 assumption?** Pre-empt it.

Every "Design X" prompt — an API, a queue, a recommendation system, a rate limiter — fits this shape. The nouns change; this sequence doesn't.
