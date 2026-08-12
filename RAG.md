---
title: "AI Engineer Interview Q&A — Part 2: RAG Systems and Agents"
subtitle: "Retrieval-augmented generation, agent architectures, and the failure modes of each"
author: "Prepared for Mayungbo Oluwatobi Melvyn"
date: ""
---

# Part 2: RAG Systems and Agents

This is the section where your existing project work gives you a real edge — you've built the eval harness, hit the leakage bugs, and read the real numbers. Answer these the way you'd explain your own repo: concrete, with a specific failure mode named, not textbook-generic.

## RAG Systems

**Q1. Walk me through how you would design a RAG system from scratch.**
Start from the question, not the architecture: what corpus, what query patterns, what's the cost of a wrong answer. Then: ingest and clean the source documents, choose a chunking strategy that respects the document's own structure rather than blind fixed windows, embed chunks (and consider a sparse index alongside dense, since keyword and semantic search fail on different query types), build a retrieval pipeline that fuses both signals, optionally rerank with a cross-encoder, assemble a prompt that instructs the model to answer only from retrieved context and cite it, and — critically — build the evaluation harness *before* you tune anything, with retrieval metrics measured separately from generation metrics, so when quality drops you know which half broke.

**Q2. What's the difference between dense retrieval and sparse retrieval (BM25)? When would you use each?**
Sparse retrieval (BM25) matches on exact token overlap weighted by term rarity and document length — excellent for exact codes, IDs, rare technical terms, and anything where the user's wording matches the source's wording closely. Dense retrieval embeds query and passage into a shared vector space and matches on semantic similarity — excellent for paraphrase and conceptual queries where the wording differs but the meaning is the same, weak on exact tokens because embedding models aren't built to privilege exact string matches. Use both, fused, rather than picking one — they fail on opposite query types.

**Q3. How do you evaluate whether your retrieval is actually good?**
Separately from generation, using a labelled golden set of questions with known relevant passages. Recall@k (did the relevant passage appear in the top k), MRR (how high up did the first relevant result rank), and precision at fixed k, ideally broken down per question category rather than one aggregate number — an overall 90% recall can hide total failure on multi-hop or negation questions specifically.

**Q4. What's the difference between recall@k and MRR? When do you report each?**
Recall@k asks a binary question per query — was at least one relevant document found within the top k — then averages across queries; it's the right metric when you just need *something* relevant in the returned set, since a reranker or the generation step can sort out the rest. MRR (Mean Reciprocal Rank) cares about position specifically — it's the average of 1/rank of the first relevant result — and is the better metric when ranking quality itself matters, because a relevant document at rank 1 versus rank 8 are treated very differently even though both would score identically under plain recall@k.

**Q5. How would you handle a corpus that's too large to fit in a vector database cheaply, or that changes constantly?**
For scale: shard the index, use approximate nearest-neighbour search (FAISS, HNSW) rather than exact brute-force once you're past roughly hundreds of thousands of vectors, and consider a two-stage retrieve-then-rerank pipeline so the expensive step (cross-encoder reranking) only runs on a small candidate set. For churn: build an incremental indexing pipeline rather than full rebuilds, track document versions so stale chunks can be identified and invalidated, and decide explicitly on an acceptable staleness window rather than pretending the index is always perfectly current.

**Q6. Why would a RAG answer be wrong even when retrieval found the correct document?**
Generation failure over correct context — the most common causes are the model ignoring or under-weighting part of the retrieved context (especially if it's buried in the middle of a long prompt), the prompt not explicitly instructing grounded-only answering, contradictory information between multiple retrieved chunks that the model resolves incorrectly, or the chunk containing the right topic but not quite the specific fact needed, so the model fills the gap by extrapolating rather than admitting it doesn't know.

**Q7. How do you debug a RAG system that's giving confident but wrong answers?**
Isolate retrieval from generation directly: take the known-correct document and hand it to the model manually, bypassing retrieval entirely. If the answer is now correct, the bug is in retrieval — check chunking, embeddings, and ranking. If it's still wrong, the bug is in generation — check the prompt's grounding instructions, context ordering, and whether the model is being explicitly told to refuse rather than guess when context is insufficient. That single test cuts the debugging search space in half in about two minutes.

**Q8. What's the difference between chunking strategies and their trade-offs?**
Fixed-size windows are simple and predictable but structure-blind, and can split a clause or sentence in half at an arbitrary character boundary. Recursive/semantic chunking splits preferentially on paragraph or sentence boundaries, respecting more natural units. Structure-aware chunking (section-aware, for hierarchical documents like regulation or legal text) never merges or splits across meaningful document boundaries, keeping every chunk attributable to exactly one section — at the cost of producing some very short chunks when a section itself is short. Overlap between chunks (typically 10–20% of chunk size) prevents information at a chunk boundary from being lost entirely to one side.

**Q9. How do you decide chunk size?**
Balance two competing pressures: too small and a chunk lacks enough context to be individually meaningful or embeddable with good signal; too large and you dilute the embedding's precision (a long chunk's vector represents an average of many ideas, matching less precisely to any single query) and waste generation-time context window on irrelevant surrounding text. There's no universal right answer — it depends on the corpus's natural unit size (a legal clause versus a long-form article) and is something you should actually measure via retrieval metrics at a few different chunk sizes, not just guess.

**Q10. What is reranking and why would you add it to a RAG pipeline?**
A second-stage refinement step: retrieve a wider candidate set cheaply (via BM25 and/or dense search), then score that smaller candidate set more expensively and more precisely with a cross-encoder — a model that looks at the query and passage jointly, rather than comparing independently-computed embeddings. Cross-encoders are more accurate but too slow to run over an entire corpus, so reranking gets you their precision at a cost you can actually afford by only applying it to, say, the top 30 candidates rather than every document.

**Q11. What's the difference between a bi-encoder and a cross-encoder?**
A bi-encoder embeds the query and each passage independently into the same vector space, then compares them via a fast similarity computation (cosine, dot product) — this is what makes large-scale retrieval feasible, since passage embeddings can be precomputed and indexed once. A cross-encoder takes the query and passage together as one input and outputs a single relevance score directly — much more accurate because the model can attend across both texts jointly, but it has to run a full forward pass per query-passage pair, making it too slow to use over an entire corpus, which is why it's used only for reranking a small candidate set.

**Q12. How do you handle a RAG query where nothing relevant exists in the corpus?**
The system should refuse rather than hallucinate an answer, and that has to be engineered deliberately, not hoped for. Concretely: set a minimum relevance/similarity threshold below which no context is passed to the model at all; explicitly instruct the model in the prompt to emit a specific refusal signal when the supplied context doesn't support an answer; and treat refusal correctness as a first-class evaluation metric with its own labelled test cases, not an afterthought — a system that's never tested on out-of-scope questions will confidently hallucinate on them in production.

**Q13. How would you build citation/attribution into a RAG system so users can verify answers?**
Number each retrieved chunk (S1, S2, ...) in the prompt, instruct the model to cite the specific marker(s) supporting each claim inline, and then — critically — verify programmatically after generation that every cited marker actually exists in the retrieved set, since the model can and will occasionally invent a citation. Any invalid citation should be stripped from the final answer with a visible note, not silently left in, because a citation the user can't verify is worse than no citation — it looks trustworthy right up until someone checks it.

**Q14. How do you keep a RAG index up to date with a changing source corpus?**
Incremental ingestion pipelines that detect new, updated, and deleted source documents rather than full rebuilds every time; content-hash-based change detection so unmodified documents are skipped cheaply; explicit versioning of both the index and the embedding model used to build it, so a mismatch (index built with model A, queried with model B) is caught rather than silently producing degraded, incompatible search results; and a defined staleness SLA — how out-of-date is acceptable before the index must be rebuilt.

**Q15. What's the difference between standard RAG and GraphRAG, and when would you actually need the latter?**
Standard RAG treats retrieval as independent chunk lookup based on similarity. GraphRAG first extracts entities and relationships from the corpus into a knowledge graph, then retrieval can traverse those relationships to answer multi-hop questions that require connecting several facts together — something flat similarity search structurally can't do, since it has no notion of relationship, only of topical closeness. The cost is a significantly heavier ingestion pipeline (entity extraction, relation extraction, graph construction), so it's worth it specifically when your query patterns genuinely require multi-hop reasoning over relationships, not for corpora that are answerable from single, independent passages.

**Q16. How do you handle multi-hop questions in RAG — questions that require combining information from multiple documents?**
Standard single-shot retrieval often fails here because no single chunk contains the full answer. Approaches: iterative retrieval, where the model's partial answer or a generated sub-question triggers a second retrieval round; query decomposition, where a complex question is broken into simpler sub-questions each answered independently and then combined; and GraphRAG, when the multi-hop structure is genuinely relational rather than just requiring several independent facts. Whichever approach, your golden evaluation set needs multi-hop questions specifically labelled, because they're exactly the category standard RAG silently fails on while single-hop metrics still look fine.

**Q17. What are the main risks and failure modes specific to production RAG systems?**
Silent recall failure — retrieval returns the wrong or irrelevant chunks and the model answers fluently and confidently from them anyway, producing a wrong answer with no visible error. Chunk truncation splitting critical qualifying clauses ("...unless approved by the board") away from the statement they modify. Stale indices serving results from documents that have since been deleted or updated. Citation fabrication. And the "lost in the middle" effect, where retrieved context that's genuinely relevant gets under-attended simply because of where it lands in a long assembled prompt.

**Q18. When would you choose long-context prompting over RAG entirely?**
When the corpus is small and static enough to fit comfortably in the context window (tens of pages, not thousands), when the content changes rarely enough that rebuilding an index isn't worth the engineering overhead, when you don't need per-answer source attribution down to a specific passage, and when cost is less sensitive than engineering simplicity — sending the same large context repeatedly is expensive, but prompt caching mitigates that substantially for content that's genuinely stable across many calls. RAG earns its complexity specifically when the corpus is large, changes frequently, needs access control (different users see different documents), needs precise citation, or the cost of resending everything on every call is prohibitive.

**Q19. How would you evaluate whether a RAG system is ready for production?**
A defined evaluation harness with a labelled golden set covering single-hop, multi-hop, negation, out-of-scope/refusal, and ambiguous questions — not just typical happy-path queries. Retrieval and generation metrics reported separately. An LLM-as-judge component that's itself been validated against human labels (measuring agreement, e.g. Cohen's kappa) rather than trusted blindly. A documented failure taxonomy of the ways the system actually breaks, with real logged examples, not hypothetical ones. And regression testing wired into CI so a prompt or retrieval change that degrades quality is caught before it ships, not after a user reports it.

\newpage

## Agents

**Q20. What is an AI agent, and how does it differ from a simple LLM call or chatbot?**
A simple LLM call is a single input-output transformation — you send a prompt, you get a response, done. An agent has a loop: it can decide which action to take (including calling external tools), observe the result of that action, and decide the next action based on that observation, continuing until it determines the task is complete or a stopping condition is hit. The defining difference is autonomy over a multi-step process with tool use and state, not just generating one response to one prompt.

**Q21. What is the ReAct pattern and how does it work?**
ReAct (Reason + Act) interleaves explicit reasoning steps with actions: the model generates a thought (what should I do and why), then an action (a tool call), observes the tool's result, then generates another thought incorporating that new information, and repeats. Making the reasoning explicit and interleaved with real-world feedback, rather than trying to plan the whole sequence upfront, generally makes agents more robust to unexpected tool outputs or errors mid-task, since each step can adapt to what was actually observed rather than a static a-priori plan.

**Q22. How do you decide whether a task actually needs an agent, versus a simpler single-call or workflow approach?**
Default to the simpler option. A single well-crafted prompt, or a fixed deterministic workflow (a defined sequence of steps with no dynamic decision-making) is more predictable, cheaper, easier to test, and easier to debug than an agent. Reach for an agent specifically when the number and order of steps genuinely can't be known in advance — the task requires the system to dynamically decide what to do next based on intermediate results in a way a fixed pipeline can't anticipate. Building an agent for a task that's actually a fixed five-step pipeline adds cost, latency, and unpredictability for no real benefit.

**Q23. How do you prevent an agent from getting stuck in an infinite loop or spending unbounded compute?**
Hard limits on the loop: a maximum number of steps or tool calls per task, a maximum wall-clock time budget, and a maximum token/cost budget per task, all enforced in code, not left to the model's own judgement about when to stop. Beyond hard limits, detecting repeated identical or near-identical actions is a useful heuristic for catching a genuine loop before the hard cap is even reached, and logging every step so a stuck agent can be diagnosed rather than just killed and forgotten.

**Q24. How do you give an agent access to tools, and what are the risks?**
Tools are typically exposed via function-calling — you provide the model with a schema describing each tool's name, purpose, and parameters, and the model outputs a structured call which your code then actually executes (the model never runs anything itself). Risks: the model calling a destructive tool (delete, send, purchase) based on a misunderstanding or a manipulated input, prompt injection via tool outputs (a malicious webpage the agent reads instructing it to take a harmful action), and cascading errors where one tool's incorrect output feeds directly into the next step's reasoning uncorrected. Mitigations include scoping tool permissions tightly, requiring human confirmation before any irreversible action, and validating tool outputs before feeding them back into the loop.

**Q25. What's the difference between a single agent and a multi-agent system? When would you use multiple agents?**
A single agent handles the entire task within one reasoning loop and one context. Multi-agent systems split a task across several specialised agents — a planner, a researcher, a coder, a reviewer — often coordinated by an orchestrator, each with a narrower role and often a separate, smaller context. This helps when a task is genuinely decomposable into distinct specialised roles, or when you want a built-in check (one agent's output reviewed by another before proceeding), but it adds real coordination complexity and latency, so it isn't automatically better than a well-designed single agent with a good tool set.

**Q26. How do you evaluate an agent's performance, given that its behavior is a multi-step trajectory rather than one output?**
Task success rate on a labelled benchmark of representative tasks is the headline metric, but that alone hides too much — you also want per-step correctness (did each individual action make sense given the state at that point), efficiency (how many steps/tokens/tool calls to reach the answer, since two agents can both succeed with wildly different cost), and failure mode analysis on the trajectories that failed, categorising *why* — wrong tool chosen, correct tool but wrong arguments, correct action but misinterpreted the observation, or getting stuck in a loop. A single success/fail number tells you almost nothing about what to fix.

**Q27. What is agent memory, and what are the different types?**
The mechanisms by which an agent retains and reuses information beyond a single turn. Working memory is the current task's active state — what's happening right now, usually just the current context window. Episodic memory stores specific past interactions or task instances the agent can recall and reference. Semantic memory stores generalised facts or knowledge extracted from past interactions, decoupled from any specific episode. Procedural memory stores learned skills or successful action sequences that can be reused on similar future tasks. Different agent architectures implement different subsets of these depending on how much continuity across sessions the use case actually needs.

**Q28. How would you handle an agent that needs to complete a long-running task that exceeds a single context window?**
Summarise and compress completed steps into a running state summary rather than keeping the full transcript of every action and observation in context; persist critical state externally (a scratchpad, a database, a file) rather than relying on it staying in the context window at all; and break the long task into checkpointed sub-tasks so progress isn't lost and the agent can resume from the last checkpoint rather than restarting, if it's interrupted or a step fails.

**Q29. What is tool selection error, and how do you reduce it?**
When an agent is given multiple tools and chooses the wrong one, or calls the right tool with wrong or malformed arguments, for a given step. It gets worse as the number of available tools grows, because the model has to discriminate between increasingly similar options from a text description alone. Mitigations: clear, distinct, well-documented tool descriptions (ambiguous or overlapping descriptions are the most common root cause); limiting the tool set actually exposed at each step to only what's relevant to the current state rather than always exposing everything; and few-shot examples of correct tool usage in the system prompt for tools that are frequently confused with each other.

**Q30. How do you handle errors and failures within an agent's tool-calling loop?**
Never let a single failed tool call silently corrupt the rest of the trajectory. Catch and structure tool errors so the agent receives a clear, parseable error observation rather than a raw stack trace or a silent empty result — the agent needs to be able to reason about *what* went wrong to decide whether to retry, try a different approach, or escalate. Set a retry limit per step so a persistently failing tool doesn't consume the entire step/cost budget. And for consequential failures, escalate to a human rather than letting the agent guess its way forward indefinitely.

**Q31. What is the difference between planning and execution in agent architectures?**
Planning is the agent (or a dedicated planning module) deciding, upfront or incrementally, what sequence of steps should accomplish the task — essentially producing a plan or the next action to take. Execution is actually carrying out that step — calling the tool, running the code, making the API request — and returning a real-world observation. Some architectures separate these explicitly (a planner LLM proposes steps, an executor carries them out, sometimes with a different, cheaper model), which can improve both quality (planning gets dedicated reasoning effort) and cost (execution can use a smaller model for what's often a more mechanical step).

**Q32. How would you prevent an agent from taking a harmful or irreversible action by mistake?**
Human-in-the-loop confirmation gates before any irreversible action (sending money, deleting data, sending a message externally) — the agent proposes the action, a human approves or rejects it before it executes. Tightly scoped tool permissions, so the agent's blast radius is bounded even if it does something wrong (a tool that can only read, not write, cannot cause irreversible harm regardless of what the model decides). And explicit classification of actions by risk/reversibility, so low-risk actions can proceed autonomously while high-risk ones always route through a human, rather than treating every action identically.

**Q33. What's the difference between few-shot prompting an agent and fine-tuning it for a specific task?**
Few-shot prompting provides examples directly in the prompt at inference time — fast to iterate, no training infrastructure needed, but consumes context window on every call and is limited by how much can be demonstrated in-context. Fine-tuning trains the model's weights on a larger set of examples specific to the task or desired behaviour — more durable, doesn't consume context window at inference time, and can encode patterns too subtle or numerous for a handful of in-context examples to convey, but requires real training infrastructure, data curation, and a slower iteration cycle. Most teams start with prompting and only fine-tune once prompting has clearly plateaued.

**Q34. How do you handle a scenario where two agents (or two steps in a multi-agent system) produce conflicting outputs?**
Depends on what's available to adjudicate: if there's ground truth or a verifiable check, use it directly rather than trusting either agent's self-report. Otherwise, introduce an explicit reviewer/adjudicator step — a separate call (ideally with a different prompt or model, to avoid correlated blind spots) that's given both outputs and asked to reconcile or choose between them. Logging the disagreement itself is valuable regardless of how it's resolved, since a pattern of frequent disagreement between two particular agents is a signal that one of their roles or prompts needs revisiting.

**Q35. What are the main cost and latency considerations specific to agentic systems compared to single-call LLM applications?**
Cost and latency compound across every step in the loop, not just once — a five-step agent trajectory means five (or more) LLM calls, each with its own latency and token cost, plus the tool execution time in between. This makes model routing important — using a cheaper, faster model for simpler steps (tool selection, formatting) and reserving the most capable model for the steps that genuinely need deep reasoning. It also makes step-count efficiency a real product metric, not just an engineering nicety: an agent that reliably solves a task in 3 steps is meaningfully cheaper and faster in production than one that solves the same task in 8, even if both succeed at the same rate.

\newpage

# What's next

Part 2 of 6 done, left in markdown per your request. Remaining:

- **Part 3 — Fine-tuning, Evaluation, and ML Fundamentals**
- **Part 4 — System Design (AI-specific and traditional)**
- **Part 5 — Coding Questions**
- **Part 6 — Behavioral, Project Deep Dives, and Take-Homes**

Say "next part" for Part 3, or tell me if you want a specific one out of order.
