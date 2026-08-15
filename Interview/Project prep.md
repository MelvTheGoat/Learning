---
title: "Project Deep-Dive Prep — Nigerian Fintech Compliance RAG Assistant"
subtitle: "Every likely interview question on this repo, organized around real design decisions, rejected alternatives, and the reasoning behind each"
author: "Prepared for Mayungbo Oluwatobi Melvyn"
date: ""
---

# How to use this document

Every question here is anchored to an actual decision in your repo — real file names, real numbers, real trade-offs, not generic RAG theory. Two categories of question, and both matter equally: **"why did you build it this way"** (shows you made deliberate choices) and **"why didn't you use the obvious alternative"** (shows you actually considered the alternatives, not just the first thing that worked). The second is where interviewers separate people who copied a tutorial from people who engineered something.

Read this once fully, then skim it again the morning of the interview. You should be able to open any file in the repo cold and defend every line in it.

\newpage

# Opening / framing questions

**Q1. Walk me through this project in two minutes.**
A RAG assistant answering questions about Nigerian financial and data-protection regulation — CBN circulars, the NDPA — for compliance officers and engineers who currently have to read hundred-page documents by hand to answer a simple question. Hybrid retrieval combining BM25 keyword search with dense embeddings, fused with reciprocal rank fusion. Grounded generation with mandatory inline citations. An output guardrail that strips any citation the model invents rather than trusting it blindly. It's deployed live on GCP Cloud Run via Docker — not a local demo. The interesting engineering constraint was building this to run within a genuinely small memory budget rather than assuming unlimited cloud resources, and that constraint shaped almost every architectural decision in the codebase.

**Q2. What problem does this actually solve, and who is the user?**
Compliance officers and engineers at Nigerian fintechs who need a fast, verifiable answer to a specific regulatory question — "what's the KYC limit for a Tier 1 account," "what does the NDPA require for breach notification" — instead of manually cross-referencing CBN circulars and the NDPA. The user is not a general consumer; the tool is scoped narrowly and explicitly refuses to give legal advice or compliance verdicts, only factual information grounded in the source documents, with a citation the user can independently verify.

**Q3. What was the single hardest engineering problem in this project?**
Making refusal — the model saying "I don't know" when retrieved context doesn't support an answer — a genuinely reliable, measurable behavior rather than a hoped-for one. That required three separate pieces staying in sync: the system prompt asking for an exact sentinel token (`INSUFFICIENT_CONTEXT`), the output guardrail detecting that exact token, and the evaluation harness scoring refusal correctness as its own first-class metric. Change the sentinel string in one place and not the other two, and refusal silently breaks or silently stops being measured — nothing crashes, it just quietly stops working.

**Q4. What would you change if you rebuilt this today?**
Two things, honestly. I'd want real numbers from a live model provider in the evaluation results rather than only the offline stub — the stub validates that the guardrail plumbing works correctly, but it understates refusal quality specifically, because it uses lexical word-overlap rather than genuine understanding of, say, why a question about Kenya isn't answered by a Nigeria-specific cross-border-transfer clause that happens to share a lot of vocabulary with the question. And I'd want a larger, more adversarially-constructed golden set — the current one covers the core categories well but could use more near-duplicate-distractor and contradictory-source cases specifically, since those are the categories most likely to fool retrieval quietly.

**Q5. Why did you pick Nigerian financial regulation as the domain instead of something more generic, like a company FAQ or product docs?**
Two reasons. It's a real, personally relevant problem — compliance in Nigerian fintech is genuinely painful and manual today, so the project isn't a toy. And it's a domain where being wrong actually matters, which forced me to design for trustworthiness from the start rather than bolt it on later — a fintech compliance tool that confidently hallucinates a KYC threshold is a worse outcome than one that just says "I don't know," and that asymmetry shaped the entire prompt and guardrail design.

\newpage

# Ingestion and chunking

**Q6. Why section-aware chunking instead of a standard fixed-size sliding window?**
Because merging text across section boundaries means a citation can point at a blend of two unrelated clauses instead of exactly one. If a user asks about section 40 specifically, they need section 40's text back — not the tail end of section 39 plus the head of section 40, concatenated because they happened to both be short. The rule I enforce is: never merge across a section boundary. The cost is some very short chunks — a two-sentence section becomes its own tiny chunk — and I accepted that deliberately, because short, precise clauses are often exactly what a compliance officer asks about directly.

**Q7. Doesn't that produce a lot of tiny, low-information chunks? Isn't that wasteful?**
Some, yes — but I didn't just assert section-aware chunking was better and move on. I kept `fixed_window_chunks`, a deliberately structure-blind baseline, in the codebase, registered alongside the section-aware strategy in a `CHUNKING_STRATEGIES` dict selectable by name. That means the evaluation harness can actually run both and quantify the real difference in retrieval quality, rather than me asserting section-aware chunking is better without evidence. That comparison is what turns a design opinion into a number I can defend.

**Q8. Why does your chunking cascade through paragraph, then sentence, then a hard character cut as a last resort? Why not just always split by sentence?**
Because a single "sentence" — by the regex's definition — can still exceed the max chunk size in dense legal text that runs on without much punctuation. The cascade tries the least destructive option first (a paragraph boundary), falls back to sentence boundaries if the paragraph is too long, and only falls back to a hard character cut — which can split mid-word — if even one sentence is still too long. That's a genuinely ugly last resort, and I chose it deliberately: one ugly cut in a rare pathological case is a better failure mode than the whole index build throwing an exception on a real document.

**Q9. Why 180 characters of overlap between chunks specifically? Why not zero, or 500?**
Roughly a sentence and a half — chosen as "usually enough to carry one qualifying clause across a boundary." The concrete failure it prevents: a clause reading "...shall notify within 72 hours, UNLESS the breach is unlikely to cause harm" landing exactly on a chunk boundary, with "UNLESS..." stranded in the next chunk, so a retriever surfacing only the first chunk shows an obligation with its exception silently missing. Zero overlap risks exactly that. Much larger overlap (500+) would mean adjacent chunks are mostly duplicate content, wasting index size and diluting each chunk's distinctiveness for retrieval without a proportional benefit.

**Q10. Why not use an LLM to do the chunking — semantic chunking via a model call?**
Cost and latency, mainly — that's an LLM call per document during ingestion, which is neither free-tier-friendly nor necessary here, since the source documents already carry real structural signal (headings, section numbers, PART/CHAPTER markers) that a regex-based parser can extract reliably and deterministically. LLM-based semantic chunking earns its cost on genuinely unstructured prose without clean headings — regulatory documents aren't that, so paying for an LLM call to rediscover structure that's already explicitly present in the text would be wasteful.

**Q11. Your heading-detection regexes are described as "deliberately conservative." What does that actually mean, and why?**
A false positive — treating an ordinary sentence like "12. The Commission may, from time to time..." as if it were a heading — splits a real clause in half mid-sentence, which is exactly the failure mode I was trying to avoid. A false negative — failing to detect a real heading — just means that section's content gets folded into the previous section, which is a milder, more recoverable failure. So the patterns are ordered most-specific-first (Markdown headings, then PART/CHAPTER/SCHEDULE, then "Section N", then dotted numbers, then bare numbered clauses last) and the bare-numbered-clause pattern specifically requires a capital letter immediately after the period, because that alone rules out a large share of false positives like lowercase sentence continuations.

**Q12. Why not just use an existing PDF-to-markdown library instead of hand-writing extraction logic?**
For a general document that would be reasonable. Here, the extraction needs very specific domain knowledge baked in — recognizing "PART III", "Section 40", and dotted clause numbers like "4.2" as structural headings, tracking page ranges per section for citation purposes, and repairing PDF-specific artifacts like hyphenation across line breaks. A generic library gets you clean text; it doesn't know that "12." at the start of a line might or might not be a legal clause number, and it has no reason to track page_start and page_end separately for citation accuracy. That domain-specific logic had to be written regardless of what library did the initial PDF-to-text step.

**Q13. Why track both page_start and page_end for a section instead of just one page number?**
Because a section in a real regulatory document routinely spans a page break — section 40 might start on page 11 and finish on page 12. If I only recorded one page number, roughly half of my citations for multi-page sections would be off by one, silently, and I'd likely never notice unless I went and checked citations by hand against the source PDF. Tracking both lets the citation render as "p.12" when a section fits on one page and "pp.11-12" when it spans two — small detail, but it's the difference between a citation someone can trust and one that's subtly wrong roughly half the time.

**Q14. Why do you prepend the document title and section heading to the text before embedding it, instead of embedding the raw chunk text directly?**
Because a clause read in total isolation — something like "shall not exceed N50,000 per transaction" — is retrieval poison. It has almost no topic words a query would match against. Prefixing it with something like "Three-Tiered KYC Requirements — Tier 1" before embedding gives both the sparse and dense retrievers the topic context they need to match a natural-language question. Critically, this prefixed version is only used for the *embedding text* — the version displayed to the user in the sources panel stays clean and unprefixed, so the citation is exactly what's in the source document, not what I fed the embedder.

\newpage

# Retrieval — BM25, embeddings, fusion

**Q15. Why did you implement BM25 by hand instead of using an existing library like rank_bm25?**
Two concrete reasons, not just not-invented-here. First, the index needs to serialize to plain JSON so a fresh process can load it with zero build step at startup — that's a hard requirement given the deployment constraint, and not every off-the-shelf implementation serializes cleanly or without pulling in its own numpy/scipy dependency tree. Second, memory: on a 2GB deployment target, every additional import costs resident memory, and the BM25 algorithm itself is simple enough — roughly 150 lines — that owning it outright was a better trade than a dependency whose internals I don't fully control.

**Q16. Your BM25 tokenizer keeps words like "shall," "may," and "not" that a standard stopword list would remove. Why?**
Because in legal text those words carry real meaning, not noise. "A controller shall notify" is a mandatory obligation; "a controller may notify" is discretionary. Those are different legal outcomes, and stripping "shall" and "may" as generic stopwords — which a standard English stopword list would do — would destroy the ability to distinguish a mandatory duty from an optional one in a keyword search index, in a compliance tool specifically built to answer questions about exactly that distinction.

**Q17. Why does your BM25 tokenizer allow dots inside tokens, like "s.40" or "4.2," instead of splitting on punctuation the normal way?**
Because a generic tokenizer would split "s.40" into "s" and "40" as two separate tokens, discarding the fact that they belong together as one specific, highly discriminative reference. If a user searches for "s.40" exactly, keeping it as one unbroken token lets it match on that exact, rare token — rather than only matching on the numeral "40" alone, competing against every other "40" in the corpus, including page numbers and unrelated section numbers. This is a small regex change tuned specifically for this corpus, not a generic choice.

**Q18. Why ONNX Runtime for the embedder instead of just using sentence-transformers / PyTorch directly, which is what most tutorials use?**
Memory, specifically. Importing PyTorch costs roughly 350-450MB of resident memory before a single vector is even computed — on a 2GB deployment budget, that's a huge fraction of the entire budget spent purely on framework overhead, not on the actual ~23-million-parameter model doing the work. ONNX Runtime runs the identical model weights — same architecture, same numbers out — through a leaner, inference-only runtime that doesn't carry PyTorch's training/autodiff machinery, which I never need at inference time anyway.

**Q19. Why did you set `intra_op_num_threads=1` for the embedder? Doesn't more threads mean faster?**
Usually, yes, when you have real parallel work to spread across threads. Here, the app embeds one user question at a time — batch size 1 at query time — so there's essentially nothing to parallelize per query. Each additional onnxruntime thread allocates its own memory arena regardless of whether there's work for it, so extra threads here would cost memory for effectively zero throughput gain given the actual batch size this app runs at. It's a deliberately counter-intuitive-looking setting that's correct once you know the real access pattern.

**Q20. Why brute-force cosine similarity search instead of a proper vector database like FAISS or Pinecone?**
Scale. With a few thousand chunks, a plain matrix multiply between the query vector and a `(n_chunks, 384)` matrix takes single-digit milliseconds — genuinely imperceptible to a user — and costs about 6MB of memory for 4,000 chunks. FAISS or a hosted vector DB would add a dependency, a build artifact, and — for approximate nearest-neighbour methods specifically — a real recall/latency trade-off, all to solve a latency problem that doesn't actually exist at this corpus size. If the corpus later grew into the hundreds of thousands of chunks, this is exactly the decision I'd revisit — but building it now would be optimizing for a scale I'm not at.

**Q21. Why do you run both BM25 and dense retrieval instead of picking one?**
Because they fail on opposite kinds of query. Dense embeddings are strong on paraphrase and conceptual similarity — different wording, same meaning — but comparatively weak on exact tokens like a specific clause number or a naira amount, since embedding models have no special respect for numbers or codes. BM25 is the mirror image — very strong on exact token matches, structurally blind to meaning. Running only one means being systematically bad at whatever query style the other one handles well, so I fuse both rather than choosing.

**Q22. Why reciprocal rank fusion instead of just adding the BM25 score and the cosine similarity score together?**
Because those two scores live on completely incompatible scales. BM25 scores are unbounded and can easily reach 15+ for a rare term; cosine similarities from a normalized embedder are bounded to [-1, 1] and cluster in a narrow band, often something like 0.3-0.7. Add them directly and BM25 simply dominates every ranking because its numbers are bigger, not because it's more trustworthy. RRF sidesteps the whole problem by keeping only each retriever's rank — 1st place, 2nd place — and discarding the raw score entirely, since "rank 1" means the same thing regardless of which scoring function produced it.

**Q23. I've also heard of min-max normalization as a fix for that scale mismatch. Why not use that instead of RRF?**
I considered it and rejected it. Min-max normalization is per-query, which creates a subtler problem: if BM25 finds only one weak, barely-relevant match for a given query, that one weak match gets rescaled all the way up to 1.0 — the maximum possible score — purely because it was the best of a bad set. Now a genuinely mediocre hit on one query looks numerically as confident as a strong match from a completely different, better query. RRF avoids that per-query noise sensitivity entirely by never depending on the absolute score values in the first place.

**Q24. Why k=60 in your RRF formula specifically? Where did that number come from?**
It's the value from Cormack et al.'s original 2009 RRF paper, not something I tuned myself. It's a damping constant — it flattens the contribution curve so the gap between rank 1 and rank 2 isn't dramatically larger than the gap between rank 9 and rank 10, which is the right behavior when you don't trust either individual retriever's precise ordering that granularly, only its rough rank. I kept the literature default rather than tuning it against my own small eval set, since tuning a damping constant against 50 golden questions risks overfitting the constant to my specific corpus rather than it reflecting a genuinely better fusion behavior.

**Q25. What's the actual retrieval quality number, and how do you know it's good?**
Recall@5 of 0.96 and MRR of 0.842 across a labelled 50-question golden set, with zero retrieval misses in the top 10 across the entire set. I know it's meaningful, not a fluke, because it's measured against manually labelled ground-truth passages per question, not against the model's own generated answers — retrieval and generation are scored completely separately in my evaluation harness specifically so a good retrieval number can't be inflated by a lucky generation, or vice versa.

**Q26. Why is your reranker optional rather than always on?**
Two reasons. Memory — a cross-encoder is another model that has to fit in the same tight budget as everything else, so I made it a flag rather than a hard requirement, and if it can't fit alongside the embedder and everything else, the app degrades to hybrid retrieval without reranking rather than failing to start. And because reranking is a genuine trade-off, not a strict improvement — it adds latency for a quality gain that needs to be measured, not assumed, which is exactly why it's wired into the ablation comparisons in the evaluation harness rather than just turned on by default.

\newpage

# Generation, prompts, and providers

**Q27. Why does your system prompt prioritize refusal over answering well? Isn't the point of the tool to answer questions?**
The point of the tool is to answer questions *correctly*, and in a regulatory compliance context, the two failure modes aren't symmetric. A refusal costs the user a few seconds of mild frustration — "let me check the source directly." A confidently wrong answer with a fabricated section number costs the user's trust in the tool, and potentially costs their organization a real compliance failure if they acted on it. So the prompt is explicitly ordered — "RULES, in priority order" — with grounding and refusal ranked above being concise or complete, so when those rules conflict, the model has an explicit tie-breaker rather than resolving the conflict unpredictably on its own.

**Q28. Why do you tell the model to emit an exact literal token for refusal instead of just asking it to "say you don't know" in natural language?**
Because "say you don't know" in natural language is not machine-detectable — I'd have no reliable way to programmatically check whether a given response was a refusal or not, which means I couldn't build a guardrail around it or measure refusal correctness in the evaluation harness. An exact sentinel string, defined once as a shared constant and referenced by both the prompt and the output guardrail, makes refusal something my code can actually check for reliably, not something I have to guess at by parsing free text.

**Q29. Why order the retrieved passages before the question in your prompt, rather than the more natural "here's my question, here's some context" ordering?**
Because passages coming first means the model reads all the evidence before it reads the question — by the time it reaches the question, it's already processed everything it's meant to ground the answer in, so the question arrives as "given all that, now what" rather than the model forming an intent to answer and then skimming the context looking for supporting justification for an answer it had already half-decided on. It's a small reordering with a real, documented effect on reducing the tendency to answer from memory instead of from the supplied context.

**Q30. Why restate the valid citation markers explicitly in the prompt ("Valid citation markers: S1, S2...") when the numbered source headers already imply the same thing?**
Deliberate redundancy. Stating the valid output space twice — once implicitly through the numbered headers, once explicitly as a plain list — measurably reduces the rate at which the model drifts outside that space and invents a marker that was never actually retrieved, compared to relying on the model to correctly infer the valid range from context alone. It costs one extra line in the prompt and meaningfully tightens the model's behavior.

**Q31. Why did you build a provider-agnostic abstraction instead of just calling one specific LLM API directly?**
Because there's no room in this deployment for a local model, so generation has to be an HTTP call to somebody else's API — and "which provider" is a decision that can and does change: rate limits shift, pricing changes, a provider's free tier can be discontinued. A small shared interface — one method, `stream()` — means every downstream piece of code (the answer engine, the evaluation harness, the UI) only ever talks to that interface, never to a specific provider's wire protocol, so swapping or adding providers doesn't touch anything else in the codebase.

**Q32. Why did you build a deterministic stub provider instead of just running tests and CI against the real LLM API?**
Cost, determinism, and availability. Running CI against a real API means every test run costs real money and real API quota, produces non-deterministic output that makes test assertions unreliable, and makes the whole test suite dependent on network access and an external service being up. The stub is extractive rather than generative — it quotes directly from retrieved passages using a coverage-based heuristic — so it's free, fully deterministic, and runs with zero network access, which is exactly what a test suite and CI need. I was explicit in the docstring, though, that its refusal behavior is only an approximation of what a real model would do, specifically so nobody — including me, later — misreads its evaluation numbers as representative of the real deployed model's quality.

**Q33. If the stub is just an approximation, why does it matter that it's accurate at all?**
Because it's still testing real plumbing — whether the citation-validity guardrail correctly catches an invented marker, whether the refusal sentinel is correctly detected and handled, whether the prompt assembly is structurally correct. Those are all things I need to know work regardless of which LLM is actually generating text. What the stub can't validate is generation *quality* in the way a real model would need judging — and I was careful not to conflate "the stub's refusal correctness was 0.40" with "the deployed system refuses correctly only 40% of the time," because those are different claims and only one of them is actually true.

**Q34. Why do you catch provider errors and return a degraded response instead of letting the exception propagate and showing the user a clean error page?**
Because retrieval and generation are genuinely independent operations, and a generation failure — a rate limit, a timeout, a provider outage — shouldn't destroy retrieval's work, which already succeeded. If I let the exception propagate, the user gets nothing, even though the system actually found the right passages. Instead, I catch the provider error and still return the retrieved sources with a clear note that generation failed, so the user gets something useful — "here's what we found, though we couldn't summarize it right now" — rather than a total, unhelpful failure caused by one flaky network call.

\newpage

# Guardrails

**Q35. Why is your input guard described as targeting a "low-severity" threat model? Isn't prompt injection a serious security issue?**
It can be, in systems with privileged access or tool use. This one specifically doesn't have that — it's a public, read-only question-answering app with no tools and nothing sensitive to exfiltrate through a successful injection. The real risks here are people trying to burn the app's API quota to turn it into a free general-purpose chatbot, and personal data ending up sent to a third-party LLM provider. I scoped the guard to those two actual risks rather than pretending this needed defenses appropriate to a system with real privileged access, which would have been effort spent on a threat that doesn't apply here.

**Q36. Your docstring admits the input guard "will both miss sophisticated attempts and occasionally fire on an innocent question." Why ship something you know is imperfect?**
Because a heuristic filter that catches the common, low-effort cases is still worth having even though it isn't a complete solution, and I was explicit about its limits rather than overselling it as a robust security boundary. That's also exactly why a block returns a friendly, explanatory message rather than something punitive like a ban — because I know in advance that some legitimate questions will occasionally trip a pattern, and the response to a false positive needs to be forgiving, not adversarial toward the user.

**Q37. Why do you only run PII redaction after every other input check has passed, instead of redacting first?**
Ordering by cost and certainty. A length check is one comparison; regex injection-pattern matching is more expensive; PII redaction is the most involved step. If an input is going to be rejected anyway — too short, too long, matches an injection pattern — there's no point spending effort scrubbing personal data out of it first, since the redacted result would never actually be used. Cheap, disqualifying checks run first; the more expensive, only-relevant-if-we're-proceeding check runs last.

**Q38. Walk me through why the output guardrail's citation check matters more than almost anything else in the system.**
Because an answer citing a marker that was never actually retrieved *looks* exactly as trustworthy as a correctly-cited one — right up until someone actually checks it, discovers the citation is fabricated, and by then may have already acted on the information. A citation the user can't verify is worse than no citation at all, because it looks verifiable. This check independently reconstructs the set of valid markers from what was actually retrieved — never trusting the model's own claims about which markers it used — and compares every citation the model produced against that ground-truth set.

**Q39. When an answer has an invalid citation, why strip just that citation instead of discarding the whole answer?**
Because the rest of the answer might be entirely correct and grounded, and discarding a mostly-good answer over one bad citation throws away real, useful, retrievable work for no benefit to the user. Instead, invalid markers are surgically removed from the text, and a visible note is appended stating exactly what happened and how many citations were removed. The user sees an honestly-flagged answer rather than either a fabricated-looking one or a blank error — which mirrors the same instinct behind the provider-error handling: don't hide the problem, but don't be unhelpfully alarmist about it either.

**Q40. Doesn't checking that citations exist in the retrieved set guarantee the claim itself is actually true?**
No, and I was explicit about that limitation. The check verifies a cited marker was genuinely part of the retrieved context — it does not verify that the specific claim attached to that citation is actually supported by that passage's content. Doing that would require a semantic judge comparing the claim against the passage, which is a heavier, LLM-based check I didn't build into the always-on guardrail path, partly for cost and latency reasons. What I do have is groundedness scoring in the offline evaluation harness, which does attempt exactly that comparison — but that runs offline against the golden set, not on every live production request.

\newpage

# Evaluation harness

**Q41. Why do you score retrieval and generation completely separately instead of one blended answer-quality score?**
Because they fail for different reasons and get fixed by different work. A bad answer over a genuinely correct retrieved passage is a prompt or model problem — I need to look at `prompts.py` or which LLM I'm calling. A good-looking answer over the wrong passage is a chunking or ranking problem — I need to look at `chunking.py`, `bm25.py`, or `fusion.py`. A single blended number moving doesn't tell me which of those to open; two separate numbers do.

**Q42. Why does your recall@k implementation score a question with two relevant sections as 0.5 if only one is found, instead of just checking whether anything relevant was retrieved at all?**
Because the more common binary version — did anything relevant show up in the top k, yes or no — is too generous for this corpus. Some questions genuinely need two different sections to answer completely, a statute's general principle and its implementing guideline's specific number, and finding only one of those two labelled locations is a real, partial failure, not a full success. I chose the stricter, more honest reading specifically because it reflects what "fully correct" actually requires here.

**Q43. Why did you segment claims by citation marker rather than by sentence when scoring groundedness?**
Because a claim in a real, well-written answer regularly spans multiple sentences before its citation appears — something like "Notification must occur within seventy-two hours. It must be made to the Commission and describe the categories of data affected [S1][S3]." If I split on sentence boundaries first, the first sentence has no citation marker anywhere in it and would be scored as an uncited claim, which is wrong — it's actually supported by the citation trailing the second sentence. Splitting on citation markers first, where a marker terminates the claim before it however many sentences that spans, avoids that measurement bug entirely.

**Q44. How do you know your LLM-judge component is actually trustworthy and not just producing plausible-looking numbers?**
I validate it against human labels rather than trusting it blindly — hand-labelling a representative sample and computing agreement (Cohen's kappa) between my labels and the judge's. Below roughly 0.6 kappa, I don't treat the judge's output as trustworthy for reporting. I also test the judge's self-consistency by scoring the same item multiple times and checking the variance, since a judge that disagrees with itself across repeated calls on identical input can't reasonably be expected to agree with a human rater either.

**Q45. Your refusal correctness number is only 0.40. Doesn't that mean the system fails to refuse most of the time?**
No — and being able to explain exactly why not is the actual point of this question. That 0.40 was produced by the offline stub provider, whose refusal logic is a simple lexical coverage heuristic — it refuses when the question's content words fall below a threshold of overlap with the retrieved passages. Looking at the actual logged failures, the specific case that dragged the number down was a question about Kenya's data protection rules, where retrieval correctly found the NDPA's cross-border-transfer provision — which happens to share real vocabulary with the question ("data protection," "transfer," "another country") purely because it's topically adjacent, not because it actually answers a question about a different country's law. The stub's coverage was accidentally high, so its heuristic didn't fire. That's a limitation of the *stub's approximation of refusal*, not evidence that the deployed system — running a real model with genuine understanding of which country a passage is about — fails to refuse at that rate. I have this documented precisely so I don't misread my own numbers.

**Q46. Given that limitation, why report that number at all instead of leaving it out?**
Because an honestly-reported weak number is more valuable than a suppressed one — it tells me and anyone reviewing the project exactly where the offline evaluation's blind spot is, and it's the reason the natural next step is explicitly named: rerun the same evaluation with a real model provider instead of the stub, to get a refusal number that actually reflects deployed behavior. Reporting a number I can explain honestly is worth more than reporting only the numbers that look good.

**Q47. Why do you validate your causal/retrieval logic against a stub before trusting results from the real system at all?**
Because groundedness and citation-validity both scoring a clean 1.000 with the stub isn't really validating generation quality — it's validating that the guardrail *plumbing* itself works correctly, since the stub is extractive and trivially grounds everything it says by construction. That's still useful: it confirms `check_answer` really does compare citations against the retrieved set correctly, and that the judge's overlap computation is implemented correctly, before I ever spend API budget testing the same plumbing against a real, costly model call.

\newpage

# Rate limiting and serving

**Q48. Why three separate layers of rate limiting instead of just one global limit?**
Because each layer defends against a different actor. An input length cap bounds the cost of any single request and is checked earliest since it's cheapest. A per-session sliding window stops one visitor from hammering the app repeatedly. A global daily cap bounds total spend regardless of how many different sessions show up. No single layer covers all three cases — a global cap alone doesn't stop one abusive session from consuming the entire day's budget by itself before anyone else gets to use the app.

**Q49. Your rate limiter state is described as "best-effort" because the container filesystem is ephemeral. Isn't that a real weakness?**
It's a real, named limitation, not a hidden one — I chose it deliberately rather than not noticing it. A production-grade version would persist the daily counter in a real database, immune to container restarts. That's real infrastructure with its own free-tier limits, for a problem whose actual worst-case consequence is mild: the daily counter might reset slightly early if a restart happens to coincide with heavy traffic, giving a slightly-too-generous budget on that one day. Given this runs on a free tier, adding a database purely to solve that specific, low-severity edge case wasn't the right trade, and I documented the reasoning directly in the code rather than leaving it as an unexplained shortcut.

**Q50. Why separate `check` and `consume` into two methods on your rate limiter instead of one method that does both?**
Because `check` alone — read-only, no side effects — is genuinely useful somewhere I actually need it: the input guard's verdict is checked first, and only if the *input itself* is valid does the app go on to check-and-consume the rate limit. A blocked, invalid question shouldn't burn a slot out of a visitor's limited daily quota — that would be punishing someone twice for one mistake. Splitting the read from the write is what makes that distinction expressible in code at all.

**Q51. Why Streamlit instead of a more conventional frontend framework like React?**
Speed of building a genuinely usable chat interface in Python without a separate frontend codebase or a build pipeline — for a project scoped to one deployable app on a free tier, that trade-off strongly favors Streamlit. `st.cache_resource` maps directly onto the "load the index and models once, not per interaction" requirement, and `st.chat_message`/streaming primitives map directly onto a chat UI's actual needs. A React frontend would be more flexible and more production-conventional for a larger team, but it's real additional infrastructure — a separate API layer, CORS, deployment of two services instead of one — for a solo project where that flexibility wasn't the actual constraint I was optimizing for.

**Q52. Why cache the index and embedder with `st.cache_resource` instead of just loading them at module level?**
Streamlit reruns the entire script top-to-bottom on nearly every user interaction — every click, every new chat message. Loading a persisted vector index and an ONNX embedder is expensive enough that doing it on every single interaction, rather than once per running container, would be both slow for the user and wasteful of the exact memory budget the whole project is built around. `cache_resource` specifically caches the object once per running process rather than once per session, which is the correct scope for something like a loaded model that's identical regardless of which user is asking.

**Q53. Why build the index offline and commit it, instead of building it on app startup?**
Because building — parsing documents, chunking, running every chunk through the embedder — takes real time, tens of seconds to a couple of minutes depending on corpus size, and a Hugging Face-style or Cloud Run cold start has a limited boot window before the platform considers the container unhealthy. Building offline and committing the output means the app's startup job shrinks to the simplest possible thing: read three files off disk. That tradeoff — a slightly heavier repo, versus a startup that reliably survives the platform's boot timeout — was an easy one to make.

\newpage

# Deployment

**Q54. Why GCP Cloud Run specifically, rather than a persistent VM or a different platform?**
Cloud Run scales to zero and bills close to nothing at low or no traffic, which matters directly for a demo/portfolio deployment that isn't generating revenue to justify a persistently running server. It also fits the container-based deployment I'd already built via Docker without much additional adaptation, and Cloud Build gave me a straightforward CI/CD path from a container image to a live URL without standing up separate infrastructure for that.

**Q55. What would you need to change to make this handle real production traffic rather than a demo deployment?**
The rate limiter's state needs to move off the ephemeral local filesystem and into something like Redis or a small managed database, so it survives container restarts and works correctly across multiple concurrent instances, since Cloud Run can and does spin up more than one instance under load — a per-instance in-memory counter doesn't enforce a true global daily cap once you're running more than one instance. I'd also want structured, centralized logging (Cloud Logging, or equivalent) rather than relying on container stdout, and real alerting on error rates and provider failures rather than only finding out about a problem when a user reports it.

**Q56. Is this actually live right now? Can I open it?**
Yes — it's deployed and running on Cloud Run. [Have the URL ready to share on screen or paste directly.] That's also the honest answer to "is this a real project or a portfolio exercise" — it's a genuinely working, publicly reachable system, not a notebook.

\newpage

# Hostile / pushback questions — worth rehearsing specifically

**Q57. Isn't this whole system over-engineered for what's essentially a document search tool?**
Every piece of complexity here traces back to a specific, named failure mode, not complexity for its own sake — hybrid retrieval exists because BM25 and dense search fail on opposite query types; RRF exists because naive score-blending is measurably wrong; the citation guardrail exists because an LLM will fabricate a citation if nothing stops it; the ONNX/memory decisions exist because of a real 2GB deployment constraint. I can point to the specific problem each piece of "extra" complexity solves — that's a different thing from complexity added because it seemed sophisticated.

**Q58. Your evaluation numbers were produced with a stub, not a real model. Doesn't that mean you don't actually know if this system works?**
I know the retrieval half works, independent of which LLM generates the final text — recall@5 of 0.96 and MRR of 0.842 don't depend on generation at all. What I don't yet have is a *generation-quality* number I fully trust, and I've been explicit about that rather than presenting the stub's numbers as if they represented the deployed model's real performance. The next concrete step, which I'd do before calling this "evaluated" in a stronger sense, is rerunning the same harness against the live provider and re-validating the judge against fresh human labels at that point.

**Q59. Why should I trust that you built this yourself and understand it, rather than having an AI generate most of it?**
[Answer this one in your own words, honestly, and be ready for it — it's very likely to come up given how the project was actually built. The strongest version of this answer is being able to explain, unprompted and in detail, *why* any specific line is written the way it is — not just what it does — because that's the thing that can't be faked in the room. Everything in this document is built to make that possible: if you can answer Q6 through Q53 above from memory, in your own words, you can answer this one too.]

\newpage

# The one preparation exercise worth doing before the interview

Pick five questions from this document at random. Answer them out loud, without looking, in under 90 seconds each. If you stumble on the "why not X" half of any of them, that's exactly the file to reopen and reread before the interview — the "why did you" half is usually the easy part to remember; the rejected alternative is the part that fades first.
