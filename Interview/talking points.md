---
title: "The Nigerian Fintech Compliance RAG — 10-Point Interview Summary"
subtitle: "The whole project, in the order you'd actually tell it"
author: "Prepared for Mayungbo Oluwatobi Melvyn"
date: ""
---

# How to use this

These 10 points are written to be spoken in sequence — each one is 15-30 seconds out loud, and together they're the "walk me through your project" answer, start to finish, in about 4-5 minutes. You don't have to say all 10 every time; if an interviewer interrupts after point 4 with a question, that's normal and good. But read them in order a few times so the *shape* of the story is automatic, not the exact words.

---

**1. The problem.** Nigerian compliance officers and engineers were spending hours manually cross-referencing hundred-page CBN circulars and the NDPA just to answer specific questions — like whether a Tier 2 account can hold a certain balance overnight. I built a RAG assistant that answers those questions directly, grounded in the actual regulation, with a citation the user can check themselves.

**2. It's live, not a demo.** It's deployed on GCP Cloud Run via Docker, with real CI/CD through Cloud Build — a public URL, not something running only on my laptop. That mattered to me because getting something deployed is where most portfolio projects stop.

**3. The hard constraint that shaped everything.** I built it to run on a genuinely small memory budget — no assumption of unlimited cloud resources. That single constraint is why I chose ONNX over raw PyTorch for the embedder, why there's no local LLM, why the vector search is a plain matrix multiply instead of a heavier vector database. Almost every architectural decision traces back to that one constraint.

**4. Hybrid retrieval, not just one method.** I combine BM25 keyword search with dense embedding search, fused with reciprocal rank fusion rather than naively adding their scores — because BM25 and dense search fail on opposite kinds of query, and naive score-blending is provably wrong once you look at how differently their scores are distributed.

**5. Chunking respects the document's actual structure.** Rather than blind fixed-size windows, chunks never cross a section boundary, so a citation always points at exactly one clause, never a blend of two. I kept a fixed-window baseline in the code specifically so I could measure — not just assert — that the structure-aware approach was actually better.

**6. Refusal is engineered, not hoped for.** The system is explicitly built to say "I don't know" when retrieved context doesn't support an answer, using a sentinel token the prompt requests, the output guardrail detects, and the evaluation harness scores as its own metric. In a compliance tool, a confident wrong answer is worse than a refusal, so I optimized for that asymmetry deliberately.

**7. Citations are verified, not trusted.** After generation, I independently check every citation the model produced against what was actually retrieved — never trusting the model's own claims — and strip anything fabricated, with a visible note rather than silently discarding the whole answer.

**8. Retrieval and generation are evaluated completely separately.** Recall@5 of 0.96, MRR of 0.842, against a labelled 50-question golden set — that number tells me retrieval works, independent of whichever LLM is generating the final text. I built it this way because a bad answer over correct context is a different bug than a good-looking answer over the wrong context, and one blended score hides which one you actually have.

**9. I know exactly where the weak point currently is, and why.** My evaluation numbers were produced with an offline, deterministic stub provider — necessary for free, fast CI — and its refusal-correctness score came back at 0.40. I can explain precisely why: it's a lexical-overlap heuristic that got fooled on a Kenya-related question because the retrieved Nigerian clause happened to share vocabulary with it. That's a known limitation of the *stub's approximation*, not the deployed system, and the next real step is rerunning the same harness against a live model and re-validating the judge against human labels.

**10. What I'd do next.** Get real generation-quality numbers from the live provider rather than only the stub, expand the golden set with more adversarial and contradictory-source cases, and move the rate limiter's state off the ephemeral local filesystem so it holds up correctly under real multi-instance production traffic.
