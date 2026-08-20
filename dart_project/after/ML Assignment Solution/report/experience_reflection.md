# Experience Reflection

## Situation and my responsibility

I'd built a RAG system before — an enterprise RAG, part of when I first learned hybrid search — but it wasn't put together well. Going into this one, I wanted to actually take it to the end and do it properly, so I told myself not to leave a stone unturned. I also have a real interest in fintech and figured there are a lot of people like me who'd find something like this useful, so I wanted to build something that could actually be used, not just a demo.

I decided early on to build it so it could run on all kinds of devices, which is where the 2GB RAM constraint came from. That was my own decision, not something imposed on me, and it slowed me down and made straightforward things harder than they needed to be — I had to keep finding alternatives instead of taking the easy path. I had to use ONNX instead of PyTorch because of it. I also decided to use hybrid retrieval — BM25 plus dense embeddings — specifically so I'd catch both exact word matches and context-based meaning, not just one or the other.

At a few points I seriously considered dropping some of the harder decisions — ditching the 2GB constraint, importing BM25 instead of writing it by hand, skipping the step where I independently check every citation the model produces against what was actually retrieved. I decided against all of that for two reasons: I knew I wanted this to actually go live, so it had to be built to survive that; and I won't always have the luxury of building without worrying about optimization for every device, so it was better to get used to that discipline now rather than later.

## Evidence I personally inspected

The first real evidence problem showed up early. My retrieval numbers weren't good, and I hadn't incorporated reciprocal rank fusion yet — BM25 was bullying the dense embedding search, so performance on context-based prompts acted poorly. Once I added RRF, I got a Recall@5 of 0.96 and an MRR of 0.842. That fix taught me something I ended up relying on later: trust the number over the instinct, and go find out why it's wrong before assuming the whole thing is broken.

That lesson mattered a few weeks later, when a different number stopped me — refusal correctness came back at 0.40. Only 4 out of 10 out-of-scope questions were correctly refused. Instead of accepting that as a verdict, I went through the failing questions one at a time and asked the obvious questions first: was this a retrieval problem — BM25, dense embeddings, something in the search itself? Or was a specific kind of question fooling the refusal logic directly? The Kenya question was the one that actually explained it: retrieval, doing its job correctly, found the NDPA's real cross-border-transfer provision — the passage was topically close enough, sharing enough real vocabulary with the question, that the refusal check's word-overlap logic got fooled into treating it as relevant when it wasn't.

## A hypothesis that was wrong or incomplete

When I first saw the 0.40, my honest first reaction was that the whole thing was a mess — that the constraints I'd chosen for myself had finally caught up with me, and the system just wasn't going to perform well. That turned out to be the wrong read, and going question-by-question is what corrected it. It wasn't a broad failure. It was a narrow, specific issue in how the evaluation judged relevance, not the retrieval or generation pipeline actually breaking.

## Action I took and why

I didn't accept the 0.40 as a final verdict, and I didn't hide it either. Hiding it would have done more harm than good — if a question could fool the evaluation in my own controlled environment, it could get a lot worse once it was live and someone asked something genuinely adversarial rather than an evaluation question. So I traced each failing question individually, ruling out retrieval first and generation second, until I could point at the actual mechanism instead of guessing at it.

## Outcome and how it was measured

The retrieval fix is measured directly and is already reflected in the deployed system: Recall@5 at 0.96, MRR at 0.842. The refusal investigation is measured differently — it didn't end in a fix yet, it ended in an honest, specific diagnosis. I know the 0.40 is a limitation of how the stub judge checks relevance, not proof the live system fails on 6 out of 10 real questions. That distinction is the actual outcome here, and it's the one I'd rather state plainly than round up into something it isn't yet.

## What I would do differently now

The next real step is getting actual generation-quality numbers from the live LLM provider instead of relying on the stub, and expanding the golden set — making it bigger and covering more of the kind of question that fooled the refusal check this time. I haven't done this yet, but it's on my list to come back to. I'd also like to rebuild the frontend on a different platform, probably React, once the evaluation side is in better shape.

None of that changes how I think about the work I've already put in. I know there are bigger, more complicated systems out there than this one, and I'm fine with that — I'm not competing with anyone. I know exactly how much work went into this, and if something didn't meet the standard it should have, I'm open to hearing that and doing better next time.
