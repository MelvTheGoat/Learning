# AI Lab Business Case - PR Risk Briefing Pilot

## Target user, job-to-be-done, and decision enabled

- **Target user:** Software engineers on the three pilot product teams who author and review pull requests. The primary beneficiary is the *reviewer*, whose job is to assess risk and correctness before merge.
- **Job-to-be-done:** Before a human reviewer opens a PR, they need a fast, structured summary of what areas of risk the change introduces (e.g., breaking API contracts, security-sensitive code paths, performance-critical sections, missing test coverage) so they can focus review effort where it matters most.
- **Decision enabled:** The pilot produces a go, pivot, or stop recommendation on whether AI-assisted PR risk briefing reduces time-to-first-meaningful-review without degrading review quality. This decision lets leadership choose whether to invest further in productionizing the capability or redirect resources.

## Known facts, assumptions, and important unknowns

### Known facts

- Three product teams are in scope, generating ~1,200 pull requests per month combined.
- Current median time from PR opening to first meaningful review is 18 hours.
- Hosted model inference costs ~$0.18 per run; prototypes average 2.5 runs per PR.
- A self-hosted option has an estimated $30,000 setup cost with lower variable inference cost (amount unspecified).
- The pilot has a 6-week window and a $25,000 budget.
- No trustworthy baseline exists connecting review delay to escaped defects.

### Assumptions to test

- **A1:** AI-generated risk briefings will reduce time-to-first-meaningful-review by helping reviewers prioritize and start faster.
- **A2:** Reviewers will actually read and use the briefings (adoption is not guaranteed).
- **A3:** The briefings will be accurate enough that reviewers trust them — false confidence is a material risk.
- **A4:** 2.5 runs per PR is representative of production usage; it may be higher if engineers iterate or re-trigger.
- **A5:** Reducing review delay correlates with reducing escaped defects. This is the riskiest assumption — the spec explicitly states no trustworthy baseline exists.

### Important unknowns

- What fraction of PRs actually benefit from a risk briefing? Trivial PRs (typo fixes, config changes) may not.
- What is the false positive rate of risk warnings, and at what rate do false positives cause reviewer fatigue or disengagement?
- What is the false negative rate — does the model miss real risks, creating false confidence?
- Does faster first review actually lead to fewer production defects, or is delay caused by factors the briefing cannot address (reviewer availability, timezone gaps, organizational bottlenecks)?
- What is the self-hosted model's actual variable cost per run? Without this, the hosted vs self-hosted comparison is incomplete.
- What is the source-code privacy risk profile for the hosted model provider? Are there contractual or regulatory constraints?

## Outcome metrics and guardrails

### Primary business outcome

**Reduction in median time-to-first-meaningful-review** from the current 18-hour baseline. This is directly measurable from PR metadata, does not require subjective judgment, and connects to the stated stakeholder belief.

Target: ≥ 20% reduction (to ≤ 14.4 hours) for PRs that receive a risk briefing.

### Model and product quality measures

- **Briefing relevance rate:** Percentage of briefings rated "useful" or "partially useful" by the reviewer (via a lightweight 1-click feedback widget on the briefing). Target: ≥ 60%.
- **False positive rate:** Percentage of flagged risks that the reviewer judges as not actually risky. Target: < 40%. Above this, reviewer fatigue becomes a concern.
- **Coverage:** Percentage of PRs where the model produces a briefing (vs failures, timeouts, or content filter blocks). Target: ≥ 95%.

### Safety, adoption, and workflow guardrails

- **Reviewer disengagement guardrail:** Monitor whether reviewers' own comments decrease in depth or frequency after briefing adoption. If reviewer comment depth drops > 25% in the treatment group, trigger a pivot review — the tool may be substituting for human judgment rather than augmenting it.
- **False confidence guardrail:** Track escaped defects (bugs found post-merge) in the treatment group vs control. If escaped defects increase by any statistically significant amount, stop the pilot.
- **Source-code privacy:** All PR content sent to the hosted model must comply with the data processing agreement. Confirm this before the pilot begins.
- **Adoption floor:** If < 30% of eligible reviewers interact with briefings after 3 weeks, the tool is not solving a real workflow problem. Pivot or stop.

## Falsifiable pilot design

### Structure

- **A/B design with staggered rollout.** Randomly assign PRs (not teams, to control for team-level confounders) to treatment (briefing shown) and control (no briefing) within each team. 50/50 split.
- **Duration:** 4 weeks of data collection within the 6-week window (1 week setup, 4 weeks running, 1 week analysis).
- **Sample size:** ~1,200 PRs/month × 4/6 weeks ≈ 800 PRs total. With 50/50 split: ~400 treatment, ~400 control. This is sufficient to detect a ~20% change in median review time with reasonable confidence.

### Baseline and control

- The control group operates as-is: PR opens, reviewers are notified, no AI briefing is provided.
- Baseline metric: current 18-hour median time-to-first-meaningful-review, measured from PR metadata over the 2 weeks preceding the pilot.

### Evidence collection

- **Quantitative:** Time-to-first-meaningful-review (automated from PR events), briefing relevance ratings (1-click feedback), escaped defects (post-merge bug reports tagged to PR), runs-per-PR, model latency, cost-per-PR.
- **Qualitative:** Short end-of-pilot survey to 10–15 reviewers asking what they found useful, misleading, or annoying.

### Confounders

- PR complexity varies; stratify analysis by PR size (lines changed) and file count.
- Team culture differences; randomize at the PR level within each team, not across teams.
- Novelty effect: reviewers may engage more in week 1 and less in week 4. Track adoption by week.

### Falsifiability

The pilot disproves the proposal if:
- Treatment group shows no statistically significant reduction in time-to-first-meaningful-review vs control, OR
- Briefing relevance rate is below 40%, OR
- Escaped defects increase in the treatment group.

## Unit economics

### Hosted-model variable cost

**At 1,200 PRs/month (pilot scale):**
- 1,200 PRs × 2.5 runs/PR = 3,000 runs/month
- 3,000 runs × $0.18/run = **$540/month**
- Over a 6-week pilot: $540 × 1.5 = **$810 inference cost**
- Well within the $25,000 budget, leaving ~$24,000 for engineering effort, tooling, and analysis.

**At 30,000 PRs/month (scale):**
- 30,000 PRs × 2.5 runs/PR = 75,000 runs/month
- 75,000 runs × $0.18/run = **$13,500/month** = **$162,000/year**

### What is missing from this estimate

- **Retry and failure cost:** If a run fails (timeout, content filter, provider error) and is retried, actual runs/PR may exceed 2.5. At 3.0 runs/PR, costs increase by 20%.
- **False positive cost:** If 40% of briefings contain spurious warnings, reviewers spend time investigating non-issues. If each false positive wastes 10 minutes of reviewer time at an engineering cost of ~$1/minute, that's a hidden $4/PR for 40% of PRs = $1.60/PR average, which at 30,000 PRs/month = $48,000/month — potentially 3.5× the inference cost.
- **Infrastructure cost:** API gateway, logging, storage for briefings, monitoring — not included in the $0.18/run estimate.
- **Engineering maintenance cost:** Prompt engineering, model version upgrades, handling edge cases — ongoing operational cost.
- **Token volume variance:** $0.18/run assumes a fixed token budget. Large PRs (1000+ lines of diff) may consume significantly more tokens per run.
- **Self-hosted variable cost:** Unknown. The $30,000 setup estimate exists, but ongoing compute, maintenance, and on-call costs are not stated.

## Hosted vs self-hosted vs non-ML baseline

| Dimension | Hosted model | Self-hosted model | Non-ML baseline (rule-based) |
| --- | --- | --- | --- |
| **Pilot variable cost** | $810 (known) | Unknown variable + $30,000 setup (exceeds $25K budget alone) | Near-zero (engineering time only) |
| **Scale cost (30K PRs/mo)** | $13,500/month (known) | Lower variable, but unknown amount; amortized setup adds ~$2,500/mo over 12 months | Near-zero ongoing |
| **Time to pilot** | 1 week (API integration) | 3–4 weeks (infra + deployment + tuning) | 1–2 weeks (rules definition) |
| **Risk assessment quality** | Likely best (LLM understands code semantics) | Comparable if same model class | Limited to syntactic patterns (file paths, diff size, known-risky patterns) |
| **Source-code privacy** | Code sent to third party; requires DPA | Code stays internal | Code stays internal |
| **Operational burden** | Low (provider manages infra) | High (GPU provisioning, model updates, on-call) | Low |

**Recommendation for pilot:** Use the **hosted model**. The self-hosted option's $30,000 setup exceeds the pilot budget alone, and the pilot's purpose is to validate the *value proposition* before optimizing cost. If the pilot succeeds and scale economics justify it, the self-hosted option becomes a Phase 2 optimization.

**Non-ML baseline as a comparison arm:** Consider running a simple rule-based risk tagger (flags: files matching `**/security/**`, `**/auth/**`, changes > 500 LOC, changes to CI/CD configs) alongside the ML briefing. This provides a credible "is ML actually better than simple rules?" comparison, which strengthens the business case if ML wins and saves money if it doesn't.

## First three activities and deliberate deferrals

1. **Validate the riskiest assumption (week 1):** Before building anything, manually generate risk briefings for 20 recent PRs using the hosted model API and share them with 5 reviewers. Collect qualitative feedback: are these useful? Would you read this before reviewing? This is the cheapest possible test of whether reviewers value the output.
2. **Instrument baseline metrics (week 1, parallel):** Set up automated measurement of time-to-first-meaningful-review from PR platform events for all three teams. Collect 2 weeks of pre-pilot baseline data. Without this baseline, the pilot cannot measure impact.
3. **Build the minimum integration (weeks 2–3):** Integrate the hosted model into the PR workflow (triggered on PR open, briefing posted as a comment). Implement the 1-click relevance feedback widget. Begin the A/B randomization.

**Deferred:**

- Self-hosted model evaluation — premature before validating the value proposition. Revisit only if the pilot produces a "go" decision and scale economics require it.
- Escaped-defect correlation analysis — requires months of post-merge defect data. Set up the data pipeline now, but do not expect results during the 6-week pilot.
- Prompt optimization and model fine-tuning — the pilot uses the model as-is. Optimization is a Phase 2 activity contingent on a "go" decision.
- Multi-language and multi-repository support — scope the pilot to the three teams' primary repositories only.

## Go, pivot, and stop thresholds

### Go

All of the following are met after 4 weeks:
- Median time-to-first-meaningful-review in the treatment group is ≥ 20% lower than the control group (≤ 14.4 hours vs 18 hours baseline).
- Briefing relevance rate ≥ 60% (reviewers find them useful).
- No statistically significant increase in escaped defects in the treatment group.
- Reviewer adoption rate ≥ 50% (at least half of eligible reviewers interact with briefings regularly).
- Hosted cost at pilot scale confirmed within 20% of estimate.

**Go decision:** Proceed to productionization. Evaluate self-hosted economics at scale. Expand to additional teams.

### Pivot

One or more:
- Time-to-first-meaningful-review reduction is 10–19% (detectable but below target) — the tool has some value but may need better prompts, different model, or different UX.
- Briefing relevance rate is 40–59% — useful for some PR types but not others. Pivot to targeting only high-risk PRs (large diffs, security-sensitive files).
- Adoption is 30–49% — some reviewers use it, others don't. Investigate why; consider making briefings opt-in rather than default.

**Pivot decision:** Extend pilot by 2 weeks with a modified approach (e.g., targeted PRs only, improved prompts, different model). Re-evaluate against go/stop thresholds.

### Stop

Any of:
- Time-to-first-meaningful-review shows no improvement (< 10% reduction) or worsens.
- Escaped defects increase in the treatment group (even if not statistically significant — err on the side of caution).
- Reviewer adoption < 30% after 3 weeks despite outreach.
- Briefing relevance rate < 40% — the majority of output is not useful.
- Cost overruns exceed the $25,000 budget before the pilot completes.

**Stop decision:** Discontinue the capability. Document learnings. Redirect resources.

## Recommendation and strongest objection

**Recommendation:** Proceed with a hosted-model pilot using the A/B design described above. The pilot is cheap ($810 inference cost), fast (4 weeks of data), and designed to produce a clear go/pivot/stop signal. The primary risk (reviewer disengagement or false confidence) is mitigated by explicit guardrails and a control group.

**Strongest objection:** The pilot measures *time-to-first-review*, but the stakeholder cares about *escaped defects* — and the spec explicitly states there is no trustworthy baseline connecting the two. Even if the pilot shows a 30% reduction in review delay, we cannot prove this reduces defects within 6 weeks. A skeptical finance leader would rightly ask: "You're making reviews faster, but are you making them *better*?" The honest answer is: we've designed the pilot to detect if it makes reviews *worse* (via escaped defect tracking), but proving it makes them better requires 3–6 months of post-merge defect data. The pilot's go decision is therefore conditional — it validates *speed and adoption*, not *quality impact*.
