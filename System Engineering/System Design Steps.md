# How to Run a System Design, Step by Step

A process to follow each time, with extra emphasis and specific self-checks at the points people most often slip on. Some steps get a short treatment because they tend to go well once you know to do them; others get more detail because they're where mistakes tend to hide.

---

## Step 1 — Find the load-bearing assumption(s)

Ask: "which unknowns, if answered differently, would actually reshape the architecture — not just a detail inside it?" State your assumption for each one explicitly and move on. Don't ask about things that only affect sizing (traffic volume, exact latency numbers) — those come later, in Step 5.

*This step tends to go well once you know the question to ask. Keep it quick.*

---

## Step 2 — Define the contract

Write out the request/response shape, identifiers, and what happens on partial failure. This is where precision matters more than it feels like it should — treat the contract as the actual source of truth, not the prose around it.

**Self-checks to run before moving on:**
- **Did every noun in your prose description make it into the schema?** If you wrote "there will be an actual result field, empty until the match/event happens," go check that your JSON example literally has that field in it. Prose is a draft; the schema is the commitment.
- **Is every label unambiguous without outside context?** A field like `"result": "win"` only makes sense if you already know whose perspective it's from. Prefer labels that are self-contained (`HOME_WIN` rather than `WIN`), so anyone reading a single record later — without the surrounding conversation — can still understand it.
- **For anything with more than two possible outcomes, are you returning information about all of them, not just the winner?** A single "confidence" or "probability" number for one outcome quietly throws away information a future version of your system (or you, later) might need.
- **Does every URL and parameter solve an actual, present need?** If you can't describe a concrete reason a parameter exists (what problem does it prevent), remove it rather than including it because it "seems like something an API should have."

---

## Step 3 — Trace one request end-to-end (the step to slow down on)

This is the step most likely to go wrong, and it goes wrong in one specific way: **starting from what a design "usually looks like" instead of starting from what *this* input actually is and what work is genuinely required on it.**

The fix is a specific habit: **before writing anything, go back and reread your own Step 1 answer.** Look specifically for any statement that something is fixed once decided, locked, finalized, or doesn't change afterward. That kind of constraint is a direct signal about whether this system needs to compute something live, on every request, or whether it can compute something once — ahead of time — and simply serve a stored answer afterward. This single check (does something become fixed/locked/final at some point?) resolves most of the "is this live or precomputed" confusion before you've written a single box in the trace.

Then, trace the actual input:
- What type of thing arrives — raw text? A structured record? An ID?
- What does it need to become, before it can be used?
- Is there a model actually involved, or could the answer already exist somewhere, waiting to be looked up?

Write the trace from these answers, not from memory of how a trace "usually" looks. If a step in your trace doesn't have a clear justification tied to *this* problem's actual input and output, cut it.

---

## Step 4 — What breaks, and how do we recover at the smallest unit?

Walk through: what happens when a component fails, when there's no data yet for something new, when a retry happens, when one item in a group of things fails but the rest succeed.

*You tend to generate good, concrete failure scenarios here — the main discipline is making sure every scenario actually gets an answer.*

**Self-check**: if you write "not sure" or start a sentence you don't finish, don't leave it hanging. Either give a real best-guess answer, or write "TBD — open question, needs research before build" explicitly. A visible gap is fine; a silent one isn't.

**One category worth specifically checking for**: does anything in your system update or retrain itself automatically? If so, ask "what stops a bad update from going live?" — not just "how would we notice after the fact that it went badly." Monitoring after the fact tells you something broke; it doesn't stop the break from happening. If nothing validates an update *before* it takes effect, that's a gap to name here.

---

## Step 5 — Connect the missing numbers to actual design knobs

For every number you're told not to assume (scale, volume, size, frequency), don't default to "no real change" — actively ask: **"what would look different about my design at 10x this number? At 100x?"** If the honest answer is genuinely "nothing changes," that's fine — but arrive at that conclusion by checking, not by skipping the question.

The most common place this bites: assuming a computation stays cheap/feasible at any scale, when in fact a design that's fine for a small volume becomes a fundamentally different (and harder) problem at a large one.

---

## Step 6 — Is it healthy but wrong?

Don't stop at naming the *category* of quality signal ("track service health" and "track model quality separately") — go one level further and name the actual, specific metric for *this* problem. If you can't yet name a specific number you'd look at, that's a sign this step isn't finished yet.

**A reliable trick for this step**: ask "what's the simplest, laziest way this system could technically 'work' without doing the interesting part of its job?" (e.g., always giving the most common answer, always returning the same popular item, never actually discriminating between different inputs). Then ask what metric would expose that. Comparing your system against this kind of naive baseline is one of the most effective ways to catch a system that looks healthy on the surface while quietly not doing anything useful.

---

## Step 7 — Flip the assumption (and park good ideas here, don't smuggle them into v1)

Take your Step 1 assumption and ask what changes if the opposite were true — this is usually where the natural follow-up questions live.

**Also use this step as a parking lot for good ideas that aren't required for a first working version.** If, partway through a design, you think of a genuinely good enhancement (an extra data source, an extra feature, an extra signal), the right move is usually not to fold it into the v1 design — it's to name it explicitly as a planned v2 addition. The reasoning: you can't tell whether an enhancement actually helped if you never had a working, simpler baseline to compare it against. Wanting to add it isn't the mistake — building it before you have something to measure it against is.

---

## The Short Version (pin this)

1. **Find what's load-bearing.** State it, move on.
2. **Write the contract like someone else has to read it with no context** — every described field actually present, every label self-contained, every parameter justified.
3. **Reread your own Step 1 answer before tracing.** Look for anything "locked" or "fixed" — that tells you live vs. precomputed. Trace the actual input, not a remembered shape.
4. **Name every failure mode an answer — even a rough one.** No trailing-off. Check: does anything self-update, and what validates it before it goes live?
5. **For every missing number, ask what breaks at 10x.** Don't default to "no change" without checking.
6. **Name a specific metric, and compare against the laziest possible baseline.** "Healthy" and "actually good" are different claims.
7. **Flip the big assumption — and park good-but-extra ideas here as "v2," not "v1."**
