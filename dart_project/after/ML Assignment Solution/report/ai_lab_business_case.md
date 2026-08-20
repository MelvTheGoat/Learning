# AI Lab Business Case — PR Risk Briefing Pilot

## Target user, job-to-be-done, and decision enabled

The actual user here isn't just "developers" in general — it's the specific reviewer staring down that 18-hour review queue. Their job-to-be-done is figuring out where to spend their limited attention before they even open the diff. The decision this pilot lets leadership make is straightforward: do I roll this tool out to more teams, pivot the approach entirely, or just stop and kill it?

## Known facts, assumptions, and important unknowns


### Known facts

- 1,200 PRs/month across three pilot teams.
- 18-hour median time-to-first-review.
- $0.18 per run hosted cost; 2.5 runs/PR average.
- $30,000 self-hosted setup estimate (variable cost unspecified).
- 6-week timeline and $25,000 pilot budget.
- No trustworthy baseline connecting review delay to escaped defects.

### Assumptions to test

The single riskiest unproven assumption is that a faster review actually reduces escaped defects — the brief explicitly says this isn't established yet. I'm also assuming reviewers will actually trust the AI's summary instead of ignoring it, and that the 2.5 runs/PR average won't drift upward once it meets real usage at scale.

### Important unknowns

- The real relationship between review delay and defects.
- How reviewer behaviour genuinely changes once the tool is sitting in their workflow — do they rely on it too much, or ignore it entirely?
- The true false-positive and false-negative rates once this hits our real, messy codebases rather than whatever it was tested on.
- What the self-hosted model's actual variable cost per run is. Without that number, the hosted vs self-hosted comparison is incomplete.

## Outcome metrics and guardrails

I've learned you can't just rely on one number here — three different kinds of metric are needed to get the real picture.

### Primary business outcome

Review-delay reduction. I chose this because it's the only thing realistically measurable within the 6-week window — defect reduction takes way too long to observe honestly, so building the pilot around it would just be setting myself up to guess.

Target: ≥ 20% reduction in median time-to-first-review (from 18 hours to ≤ 14.4 hours) for the treatment group.

### Model and product quality measures

- **Briefing relevance rate:** Percentage of briefings rated "useful" or "partially useful" by the reviewer (via a lightweight 1-click feedback widget). Target: ≥ 60%.
- **False positive rate:** Percentage of flagged risks the reviewer judges as not actually risky. Target: < 40%. Above this, reviewer fatigue becomes a real concern.
- **Coverage:** Percentage of PRs where the model produces a briefing at all (vs failures, timeouts, content filter blocks). Target: ≥ 95%.

### Safety, adoption, and workflow guardrails

Reviewer trust and disengagement, false-positive rate, and making sure zero proprietary code leaks out through the process. This is what catches the failures a pure business metric would completely miss — the tool can look like it's working on paper while quietly doing damage underneath.

- **Reviewer disengagement:** If reviewer comment depth drops > 25% in the treatment group, trigger a pivot review — the tool may be substituting for human judgment rather than augmenting it.
- **False confidence:** Track escaped defects in treatment vs control. If escaped defects increase by any statistically significant amount, stop the pilot.
- **Adoption floor:** If < 30% of eligible reviewers interact with briefings after 3 weeks, the tool is not solving a real workflow problem. Pivot or stop.

## Falsifiable pilot design

If I actually want real numbers on whether this works, I can't just hand the tool to everyone. I'd use an A/B design: randomly assign PRs (not teams — that introduces too many confounders) to treatment (briefing shown) and control (no briefing) within each team, 50/50 split.

- **Duration:** 4 weeks of data collection within the 6-week window (1 week setup, 4 weeks running, 1 week analysis).
- **Sample size:** ~1,200 PRs/month × 4/6 weeks ≈ 800 PRs total. With the 50/50 split: ~400 treatment, ~400 control — enough to detect a ~20% change in median review time with reasonable confidence.
- **Baseline:** Current 18-hour median, measured from PR metadata over the 2 weeks preceding the pilot. Without that baseline, the pilot can't measure impact.

The pilot disproves the proposal if the treatment group shows no significant reduction in review time, the relevance rate falls below 40%, or escaped defects increase.

## Unit economics

Doing the actual math:

**At pilot scale (1,200 PRs/month):**
- 1,200 × 2.5 runs × $0.18 = **$540/month**
- Over the 6-week pilot: $540 × 1.5 = **$810 inference cost**
- Well within the $25,000 budget — leaving ~$24,000 for engineering effort, tooling, and analysis.

**At scale (30,000 PRs/month):**
- 30,000 × 2.5 × $0.18 = **$13,500/month** = **$162,000/year**

What's missing from that number? A lot:

- **Retry and failure cost:** If actual runs/PR exceed 2.5, costs increase proportionally. At 3.0 runs/PR, that's a 20% bump.
- **False positive cost:** This is the one people miss. If 40% of briefings contain spurious warnings, reviewers waste time chasing risks that aren't real. At ~$1/minute engineering cost and ~4 minutes per false positive investigation, that's ~$4/PR for 40% of PRs = $1.60/PR average. At 30,000 PRs/month: **$48,000/month** — potentially 3.5× the inference cost.
- **Infrastructure cost:** API gateway, logging, storage for briefings, monitoring — none of this is in the $0.18/run figure.
- **Token volume variance:** The $0.18 assumes a fixed token budget. Large PRs (1000+ lines of diff) will consume significantly more.

## Hosted vs self-hosted vs non-ML baseline

I'd decide against self-hosting right away. That $30,000 setup cost only pays for itself once volume gets massive enough to actually offset the hosted fees, and I'm nowhere near proving that volume is coming.

| Dimension | Hosted model | Self-hosted model | Non-ML baseline (rule-based) |
| --- | --- | --- | --- |
| **Pilot cost** | $810 (known) | $30,000 setup alone exceeds budget | Near-zero (engineering time only) |
| **Scale cost (30K PRs/mo)** | $13,500/month | Lower variable, but unknown | Near-zero ongoing |
| **Time to pilot** | ~1 week (API integration) | 3–4 weeks (infra + deployment) | 1–2 weeks |
| **Quality** | LLM understands code semantics | Comparable if same model class | Limited to syntactic patterns |
| **Source-code privacy** | Code sent to third party | Code stays internal | Code stays internal |

More importantly, the pilot has to beat the non-ML baseline, not just beat nothing. A simple script that flags PRs above a certain size or ones touching sensitive files — a team could put that together in a day for almost zero cost. The pilot needs to honestly prove the AI is better than that script, not just better than doing nothing at all.

## First three activities and deliberate deferrals

Given I only have six weeks, my first three moves are:

1. **Instrument baseline metrics (week 1):** Set up automated measurement of time-to-first-review from PR metadata for all three teams. Collect 2 weeks of pre-pilot baseline data. Can't measure improvement without a solid baseline to measure it against.
2. **Build the minimum integration (weeks 2–3):** Integrate the hosted model into the PR workflow (triggered on PR open, briefing posted as a comment). Implement the 1-click relevance feedback widget. Begin the A/B randomisation.
3. **Run the controlled comparison (weeks 3–6):** Collect 4 weeks of treatment vs control data. Run the end-of-pilot analysis.

**Deliberately deferred:**
- Self-hosted model evaluation — premature before validating the value proposition. Revisit only on a "go" decision.
- Escaped-defect correlation analysis — requires months of post-merge data. Set up the data pipeline now, but don't expect results during the pilot.
- Prompt optimisation and model fine-tuning — use the model as-is for the pilot. Optimisation is Phase 2.
- Multi-language and multi-repository support — scope to the three pilot teams' primary repositories only.

## Go, pivot, and stop thresholds

### Go

All of the following are met after 4 weeks:
- Median time-to-first-review in the treatment group is ≥ 20% lower than the control group.
- Briefing relevance rate ≥ 60%.
- No statistically significant increase in escaped defects in the treatment group.
- Reviewer adoption rate ≥ 50%.

**Go decision:** Proceed to productionisation. Evaluate self-hosted economics at scale. Expand to additional teams.

### Pivot

- Time-to-first-review reduction is 10–19% — the tool has some value but may need better prompts, different model, or different UX.
- Briefing relevance rate is 40–59% — useful for some PR types but not others. Pivot to targeting only high-risk PRs.
- Adoption is 30–49% — investigate why; consider making briefings opt-in rather than default.

### Stop

- Time-to-first-review shows no improvement (< 10% reduction) or gets worse.
- Escaped defects increase in the treatment group.
- Reviewer adoption < 30% after 3 weeks despite outreach.
- Briefing relevance rate < 40%.

**Stop decision:** Discontinue the capability. Document learnings. Redirect resources.

## Recommendation and strongest objection

**Recommendation:** Run the six-week controlled pilot as designed before committing to any company-wide rollout or dropping $30K on self-hosting. The pilot is cheap ($810 inference cost), fast (4 weeks of data), and designed to produce a clear go/pivot/stop signal.

**Strongest objection:** A finance or product lead would likely push back and say six weeks with just one treatment group is too small a sample to trust. My honest answer to that: that's exactly why I'm running a controlled, falsifiable test first — it's the cheapest way to find out if I'm wrong before committing heavy resources. The pilot measures *time-to-first-review*, but the stakeholder cares about *escaped defects* — and the spec explicitly states there's no trustworthy baseline connecting the two. Even if the pilot shows a 30% reduction in review delay, I cannot prove this reduces defects within 6 weeks. I've designed the pilot to detect if it makes reviews *worse* (via escaped defect tracking), but proving it makes them better requires 3–6 months of post-merge defect data. The pilot's go decision is conditional — it validates *speed and adoption*, not *quality impact*.
