# Demo script — 5 minutes

A walkthrough for a live interview or screen-share. Five questions: three that
show the system working, one that shows it correctly refusing, and one that
shows a real weakness on purpose.

**The last one is the important one.** Anyone can demo a happy path. Being able
to point at your own failure mode, explain the mechanism, and say what you would
do about it is the part that distinguishes someone who built a system from
someone who ran a tutorial.

> **Before you start:** open the Space and ask one throwaway question to wake it.
> A cold start is 30–90 seconds and you do not want to spend it in silence. If
> you must demo cold, use it — say "this Space sleeps when idle, and rather than
> show a spinner that looks like a hang, it tells you what it is loading and how
> long it takes."

Verified against the shipped sample corpus and the committed index. Retrieval
order is deterministic, so the source panels will look as described. Exact
answer wording depends on your generation provider.

---

## 0:00 — Framing (30 seconds)

> "This answers questions about Nigerian fintech regulation — CBN circulars, the
> Nigeria Data Protection Act, NDPC guidance. The problem it solves is that this
> information is scattered across PDFs on several websites, so people either read
> hundreds of pages or guess.
>
> The thing I care about most is the panel under each answer. Every claim cites a
> passage, and the passage is right there with its document, section and page. If
> you cannot check the answer, an LLM has just given you a confident opinion, and
> in a compliance context that is worse than nothing."

Point at the sidebar: corpus contents, index build date, known limits.

---

## 0:30 — Question 1: the clean case

**Ask:** *What are the KYC requirements and limits for a Tier 1 account?*

**What happens:** the answer gives the Tier 1 limits with citations. Open the
sources panel — **S1 is "3. Tier 1 accounts — low value, minimal documentation"**
from the CBN tiered KYC circular, found at **rank 1 by both retrievers**, and all
six passages are from that one circular.

**What to say:**

> "Both retrievers agree on this one — it says 'Tier 1' and so does the document.
> Note the whole panel is the KYC circular: section-aware chunking keeps each tier
> in its own chunk, so the model gets Tier 1, Tier 2 and Tier 3 as separate
> passages rather than one blob it has to disentangle. If I had chunked on a fixed
> character window I would be splitting clauses mid-sentence, and a threshold that
> gets separated from its tier is worse than useless."

---

## 1:15 — Question 2: the one that shows why retrieval beats search

**Ask:** *How quickly must a personal data breach be reported, and to whom?*

**What happens:** answer cites the NDPA 72-hour notification duty. In the panel:
**S1 and S2 are NDPA s.40**, **S3 is the NDPC directive's breach handling
section**, and **S4 is the CBN cybersecurity framework's incident reporting
section** — which carries a *separate* 24-hour obligation to the CBN.

**What to say — this is the money moment:**

> "Look at S4. The question was about data breaches, and retrieval also surfaced
> the CBN's cyber incident rule. For a licensed payment provider that suffers a
> data breach, *both* obligations bite: 72 hours to the Data Protection
> Commission, 24 hours to the CBN. Those live in two different documents from two
> different regulators.
>
> That is the actual argument for this over Ctrl-F. Someone searching the NDPA
> finds the NDPA answer and stops. Retrieval over the whole corpus surfaces the
> obligation they did not know to look for."

---

## 2:15 — Question 3: precision on a number

**Ask:** *What is the minimum capital for a Payment Service Bank licence?*

**What happens:** answers ₦5,000,000,000, citing **S1 = "7. Payment Service Bank
licence"**. The rest of the panel is the neighbouring licence categories.

**What to say:**

> "Exact figures are what people actually copy out of a tool like this, so I
> evaluate them literally — the golden set asserts the string '5,000,000,000'
> appears in the answer. Across the 50 in-scope questions, key-fact recall is
> 0.726 with the offline stub that only quotes the first two sentences of each
> passage. That is a floor, not a ceiling, and I report it rather than the
> flattering number.
>
> Also notice the temperature is zero and the retrieval is deterministic, so this
> answer is reproducible. For regulatory content I would rather have boring and
> repeatable than creative."

---

## 3:00 — Question 4: refusing correctly

**Ask:** *What are the data protection rules in Kenya?*

**What happens:** the system **refuses** — "I could not find support for an answer
to that question in the indexed corpus" — while still showing what it retrieved,
which is six passages of *Nigerian* data protection law.

**What to say:**

> "Refusal is a feature, not a fallback. The system prompt makes refusal a named,
> machine-detectable output, which is what lets me score it.
>
> And here is the part I found genuinely interesting. The obvious optimisation is
> to detect this before you spend an API call — if retrieval looks weak, refuse.
> I measured it, and it does not work. This question scores 0.670 cosine
> similarity, which is *higher than 40 of my 50 legitimate questions*, because it
> is a question about data protection rules and the corpus is full of data
> protection rules. The one word that makes it unanswerable barely moves a
> 384-dimensional average.
>
> I swept a lexical threshold too: catching 90% of out-of-scope questions costs
> wrongly refusing 26% of real ones. So there is deliberately no confidence gate
> in this system — refusal is the model's job, because the model can tell that
> Kenya is not Nigeria. That negative result is in the README with the numbers."

---

## 4:00 — Question 5: the weakness, on purpose

**Ask:** *Does a PSP need a CISO and who do they report to?*

**What happens:** the answer is usually still correct, but **open the sources
panel and look at the order**. The genuinely relevant clause — "3. Cybersecurity
governance" from the CBN cybersecurity framework — is at **S5**. Above it sit
NDPC annual audit returns, AML suspicious transaction reporting, and PSP
licensing approval process, none of which answer the question.

**What to say:**

> "This is my system's failure mode and I want to show it rather than hope you
> don't ask.
>
> The question says 'CISO'. The document spells out 'Chief Information Security
> Officer' and never uses the abbreviation. So BM25 — the keyword half — ranks the
> correct clause **19th**. It is matching 'PSP' and 'report' against the wrong
> documents. The dense retriever rescues it at rank 3 because the embedding of
> 'CISO' does sit near 'information security officer', and reciprocal rank fusion
> pulls it into the top 6 so the model can still answer.
>
> But it lands at position 5, and if I had been retrieving top-3 it would have
> been gone. That is the hybrid working as designed and still nearly failing.
>
> Three things I would do about it, in order of cost: a domain synonym map
> expanding CISO, BVN, NIN, STR, PEP at query time — cheap, and this corpus has
> maybe twenty such terms; enabling the cross-encoder reranker, which I have
> measured as fitting in the memory budget (+142 MB, 225 → 367 MB) but have
> *not* measured for quality; or query expansion through the LLM, which costs an
> extra call per question and I would want evidence before paying it.
>
> I would start with the synonym map, because the failure is lexical and a
> lexical fix is testable in an afternoon."

---

## 4:45 — Close (15 seconds)

> "Everything is measured and in the README: retrieval MRR 0.842, recall@5 0.960
> over 60 golden questions; peak memory 225 MB against the 2 GB free-tier limit;
> and the things I could not verify are marked as unverified. The corpus that
> ships is a labelled sample — swapping in the real regulator PDFs is one command,
> and the tool tells the user which corpus it is running on."

---

## Likely questions, and honest answers

**"Why not just use a bigger context window and skip retrieval?"**
> Cost and verifiability. The corpus would be a few hundred thousand tokens per
> question, and more importantly the user would lose the source panel. Retrieval
> is what makes the answer checkable.

**"Why no vector database?"**
> 100 chunks — and it would still be the right call at 100,000. Dense search is a
> numpy matrix multiply over `4 × 384 × n` bytes, single-digit milliseconds. FAISS
> would add a dependency, a build artifact and a recall trade-off to save time I
> am not spending.

**"Is the cross-encoder actually better?"**
> I do not know, and I have not claimed it. I measured that it *fits* — 225 MB to
> 367 MB. I could not measure quality because the export needs network access to
> Hugging Face that the build environment did not have. It is behind a flag,
> defaulted off, and the README says exactly this.

**"How do you know your evaluation is not just measuring the stub?"**
> For groundedness and citation validity, it largely is, and I say so — a stub
> that can only quote its input scores 1.000 almost by construction. Those numbers
> verify the plumbing. The numbers that carry real information are the retrieval
> metrics, which are model-independent, and the key-fact recall. Running against
> a real provider is one flag: `--provider groq`.

**"What breaks first at scale?"**
> Recall, before latency or memory. With 6 documents almost everything is in the
> top 10. At 200 documents the top-6 window gets crowded, and that is where the
> reranker stops being optional. Memory has enormous headroom — the corpus could
> grow 40× before the index is a meaningful fraction of the budget.

**"Is the data real?"**
> The pipeline is; the shipped corpus is not. It is six structured summaries I
> wrote to exercise the system, labelled as non-authoritative in the file, in the
> per-passage metadata, and in the UI sidebar. The fetch script targets the real
> CBN and NDPC PDFs and writes `MANUAL_SOURCES.md` for anything it cannot reach.
> I would not demo this to a compliance team without swapping the real documents
> in first.
