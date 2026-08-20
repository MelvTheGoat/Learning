---
title: "Real Material for Step 3 (Self-Assessment)"
subtitle: "Specific facts from the actual submission, so you can answer honestly instead of guessing"
author: "Prepared for Mayungbo Oluwatobi Melvyn"
date: ""
---

# Why you couldn't answer this before

Fair reason: `self_assessment.md` in the actual solution has real, unfilled `[REPLACE]` placeholders in it — "Weakest or least certain part" and "Incomplete work and why" are both explicitly left for you to fill honestly. You weren't missing something obvious. That content genuinely doesn't exist yet, and only you can write it truthfully — but you need the real facts in front of you first, which is what this document gives you.

I'm giving you material, not answers. Pick from what's below, phrase it in your own words.

---

# Q13 — Which part are you least confident defending live, and why

Real candidates, pulled from the actual code and reports:

**The provider-format detection in `normalizeSuccess`.** It decides whether a payload is OpenAI-shaped or internal-shaped by checking which key exists — `choices` vs `output` — rather than being told explicitly which provider sent it. This works for exactly two providers. Antigravity's own self-assessment already flags this as the thing it would most want a second opinion on: *"in production with more than two providers, this heuristic could break if a new provider's response happens to contain a `choices` key with different semantics."* If a reviewer asks "what happens with a third provider," this is where you'd need to think on your feet.

**`nearest_rank_percentile`'s edge-case coverage.** The formula is standard, but it was validated against the normal cases, not exhaustively against very small N or percentiles near 0/100. If pushed with "what does p99 return for a 2-row trace," you'd be reasoning live rather than citing a test.

**The `observed_rps` formula, specifically.** This one nobody flagged in the existing self-assessment, so it's worth knowing yourself: the analyzer computes `request_count / time_span` (20 requests over 2.15s ≈ 9.30 req/s). There's a real, equally defensible alternative — `(request_count − 1) / time_span`, treating N events as N−1 intervals — which gives a different number (≈8.84 req/s) on the identical data. Neither is "the" correct answer; the brief doesn't specify. If asked "walk me through this formula," you need to be able to state which convention you used and why, not just that a number came out.

---

# Q14 — What's genuinely unfinished, and your honest reason

Real, true candidates — pick whichever is actually true for you:

**You haven't independently re-run `dart test` yourself**, separate from the agent's own Docker-based run captured in `run_evidence.txt`. If that's true, say so plainly — it's a completely reasonable thing to still need to do, and it's exactly the kind of honest gap this section is designed to surface. The brief explicitly expects you to be able to run this yourself; if you haven't yet, that's the real answer, not a euphemism for it.

**Part E's actual content.** The experience reflection is still placeholder text. That's not a minor loose end — it's arguably the single most important unfinished piece, since the brief says a passing result *requires* it.

**The `fallback_used` CSV field is parsed leniently, not strictly.** Looking at the analyzer: any value that isn't exactly `"true"` (case-insensitive) is silently treated as `false` — a typo like `"ture"` wouldn't raise an error, it would just quietly not count as a fallback. Every *numeric* field in the same file is validated strictly with a row number on failure; this one boolean field isn't held to the same standard. That's a real, small inconsistency you could name as unfinished polish.

**Self-hosted unit economics in Part F are explicitly left unknown**, by the file's own admission — the ongoing variable cost of self-hosting is stated as "Unknown" rather than estimated. That's honest, not lazy, but it does mean the hosted-vs-self-hosted comparison in that report is incomplete by design, and you should be ready to say so rather than pretend it's resolved.

---

# Q15 — First thing you'd fix with one more day

The submission's own self-assessment already proposes one real answer: **property-based/fuzz testing on the Dart normalizer**, specifically for malformed payloads with unexpected types, missing keys, or deeply nested structures beyond what the four supplied fixtures cover. That's a genuine, specific, defensible answer already grounded in the actual gap — the current tests cover the given fixtures and the boundaries the brief names explicitly, but a real provider could return something stranger than any of the four fixtures anticipated.

A second real candidate, if you want an alternative: **explicit rejection of malformed `fallback_used` values** in the Python analyzer, to bring it in line with the strict-and-loud validation everywhere else in that file — a small, concrete, one-function fix.

---

# Q16 — One decision you'd want a second, more experienced opinion on

Three real, specific candidates — pick the one you understand well enough to explain *why* it's genuinely uncertain, not just that it exists:

**The provider-detection heuristic**, same one from Q13 — already the submission's own answer to this exact question, and a legitimately good one: it's a real architectural bet (structural detection vs. explicit provider tagging) with a real failure mode at scale.

**The dead-code redundancy in `decideFallback`.** Looking at the actual fallback-reason logic: it checks `!failure.failoverEligible` first, then has a second check against the specific error code — but given how `normalizeFailure` is written, `failoverEligible` is *always* set consistently with the code being exactly `timeout` or `provider_unavailable`. That means the second check can never actually fire; it's unreachable given the current code. It's not a bug — it doesn't cause wrong behavior — but if a reviewer asks "when does this second condition ever trigger," the honest answer is "it doesn't, right now — it's defensive redundancy in case the two ever drift apart." That's a real, good thing to flag for a second opinion: is defensive redundancy here worth the extra code, or is it clutter that should be removed?

**The `observed_rps` convention**, from Q13 again — worth a second opinion specifically because it's genuinely ambiguous per the spec, not because anything is wrong with it.

---

# How to actually use this

Don't copy any of the above verbatim into the file — none of it is written in your voice, and a live reviewer will notice generic phrasing immediately. Pick the one or two items per question that you can genuinely explain if pushed further, and write the sentence yourself. If none of these feel like something you could defend for two more follow-up questions, that itself is useful information — it tells you which part of the submission to actually go read and understand before the review, not just before writing this file.
