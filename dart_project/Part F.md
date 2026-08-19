---
title: "Part F — Worked Example, Then Your Questions"
subtitle: "A parallel scenario showing how every metric connects, before you build your own"
author: "Prepared for Mayungbo Oluwatobi Melvyn"
date: ""
---

# Why a worked example first

The metrics in Part F don't sit in a list — they form a chain, where each one exists specifically to answer a question the previous one couldn't. Seeing that chain built once, in a scenario that isn't yours, should make the logic click before you have to build it yourself under time pressure.

---

# The worked example: an AI customer support ticket triage assistant

**The scenario (invented, mirrors your real one in shape):** A SaaS company gets 3,000 support tickets a month. Median time from ticket opened to first human reply is 6 hours. Leadership believes faster first response reduces customer churn, but there's no proven link yet — just a belief. An AI tool could read each incoming ticket and auto-draft a suggested reply plus a priority tag, for a human agent to review and send. Hosted-model cost: $0.04 per ticket processed, and early tests show it needs about 1.8 calls per ticket (draft, then a re-check pass). Self-hosting could cut the per-call cost but needs an estimated $18,000 setup. Six weeks, $15,000 pilot budget. Decide: go, pivot, or stop.

Now watch how the pieces connect, in order.

### 1. Target user and the decision this enables

The target user is the support agent, not the customer directly — the agent is who actually uses the tool. **The decision it enables:** should leadership roll this out company-wide, change what the tool does, or kill it. Naming this first matters because it tells you what "success" even means — success is defined relative to *this* decision, not some abstract "AI is good" feeling.

### 2. Facts vs. assumptions vs. unknowns — this is where most of the real thinking happens

- **Facts:** 3,000 tickets/month, 6-hour median first-response time, $0.04/call, ~1.8 calls/ticket, $18,000 self-host setup estimate, 6 weeks, $15,000 budget.
- **Assumption to test:** that faster first response actually reduces churn. This is stated as a *belief*, not a fact — that's the single riskiest unproven link in the whole scenario, and it's the thing the pilot most needs to interrogate.
- **Unknowns:** whether agents will actually trust and use the AI draft rather than ignoring it and writing their own from scratch; whether draft quality holds up on the company's messier, real-world tickets versus the tickets used in early testing.

Notice: the assumption and the unknowns are *why* you can't just say "ship it" on day one. They're the actual reason a pilot needs to exist at all.

### 3. Outcome metrics — and why there have to be three different *kinds*

You need one number for "did this work for the business," a separate number for "is the AI itself doing its job well," and a separate number for "is anything going wrong that a business metric alone wouldn't catch." One number can't do all three jobs:

- **Primary business outcome:** reduction in time-to-first-human-reply. Chosen specifically because it's measurable *within* the six-week window — churn takes months to observe honestly, so it can't be the pilot's primary metric even though it's the thing leadership ultimately cares about.
- **Model/product quality measure:** percentage of AI drafts sent with no edit, or a minor edit, versus rewritten from scratch. This tells you if the AI is actually good, separate from whether it happens to correlate with faster replies.
- **Guardrail:** agent override/ignore rate, and a manual spot-check of draft accuracy on sensitive tickets (billing disputes, cancellations). This exists to catch a failure mode the other two metrics would miss entirely — the AI could look fast and get used often while quietly giving bad advice on the tickets that matter most.

This is the pattern: **business metric asks "did it help," quality metric asks "is it good," guardrail asks "is it secretly hurting something the other two can't see."** Every AI business case needs a version of all three, or you can end up celebrating a metric that's rising for the wrong reason.

### 4. The falsifiable pilot — the design that makes the whole thing honest

Run it on two comparable support queues — one gets the AI tool, one doesn't, for the same six weeks. That second, untouched queue is the **control**. Without it, if time-to-first-reply drops 20%, you have no way to know if the AI caused that or if support just happened to be quieter that month. The control is what makes the pilot *falsifiable* — it's genuinely possible for the result to come back "no real difference," and you'd know it.

### 5. Unit economics — the actual arithmetic, and what's still missing after it

At 3,000 tickets/month: 3,000 × 1.8 calls × $0.04 = **$216/month** hosted variable cost.

At a hypothetical 30,000 tickets/month (10x growth): 30,000 × 1.8 × $0.04 = **$2,160/month**.

What's *missing* from that number, stated honestly: the cost of an agent's time spent double-checking or fixing a bad draft on tickets where the AI was wrong; the engineering cost of maintaining the integration; and the fact that 1.8 calls/ticket came from early testing and could easily drift upward once it meets messier real tickets.

### 6. Hosted vs. self-hosted vs. a non-ML baseline

Self-hosting's $18,000 setup only makes sense once the hosted variable cost it would save, over time, exceeds that upfront number — do the rough division to find that breakeven volume, and be honest that the self-hosted *ongoing* cost isn't precisely known, only that the per-call fee goes away in exchange for new operational burden. The **non-ML baseline** matters just as much: a simple keyword-based router (tickets containing "refund" or "cancel" get flagged urgent, everything else goes to a queue in arrival order) costs close to nothing and might capture a real chunk of the value. The pilot needs to honestly ask whether the AI beats *that*, not just whether it beats doing nothing.

### 7. First three activities, and what gets deliberately deferred

With six weeks: (1) instrument current time-to-first-reply precisely, per queue, since you can't measure improvement without a precise baseline; (2) build the smallest working version of the draft-and-tag tool for one queue; (3) run the controlled comparison from step 4. **Deferred, on purpose:** company-wide rollout, the self-hosted option, and any attempt to measure churn directly — none of those are answerable honestly in six weeks, and pretending otherwise would produce a fake-precise number nobody should trust.

### 8. Go / pivot / stop — decided *before* the pilot runs, not after

- **Go:** time-to-first-reply drops by a stated meaningful margin in the AI queue versus control, with override/ignore rate staying low.
- **Pivot:** draft quality is good but agents mostly ignore it anyway — that's an adoption/workflow problem, not a model problem, and the fix is different (change how it's presented, not retrain the model).
- **Stop:** override rate is high, or the spot-check turns up bad advice on sensitive tickets — the tool is either useless or actively risky, and no amount of speed improvement justifies shipping that.

### 9. A recommendation someone could actually challenge

"Run the six-week controlled pilot as designed before committing to company-wide rollout or self-hosting." Then name the strongest objection to your own recommendation directly: leadership might reasonably push back that six weeks and one queue is too small a sample to trust — and the honest answer to that objection is that it's true, and that's *why* the recommendation is "run the pilot," not "roll out now" — the whole point of Part F is proposing the cheapest test that could actually be wrong, not the fastest path to a green light.

---

# Now, your questions — mirrored to your real scenario

Same nine-part structure, applied to the actual PR risk briefing case. Answer in rough form and send back.

1. **Target user and decision.** Who's the actual user — the reviewer, the PR author, or both? What decision does the six-week pilot let leadership make?

2. **Facts vs. assumptions vs. unknowns.** List out the facts already given (I've listed them for you in the earlier orientation doc). Then: what's the single riskiest unproven assumption in this scenario — is it the same shape as "faster reply reduces churn" in my example? Name it in your own words.

3. **Outcome metrics.** What's your candidate for the *primary business outcome* — does it need to be observable within six weeks, like my example, or could review-delay reduction actually work here directly? What would the *quality* metric be (something about the AI's flags themselves, not the business outcome)? What's one *guardrail* metric that could catch a failure the other two would miss?

4. **The falsifiable pilot.** What would your control group look like here — which teams get the tool, which don't, and why that split rather than another one?

5. **Unit economics.** Do the actual multiplication yourself: $0.18 × 2.5 runs × 1,200 PRs = ? And at 30,000 PRs/month = ? (Check your numbers against mine in the earlier orientation doc once you've tried it yourself.) What's missing from that number, in your own words — think about what could go wrong that pure API cost doesn't capture.

6. **Hosted vs. self-hosted vs. baseline.** What's the simplest possible non-ML baseline you can think of for "flag risky pull requests" — something a team could build in a day with no AI at all? Would you actually expect the AI to clearly beat it, or are you not sure?

7. **First three activities, and what you'd defer.** Given six weeks, what's the very first thing you'd build or measure? What would you explicitly *not* attempt yet, and why?

8. **Go / pivot / stop.** Try writing one concrete sentence for each of the three — doesn't need to be the final numbers, just your first attempt at what "clearly working," "working but not adopted," and "not working" would each look like here.

9. **The recommendation, and its strongest objection.** What's your gut-level recommendation right now, before overthinking it? And what's the one thing a skeptical product or finance lead would say back to you?

---

Send back whatever you've got, even partial — the multiplication in question 5 and a rough attempt at 8 are the two most load-bearing, so prioritize those if you're short on time.
