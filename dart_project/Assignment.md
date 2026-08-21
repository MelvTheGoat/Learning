---
title: "Opening Answer — \"Talk to Me About Your Assignment\""
subtitle: "A script for the first 2–3 minutes, said out loud, not read"
author: "Prepared for Mayungbo Oluwatobi Melvyn"
date: ""
---

# How to use this

This is written to be spoken, not read off a screen. Say it out loud to
yourself a few times until the shape sticks — you don't need the exact
words, you need the order and the emphasis. Bracketed notes are stage
directions for you, not things to say.

One structural choice worth knowing before you read it: the honesty note
about tool use is placed **first, briefly, before any technical content**.
That's deliberate — get the hard sentence out of the way in one breath,
then spend the rest of your time on real strength. If you decide *not* to
volunteer it unprompted and would rather wait until it comes up naturally
(e.g., when they look at `tool_use_log.md` directly), cut that paragraph
and start straight from "This is a gateway..."

---

# The script

**[One honest sentence first, if you're volunteering it]**

"Before I walk through it — one correction I want to make up front. My
tool use log undersells how much I leaned on AI for the initial code and
two of the reports. I want to be straight about that now rather than have
it come up later."

*[Pause. Don't over-explain here — one sentence, then move on. You'll get
a chance to go deeper if they ask.]*

**[The actual walkthrough]**

"This is a gateway boundary for an AI provider — the piece that sits
between product code and whichever model provider is actually answering,
so the rest of the system never has to know or care which one it is. The
brief broke it into six parts, and they're testing pretty different
things.

The Dart piece normalizes two different provider response shapes into one
stable contract, maps failures into eight canonical error codes, and
decides when it's actually safe to fail over to a backup provider — which
turned out to be the most interesting part of the whole assignment,
because failover sounds obviously good and is actually dangerous if you
get it wrong. If you fail over on the wrong kind of error, you can retry a
request that was never going to succeed, or bounce it between providers
indefinitely. So the logic only permits exactly one fallback, only for two
specific error codes, only when the backup is a genuinely different
provider. I ran the test suite — 43 tests, all passing — and there's real
output for that in the evidence file.

The Python side analyzes production-style telemetry — a trace with 20
requests, a mix of successes and failures — and computes latency
percentiles, per-tenant error rates, that kind of thing, all from the
standard library, no pandas. That fed directly into the incident analysis:
there's a real, traceable pattern in that data — queue depth climbs,
errors start clustering right where it peaks, fallback kicks in but adds
enough latency to make the queue worse before it gets better. I tried to
keep facts and hypotheses separate there rather than write a generic
incident narrative.

Then there's a system design piece — capacity planning for 10,000 requests
a minute with tenant fairness built in — and a business case for a
hypothetical AI feature, where the actual test is whether you can design a
pilot that could honestly come back and say 'this doesn't work,' not just
one that looks good on paper."

**[One honest limitation, named before they ask]**

"One thing I'd flag myself: the way `normalizeSuccess` figures out which
provider sent a response is structural — it just checks which keys exist
in the payload. That works for the two providers here, but it's a real
weak point if a third provider's response happened to share a key with a
different meaning. I'd want that to be explicit rather than guessed, given
more time."

**[Close, and hand it back]**

"Happy to start wherever's most useful to you — the code, the trace, or
the business case."

---

# Timing

Read at a normal conversational pace, this runs close to two and a half
to three minutes. That's the right length for an opening — long enough to
show real command of the material, short enough that you're not filling
the entire session before they've asked a single question.

# The one thing to get right

Don't recite this from memory word-for-word — if a reviewer interrupts
mid-sentence (likely, and part of what they're testing), you need to be
able to drop the script and answer the actual question, then find your way
back. Know the *shape* — correction, what it does, the fallback-safety
story, one honest limitation, hand it back — and let the exact words come
out differently each time you practice it.
