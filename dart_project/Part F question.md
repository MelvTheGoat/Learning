# Part F — AI Lab Business Case

## What it actually is

Not a personal narrative — a structured business analysis with real math. This one I can help build directly with you, since it's reasoning about a hypothetical scenario, not your personal history.

## The scenario, restated simply

A company wants to build an AI tool that scans a pull request and warns reviewers about risk before they read it. They have a six-week window and a $25,000 budget to decide: build it for real, change the idea, or kill it. Your job is to design the cheapest experiment that would tell them the truth.

## The core skill being tested

**Can you tell the difference between what's known, what's assumed, and what's genuinely unknown — and can you design a test that could actually fail?** Most weak answers here either treat every assumption as fact, or propose a "pilot" so soft that it can only ever look successful regardless of what actually happens.

## Walking through each required piece

**1. Target user, job-to-be-done, decision enabled.** Be specific about *who* benefits and *what decision* the business makes based on the pilot's result. Not "developers" — the actual reviewer facing an 18-hour review queue, and the decision is "do we roll this out to more teams, change the approach, or stop."

**2. Facts vs. assumptions vs. unknowns.** Go through the scenario line by line:
- **Facts:** 1,200 PRs/month, 18-hour median time-to-first-review, $0.18/run hosted cost, 2.5 runs/PR average, $30,000 self-hosted setup estimate, six weeks, $25,000 budget.
- **Assumptions to test:** that faster review actually reduces escaped defects (the brief says explicitly this connection is *not yet established* — that's the riskiest unproven assumption in the whole scenario), that reviewers will trust and act on the AI's summary rather than ignoring it, that 2.5 runs/PR holds at scale rather than drifting up.
- **Unknowns:** the real relationship between review delay and defects, whether reviewer behavior changes with the tool present, false-positive/false-negative rates on real code.

**3. Outcome metrics.** One clear **primary business outcome** — probably review-delay reduction, since that's the only thing directly measurable in six weeks (defect reduction takes much longer to observe honestly). Then **quality measures** (precision/recall of the risk flags against real outcomes, or reviewer agreement rate) and **guardrails** (reviewer trust/disengagement, false-positive rate, no leaking proprietary code externally).

**4. A falsifiable pilot.** The key design move: run it on some PRs and *not* others (or before/after on the same teams) so you have something to compare against — a **baseline or control**. If every PR in the pilot gets the tool, you have no way to know if review time would've dropped anyway. Propose a concrete comparison: e.g., roll out to one team, hold a comparable team back as a control, compare review-delay change between them over the six weeks.

**5. Unit economics — the actual math:**

At 1,200 PRs/month: 1,200 × 2.5 runs × $0.18 = **$540/month** hosted variable cost.

At 30,000 PRs/month: 30,000 × 2.5 × $0.18 = **$13,500/month**.

Then the part that actually separates a strong answer: **say what's missing from that number.** It doesn't include the cost of a false positive wasting a reviewer's time chasing a flagged risk that wasn't real, the engineering cost of maintaining the integration, retries on failed runs, or the fact that 2.5 runs/PR is itself an early-prototype estimate that could easily be optimistic.

**6. Hosted vs. self-hosted vs. non-ML baseline.** Self-hosted's $30,000 setup cost only pays for itself if volume is high enough that the hosted variable cost saved exceeds it — work out roughly what volume that breakeven point sits at, and be honest that you don't have enough information to know the self-hosted *unit* cost precisely, only that it removes the per-run hosted fee at the price of new operational ownership. The **non-ML baseline** matters because the brief explicitly wants you to consider it: a simple heuristic (flag PRs above a certain size, or touching certain sensitive files) might capture much of the value at close to zero cost — the pilot should be honest about whether the AI actually beats that.

**7. First three activities, and what you defer.** With six weeks, the highest-value first move is almost always instrumenting the *baseline* — you can't measure improvement without knowing the current state precisely. Something like: (1) instrument current review-delay measurement precisely per team, (2) build the smallest viable version of the tool for one team, (3) run it against the control design from step 4. Defer anything like multi-team rollout, self-hosted infrastructure, or defect-correlation analysis — that needs far more than six weeks to observe honestly.

**8. Go / pivot / stop thresholds.** These need to be numbers or clearly observable facts, decided *before* the pilot runs — not vague. Something like: **go** if review delay drops by a stated meaningful margin with no material increase in reviewer disengagement; **pivot** if the tool works technically but reviewers ignore it (a workflow/adoption problem, not a model problem); **stop** if false-positive rate is high enough that reviewers report the tool as net-negative, or if delay doesn't improve at all against the control.

**9. A recommendation a finance/product leader could challenge.** State a real position — "go," "pivot," or "stop," or "run the six-week pilot as designed before deciding" — and then explicitly name the strongest objection to your own recommendation. This mirrors the pattern you already use well in your ML projects: reporting the honest limitation rather than only the flattering conclusion.
