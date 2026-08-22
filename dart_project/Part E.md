
# How to use this

Don't write full sentences. Bullet points, fragments, half-thoughts — whatever's fastest. The goal right now is getting the real material out of your head, not making it read well. I'll help shape it into the actual document after.

One useful fact before you start: these are your own public, self-directed projects — not an employer's confidential system. The brief says you *may* anonymize; you don't have to. You can name the actual project, and for the RAG assistant you can even point the reviewer at the live URL. That's a genuine advantage most candidates don't have — use it.

---

# Step 1 — Pick the strongest candidate thread

Below are four real candidates from your work, each with the specific questions that would surface a genuine "wrong assumption → evidence → correction → measured outcome" story. Skim all four, answer whichever one feels most true and most vivid to you — you don't need to answer all four fully, just pick one and go deep, though a couple of quick answers on a backup thread is useful in case the first one turns out thin once you start writing.

## Candidate A — The fraud model's calibration split (focal loss vs. weighted sampling)

1. Before you tried focal loss and weighted sampling, what did you expect would happen? Did you expect them to behave similarly, or did you have a specific reason to think one would be better?
2. What was the actual moment you realized they'd failed in *different* ways — was it a specific plot, a specific number, a specific test run? Describe that moment concretely.
3. Once you saw the ECE number (0.0063) for focal loss and the PR-AUC drop (−0.042) for weighted sampling, what was your first reaction — confusion, a specific new hypothesis, something else?
4. How did you decide temperature scaling + isotonic regression was the right fix, rather than just picking whichever of the two original techniques was "less bad"?
5. What would have happened downstream — to the fraud system, to a real decision — if you'd shipped the uncalibrated version without catching this?
6. Genuinely: what would you do differently if you started this project again, knowing what you know now about how these two techniques fail?

## Candidate B — The RAG project's refusal-correctness number

1. When you first saw the 0.40 refusal-correctness score, what did you think it meant? What was your gut reaction before you investigated?
2. Walk through the actual steps you took to dig into *why* it was 0.40 rather than just accepting or reporting the number as-is.
3. What specifically made you realize the failure was in the stub judge's lexical-overlap heuristic and not in the real retrieval or guardrail logic? What evidence pointed you there?
4. Did you consider — even briefly — just not reporting this number, or softening it? Why did you decide to report it plainly instead?
5. What's the actual next step you'd take to get a trustworthy refusal number, and why haven't you done it yet (time, cost, priority — be honest)?

## Candidate C — The uplift study's null placebo result

1. What was the placebo test supposed to show if everything was working correctly, and what did it actually show?
2. What was your assumption going into the uplift modeling — did you expect to find a strong, usable signal?
3. When the placebo test came back indistinguishable from noise on the primary arm, what did that mean for the rest of the analysis? Did it call the whole project into question, or just part of it?
4. How did you decide what to do next — stop, report it honestly, dig further into the negative-uplift segment specifically?
5. Why does reporting a null result matter here — what would a dishonest version of this project have looked like, and why didn't you do that?

## Candidate D — The forecasting platform's leakage-testing discipline

1. Was there a specific moment you found (or almost missed) a leakage bug — a feature that used data from after the forecast origin? Walk through it if so.
2. Why did you build an automated leakage test into CI rather than just checking manually once? What made you think manual checking wasn't enough?
3. What's the worst-case outcome if a leakage bug like this shipped silently into the champion/challenger promotion gate?
4. Has the 2% out-of-sample cost margin gate ever actually rejected a model? What happened when it did (or would happen, if it hasn't yet)?

---

# Step 2 — Questions that apply regardless of which thread you pick

Answer these once you've picked your main thread, using that project as the anchor.

7. What was actually *your* decision here, specifically — not "the project used X" but "I decided to use X because ___"? Be precise about where your judgment, not just the tutorial/spec/default choice, entered.
8. What evidence did you look at with your own eyes before making that decision — a specific plot, log output, metric, table? Name the actual artifact, not just "I analyzed the results."
9. Was there a point where you seriously considered a different approach and rejected it? What was it, and why did you reject it?
10. How exactly did you measure that your fix/decision actually worked — what's the before number and the after number?
11. If a skeptical reviewer said "that's a small self-directed project, not a real production incident — why should I care about this story," what's your honest answer?
12. What would you do differently if you rebuilt this specific piece today?

---

# Step 3 — For self_assessment.md (lower stakes, more direct)

13. Of everything in this whole submission — Dart, Python, the reports — which part are you least confident defending live, and specifically why?
14. What's genuinely unfinished, and what's your honest reason (not a polished excuse — the real reason: time, priority, uncertainty about the right approach)?
15. If you had one more day, what's the *first* thing you'd fix or add, and why that one over everything else?
16. Pick one real decision from anywhere in this submission that you'd genuinely want a second, more experienced opinion on before it went anywhere near production. What is it, and what's your specific uncertainty about it?

---

Send back your rough answers to whichever numbered questions you tackle — doesn't need to be all of them, and doesn't need to be clean. I'll help shape whatever's there into the actual `experience_reflection.md` and `self_assessment.md`.
