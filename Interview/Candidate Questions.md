
# A note before these

These seven questions are asked at almost every AI engineering interview because they're domain-agnostic — they'd apply to a customer support bot, a coding assistant, anything. What makes an answer strong isn't reciting the general theory, it's anchoring the general theory to something you actually built. Every answer below does that.

\newpage

## AI Workflow Design

**Pick a business workflow that could benefit from an AI assistant. How would you design the first prototype, and how would you know if it is useful?**

My project answers a version of this directly, so I'll use it rather than a hypothetical: the workflow was a compliance officer or engineer manually cross-referencing CBN circulars and the NDPA to answer a specific regulatory question — something that currently takes reading through hundred-page documents by hand.

The first prototype wasn't the full deployed system — it was retrieval alone, with no generation at all. I built and evaluated the hybrid BM25-plus-dense retrieval pipeline first, and measured whether it could reliably surface the *correct source passage* for a labelled set of real questions, before writing a single line of prompt or generation code. That ordering was deliberate: if retrieval doesn't work, nothing built on top of it can work either, so I wanted to know that early and cheaply rather than after building a full generation pipeline on a shaky foundation.

How I knew it was useful, concretely: recall@5 of 0.96 and an MRR of 0.842 against a 50-question labelled golden set, with zero retrieval misses in the top 10 across the entire set — meaning the correct passage was almost always findable. Only once that was true did I build the generation layer on top, and only once *that* was evaluated (groundedness, citation validity, refusal correctness) did I consider it something worth deploying. If retrieval had come back at, say, 60% recall, the honest next step would have been to fix chunking and indexing, not to add a fancier prompt on top of unreliable retrieval — a good prompt can't rescue bad retrieval.

If I were prototyping a genuinely new business workflow rather than extending this one, I'd follow the same shape: build the smallest possible slice, measure it against a real (even if small) labelled set before building anything downstream of it, and only add complexity once the layer beneath it is proven to work.

\newpage

## Prompting and Evaluation

**How would you test whether a prompt is producing reliable answers over time? What kinds of examples or edge cases would you include?**

This is close to exactly what my `eval/` module does. I maintain a golden set of labelled questions (`eval/golden_set.yaml`) and run it through the actual pipeline — retrieval and generation — scored automatically, with retrieval metrics kept completely separate from generation metrics, because a bad answer over correct context is a prompt problem while a good-looking answer over wrong context is a retrieval problem, and blending them into one score hides which one you actually have.

For "over time," specifically: this suite is meant to run in CI on every prompt change, with a defined regression threshold (if recall@5 drops more than a set margin below the committed baseline, the build fails). That's what makes it a *reliability-over-time* check rather than a one-time sanity test — a prompt edit that quietly breaks refusal behavior gets caught before it ships, not after a user hits it in production.

The edge case categories I built into the golden set specifically:
- **Out-of-scope questions** — where the correct answer is refusal, not a guess. This is the category most people skip, and it's the one my evaluation actually flagged as weak (refusal correctness came back at 0.40 with my offline stub judge).
- **Near-duplicate distractors** — a wrong-but-similar passage exists alongside the right one, testing whether retrieval and the prompt's grounding instructions actually discriminate.
- **Contradictory sources** — an older circular and a newer amendment that disagree, testing whether the model resolves it sensibly rather than blending both into a confused answer.
- **Multi-hop questions** requiring two sections combined, which my recall metric scores at 0.5 (not a flattering full 1.0) if only one of the two required passages is found — a stricter, more honest definition than typical binary recall.

The refusal-correctness result is worth being specific about, since it's the most interesting number in the whole project: the 0.40 wasn't the deployed system failing — it was my offline stub judge's lexical-overlap heuristic failing on a specific case (a Kenya-related question where the retrieved NDPA cross-border-transfer clause shared enough vocabulary with the question to fool a word-overlap check). That taught me something real: an evaluation harness needs its *own* limitations documented, or you draw the wrong conclusion from a number that's actually measuring something narrower than you think it is.

\newpage

## Retrieval / Context

**When would you use retrieval or embeddings instead of putting everything directly into a prompt? What risks would you watch for?**

My corpus — CBN circulars and the NDPA — is exactly the case where retrieval is the right call rather than context-stuffing: it's larger than comfortably fits in a prompt, it needs precise per-answer source citation down to a specific section and page (which raw context-stuffing doesn't give you cleanly), and different documents get added or amended over time, so I don't want to resend the entire corpus on every single call. If this were instead a ten-page policy document that never changes, I'd genuinely just put it directly in the prompt with caching — retrieval adds real complexity that has to be earned by the corpus's actual size, churn, and citation requirements, not reached for by default.

Risks I specifically had to design around, all real ones I hit:

**Chunk truncation.** A clause like "...shall notify within 72 hours, UNLESS the breach is unlikely to cause harm" landing on a chunk boundary, with the exception silently separated from the obligation. I addressed this with 180-character overlap between chunks — enough to usually carry a qualifying clause across a boundary — and with section-aware chunking that never splits across a meaningful document boundary in the first place.

**Silent recall failure.** The most dangerous risk, and the reason retrieval and generation are evaluated separately in my harness — if retrieval quietly returns the wrong passage, the model answers fluently and confidently from it anyway, with no visible error anywhere. Nothing crashes; you just get a wrong answer that looks exactly as trustworthy as a right one.

**Citation fabrication.** Even with correct retrieval, a model can invent a citation marker that was never actually retrieved. My output guardrail independently reconstructs the valid marker set from what was actually retrieved — never trusting the model's own claims — and strips any invalid citation before the answer reaches the user, with a visible note explaining what was removed.

**Embedding-index mismatch.** If the index is rebuilt with a different embedding model than the one currently loaded at query time, dense search silently compares incompatible vector spaces and returns scores that look like real numbers but mean nothing. I track this in an index manifest and log a loud warning if the embedder ID doesn't match what built the index.

\newpage

## Model Comparison

**If two models give different answers for the same task, how would you decide which one is better?**

I'd run both through the identical evaluation harness against the same golden set — never eyeball a handful of examples and go with a gut impression, since that's exactly the "vibes-based evaluation" that a structured golden set exists to replace. Score both on the same per-category breakdown (not one aggregate number), since an aggregate can hide that one model is meaningfully worse specifically on refusal or multi-hop questions while looking similar overall.

In my project specifically, this is exactly why I built a provider-agnostic interface (`LLMProvider` protocol) rather than hardcoding one LLM API — Groq, Gemini, and any OpenAI-compatible endpoint are all swappable behind the same interface, precisely so a real head-to-head comparison on my own golden set is a config change, not a rewrite.

I wouldn't stop at accuracy. Cost per request and latency are co-equal dimensions of the decision, not afterthoughts — a model that scores 2% higher on my golden set but costs meaningfully more and adds real latency is very often the wrong production choice given this runs on a free-tier deployment budget by design. And different answers don't automatically mean one is wrong — I'd look at *how* they differ first; sometimes both are acceptable and the divergence is stylistic, and sometimes it genuinely reveals one model handling a specific edge case (refusal, negation) worse than the other, which the per-category breakdown is what actually surfaces.

\newpage

## Cost Control

**How would you prevent runaway AI or GPU usage while still allowing useful experimentation and testing?**

Three concrete things from `src/limits.py` and the broader architecture, each defending against a different actor:

**A hard daily spend/request cap**, enforced in code, that kills traffic once hit rather than trusting good behavior. Layered with a per-session sliding window so one visitor can't consume the whole day's budget alone, and an input length cap checked earliest since it's the cheapest thing to reject before any expensive work happens.

**A deterministic stub provider for all testing and CI.** This is the part that specifically answers "while still allowing useful experimentation" — my test suite and CI never call a real LLM API at all. The `StubProvider` is extractive, free, and fully deterministic, so I can run the eval suite dozens of times a day, in CI, on every change, without spending a cent or waiting on network latency. Real API calls are reserved for actual deployment traffic and deliberate, occasional runs against a live provider to validate the stub's approximations are still reasonable.

**Lightweight local models for anything that doesn't need production quality** — the ONNX embedder specifically was chosen partly for memory reasons and partly because it's cheap enough to run constantly during development without a GPU or API cost at all.

I'd add, if I were scaling this further: per-feature cost tagging so a spend spike can be traced to its actual source within minutes, and tracking cost-per-successful-answer rather than only total spend — total spend rising isn't inherently bad if usage is rising with it; what matters is whether cost per resolved query stays sane.

\newpage

## Production Readiness

**What would need to be true before you would let an AI feature be used by real customers?**

I can answer this against my own project's actual state rather than in the abstract, which is more useful: some of this is true today, some isn't yet, and being honest about which is which is itself the right answer to this question.

**True today:** an evaluation gate with defined metrics and a regression threshold wired into CI. An output guardrail that strips fabricated citations before they reach a user, with a visible note rather than a silent failure. Explicit refusal behavior engineered as a first-class, tested feature rather than hoped for. Rate limiting and a spend cap in place before public deployment, not added after. A visible disclaimer that outputs are AI-generated and not legal advice. It's actually deployed and live on GCP Cloud Run — not a local demo.

**Not fully true yet, and I'd say so directly in an interview:** my generation-quality numbers come from an offline stub provider, not a live model — I know retrieval works well (0.96 recall@5) independent of that, but I don't yet have a generation-quality number I'd fully trust for a real launch decision. Before calling this genuinely production-ready for real customers, I'd rerun the same evaluation harness against the live provider and re-validate the LLM-judge component against fresh human labels, since an unvalidated judge is close to a random number generator with good manners.

The general bar I'd apply beyond this specific project: structured logging of every input, retrieved context, and prompt version so any output is reconstructable later; a kill switch that can disable the feature via config, not a deploy; a documented, evaluated failure mode — knowing roughly *how* it breaks, not just that it might; and gradual exposure (internal users, then a percentage, then general availability) rather than shipping to everyone on day one.

\newpage

## Debugging AI Behavior

**If an AI assistant gives a confident but wrong answer, how would you investigate the cause and reduce the chance of it happening again?**

This is close to word-for-word how I actually built the debugging path into the project, so I can describe the real mechanism rather than a general strategy.

**Step one: isolate retrieval from generation.** Take the question, and manually hand the model the known-correct passage, bypassing retrieval entirely. If the answer is now right, the bug is in retrieval — check chunking, embeddings, ranking. If it's still wrong, the bug is in generation — check the prompt's grounding instructions and whether refusal is actually firing when it should. That one test cuts the debugging search space in half in about two minutes, and it's directly why my evaluation harness scores retrieval and generation as separate numbers in the first place — so I don't have to do this isolation manually every time, I already know from the two scores which half is more likely at fault.

**Step two: check the guardrail logs.** My output guard independently reconstructs valid citations from what was actually retrieved and flags any invalid one — so if the wrong answer cited something, I can immediately tell whether it was fabricated (a generation problem) or a real citation to the wrong passage (a retrieval problem).

**Step three, and the one that actually prevents recurrence:** that exact failing question gets added to the golden evaluation set as a permanent regression case. This is the step most people skip, and it's the difference between a fix that holds and a fix that quietly breaks again in three months when an unrelated prompt change is made. I did exactly this while building the refusal-correctness metric — the Kenya cross-border-transfer failure I found isn't just fixed and forgotten, it's now a labelled case the harness checks on every run, so if a future change reintroduces that specific failure mode, CI catches it before it ships rather than a user finding it again.
