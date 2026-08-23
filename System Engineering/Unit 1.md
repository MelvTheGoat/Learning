# Month 1 — Week 1: ML Systems Fundamentals

# How to use this

Not a calendar. Seven units, not seven days — move to the next one when
you've actually done the build and explain-aloud steps, not when a clock
says to. If Unit 3 takes you four sessions instead of one, that's fine.

On your retention worry: the plan already has an answer built in, and it's
not "go back and re-read." Each unit ends with a 5-minute **explain aloud**
step — you say what the concept does, why it exists, and what breaks
without it, out loud, to nobody. That's the testing-effect principle from
your interview-prep habit, applied here. If you can do that from memory,
it's learned. If you can't, that's the actual thing to revisit — not a
scheduled re-read of everything.

Where a concept connects directly to something you've already built
(forecasting platform, fraud detection, RAG project, the DartCodeAI
gateway), I've said so explicitly — anchoring new material to a project
you already understand deeply is the single best thing working in your
favor here.

---

# Unit 1 — ML system architecture, end to end

## The concept

The full lifecycle a prediction goes through before a user ever sees it:
data arrives → gets turned into features → a model trains on those
features → the trained model gets registered somewhere → it gets deployed
behind an API → a real request hits that API → the prediction gets
monitored afterward to check it's still good.

Data Sources → Data Pipeline → Feature Engineering → Training Pipeline
→ Model Registry → Model Deployment → Inference API → Users → Monitoring


The one distinction to actually understand, not just recite: **training
is offline and batch, inference is what actually faces a user, and they
have completely different constraints.** Training can take hours and
nobody notices. Inference has a latency budget measured in milliseconds
and a user waiting on the other end.

## Read

- **Chip Huyen, "Machine Learning Systems Design" (free booklet)** —
  <https://huyenchip.com/machine-learning-systems-design/toc.html>
  This is her original free write-up, predating the paid book, and it
  covers exactly this end-to-end lifecycle. Read the "Overview" and
  "Data" sections.
- **Stanford CS329S lecture notes (free)** —
  <https://stanford-cs329s.github.io/>
  The actual university course this whole field is built around. Skim
  the syllabus page to see the full shape of the discipline — you don't
  need to watch lectures, the structure alone is useful.
- **Community summary of Chip Huyen's full book (free, GitHub)** —
  <https://github.com/serodriguez68/designing-ml-systems-summary>
  A detailed chapter-by-chapter summary of the paid book — this is your
  substitute for buying it. Read the "Overview" and Chapter 1–2 summaries.

## Anchor to what you already have

Your forecasting platform already *is* one full instance of this
diagram — walk your own project through the arrows above right now,
naming which real file or stage plays each role (ingestion → dbt/DuckDB
→ LightGBM training → MLflow registry → FastAPI serving → Evidently
monitoring). If you can do that fluently, this unit's core structure is
already yours.

## Build

Draw the architecture for a customer churn prediction system, from data
source to monitoring, using the diagram shape above as your template.
Use Excalidraw (free, <https://excalidraw.com>) or plain paper — the tool
doesn't matter, the act of drawing every arrow yourself does.

## Explain aloud

- What does "training vs. inference" actually mean, in one sentence each?
- Why can't you skip the model registry and just deploy straight from a
  training script?
- Where would monitoring in this diagram have caught last week's
  RAG refusal-correctness problem?

---

# Unit 2 — Data architecture, leakage, and training-serving skew

## The concept

Two closely related failure modes that sound similar and aren't:

**Data leakage** — a feature accidentally contains information from the
future relative to what it's predicting. Your forecasting platform's
automated leakage tests exist specifically to catch this.

**Training-serving skew** — the features your model saw during training
don't match what it sees in production, even though no leakage occurred.
This happens when training and serving compute the "same" feature through
two different code paths that quietly diverge.

## Read

- **"Training-serving skew" — concrete causes and symptoms (free)** —
  <https://dswok.com/General-ML/Training-serving-skew>
  The best resource I found on this specifically. Names the real causes
  (divergent code paths, batch-vs-streaming dual writes, categorical
  encoding mismatches) and gives a concrete symptom: "offline AUC of 0.95
  dropping to online AUC of 0.78" — read this whole page.
- **Google, "Rules of Machine Learning" (free)** — you already have this
  bookmarked from earlier prep. Reread rules 4–6 and the section on
  monitoring specifically through this lens.

## Anchor to what you already have

You've already lived a version of this: your credit risk project's reject
inference work exists because outcomes are only observed for *approved*
applicants — a selection-bias problem that's a close cousin of
training-serving skew (both are "the data your model learns from doesn't
match the world it operates in").

## Build

No new build here — instead, go back to your forecasting platform's
leakage tests and write one paragraph: what specific bug would each test
catch, in plain English, as if explaining it to someone who's never seen
the code.

## Explain aloud

- What's the actual difference between leakage and training-serving skew?
- Name one real cause of skew that has nothing to do with leakage.
- If your RAG project's embedding computation logic ever diverged between
  index-build time and query time, what would that look like in practice?

---

# Unit 3 — Feature stores and point-in-time correctness

## The concept

A feature store is infrastructure that guarantees training and serving
compute features the *same* way, so skew (Unit 2) structurally can't
happen. The specific mechanism that makes this work is called
**point-in-time correctness**: for any training example, the feature
store only ever returns feature values that were actually knowable at
that example's timestamp — never a value from the future.

## Read

- **"Point in Time Correctness and Time Travel" (free, technical)** —
  <https://www.systemoverflow.com/learn/ml-feature-stores/feature-store-architecture/point-in-time-correctness-and-time-travel>
  The clearest technical explanation I found, with the exact failure
  symptom named directly.
- **"Feature Stores — A Hierarchy of Needs" (free)** —
  <https://applyingml.com/resources/feature-stores/>
  Real company case studies (Uber, DoorDash, GoJek) on why they built
  feature stores and what problem each solved.
- **Made With ML — Feature Store chapter (free, practical)** —
  <https://madewithml.com/courses/mlops/feature-store/>
  More hands-on and code-adjacent than the other two if you want to see
  what this actually looks like implemented.

## Anchor to what you already have

This is exactly the concept behind your RAG project's `embedding_text`
property — the deliberate separation between what gets embedded and what
gets displayed. Point-in-time correctness is the same discipline applied
to time instead of to display formatting: "what was true and knowable at
this exact moment," never contaminated by information from later.

## Build

No code needed yet. Write out, in your own words, what a point-in-time
join would look like for your forecasting platform specifically: if
you're predicting demand for 3pm today, what's the latest timestamp a
feature is allowed to come from, and why?

## Explain aloud

- Why doesn't a data warehouse alone solve training-serving skew?
- What does "point-in-time correct" mean, in a sentence you could say to
  a non-technical person?
- What's the actual mechanism (not just the name) that prevents leakage
  in a feature store?

---

# Unit 4 — Model training systems: tracking, versioning, registry

## The concept

Once you're running more than a handful of training experiments, you need
somewhere to record what happened in each one — parameters, metrics,
which data version, which resulting model file — or you'll be unable to
answer "which run produced the model currently in production, and why."
MLflow is the standard free tool for this.

Data → Preprocessing → Training → Evaluation → Register Model


## Read

- **MLflow Tracking Quickstart (official, free)** —
  <https://mlflow.org/docs/latest/ml/tracking/quickstart/>
  The authoritative starting point — go through this exact page top to
  bottom, running the code as you read.
- **MLflow, full getting-started tutorials index (official, free)** —
  <https://mlflow.org/docs/latest/ml/tutorials-and-examples/>
  Come back to this later for the hyperparameter-tuning and PyTorch
  variants once the quickstart clicks.

## Anchor to what you already have

You already use MLflow in your forecasting platform. This unit is about
making sure you can explain *why* it's there, not just that it's in your
stack list — specifically the champion/challenger promotion gate, which
depends entirely on MLflow's registry tracking which model version is
currently "in production" versus "candidate."

## Build

Run the actual MLflow quickstart tutorial end to end — train a small
scikit-learn model, log it, open the MLflow UI locally, and find the
run. If you have five extra minutes, do it a second time with slightly
different parameters and compare the two runs in the UI directly.

## Explain aloud

- What specific question can you answer with MLflow that you couldn't
  answer with just print statements and a spreadsheet?
- What's the difference between "logging" a model and "registering" it?
- In your forecasting platform, what exactly triggers a new model
  registration?

---

# Unit 5 — Model serving with FastAPI

## The concept

A trained model sitting in a registry is useless until something can call
it over a network. Serving means wrapping the model in an API — FastAPI
is the standard, lightweight choice for this in Python.

Client → FastAPI → ML Model → Prediction


## Read

- **MLflow model serving via FastAPI, official docs (free)** —
  <https://mlflow.org/docs/latest/ml/deployment/deploy-model-locally/>
  Shows the direct connection between what you did in Unit 4 (registering
  a model) and this unit (serving it) — MLflow can spin up a FastAPI
  server for a registered model with one command.
- **"Serving a Machine Learning Model from MLflow Model Registry with
  FastAPI" (free, full walkthrough with code)** —
  <https://medium.com/@faizulkhan56/serving-a-machine-learning-model-from-mlflow-model-registry-with-fastapi-946ef97a1975>
  A complete, practical, end-to-end example connecting Units 4 and 5
  directly — train, register, then serve.

## Anchor to what you already have

Your RAG project's FastAPI backend and your DartCodeAI gateway assignment
are both real, tested examples of exactly this pattern, just in two
different languages. If you can explain why `GatewayNormalizer` sits
between the client and the model provider, you already understand why a
FastAPI layer sits between a client and a served model.

## Build

Take one of your existing trained models (the credit risk scorecard is a
good candidate) and wrap it in a minimal FastAPI endpoint: one POST route
that accepts input features and returns a prediction. Containerize it
with Docker once it works locally — see the Docker links below if you
need them.

- **Docker's own official interactive tutorial (free)** —
  <https://docs.docker.com/get-started/>
- **Docker 101, official (free, browser-based labs available)** —
  <https://www.docker.com/101-tutorial/>

## Explain aloud

- What happens to a request if the model file fails to load when the API
  starts?
- Why is loading the model once at startup better than loading it inside
  every request handler? *(You already know this exact answer from the
  RAG project — say it from memory.)*
- What would you need to add to this API before letting a real user call
  it? (Hint: think back to your DartCodeAI rate-limiting work.)

---

# Unit 6 — Scaling: load balancing, caching, latency vs. throughput

## The concept

Once one server isn't enough, you run several copies behind a load
balancer, which distributes incoming requests across them. This only
works cleanly if each server is **stateless** — holds no memory of past
requests — so any server can handle any request.
         ┌── Model Server

Client → LB ─┼── Model Server
└── Model Server


Two terms worth being precise about, since they get confused constantly:
**latency** is how long one single request takes; **throughput** is how
many requests the whole system handles per second. You can improve one
while hurting the other — a system that batches ten requests together
before processing (raising throughput) makes each individual request
wait longer (raising latency).

## Read

No single new link needed here — this is general backend systems
knowledge you can reason through directly, and it's the same vocabulary
underlying the capacity arithmetic you already did for real in the
DartCodeAI assignment (concurrency, headroom, bottlenecks). If you want a
deeper general reference later, **Alex Xu's *System Design Interview*
(Vol. 1)** is the standard, widely-recommended book for this — not
required now, just worth knowing it exists for when you want more depth
on pure backend scaling separate from the ML-specific material.

## Anchor to what you already have

This is the exact vocabulary from your DartCodeAI system design work —
you already computed real concurrency numbers (167 req/s sustained, 780
concurrent slots at burst). This unit is just extending that same
reasoning to a model-serving context specifically, where the "slow
downstream dependency" is your own model's inference time instead of an
AI provider's response time.

## Build

Take the FastAPI service from Unit 5 and answer, in writing: if this
needed to handle 100 requests per second, what's the first thing that
would break, and what's the first thing you'd add to fix it (a cache? more
instances? a queue?). You don't need to implement it — reasoning it
through in writing is the actual exercise.

## Explain aloud

- Why does a stateless server matter for load balancing specifically?
- Give one real example of when improving throughput would make latency
  worse.
- What's the caching risk specific to ML predictions, that doesn't exist
  in ordinary web caching? *(Hint: what happens if you cache a prediction
  for a user whose features just changed?)*

---

# Unit 7 — Review: design a fraud detection system for a Nigerian fintech

## The task

Don't build anything. Design it, on paper or in a doc, and then explain
it out loud as if presenting to a technical interviewer. This unit exists
to force Units 1–6 to connect into one coherent answer instead of staying
six separate facts.

Cover explicitly:

- **Data sources** — what feeds this system, and how fresh does it need
  to be?
- **Features** — what would you actually compute, and where does
  point-in-time correctness (Unit 3) matter most here specifically?
- **Training** — batch, how often retrained, and what would trigger an
  early retrain?
- **Inference** — real-time or batch? What's the latency budget, and why?
- **Database** — what needs to persist, and where?
- **API** — what does the serving layer (Unit 5) look like here?
- **Scaling** — apply Unit 6 directly: what's the bottleneck at 10x
  current volume?
- **Monitoring** — what specifically would you watch, and what would
  trigger an alert?
- **Failure handling** — if the model server goes down, what happens to a
  live transaction? (This is your DartCodeAI fallback-safety thinking,
  applied to a new domain.)

## Anchor to what you already have

This is, almost point for point, the shape of your actual sequence-based
fraud detection project — you have real answers to most of these
questions already, from a project you built and can defend. The task here
is presenting them as one coherent system design narrative rather than a
list of things you did.

## The actual test

Give yourself 45–60 minutes, uninterrupted, and talk through the whole
design out loud, start to finish, without stopping to look anything up.
If you get stuck on a specific piece, note it — that's your real signal
for what to revisit before Week 2, not a scheduled re-read of everything
above.

---

# Before moving to Week 2

You should be able to, from memory, without notes:

- Draw the full lifecycle diagram from Unit 1 and explain every arrow.
- State the difference between leakage and training-serving skew.
- Explain what a feature store actually guarantees, and why.
- Say what MLflow's registry is for, distinct from its tracking feature.
- Explain why a model gets loaded once at API startup, not per-request.
- Give one concrete example of a latency/throughput tradeoff.
- Talk through the Nigerian fintech fraud design end to end, unaided.

If two or three of these are shaky, that's normal and fine — note which
ones, and let the answer-then-check habit from your interview prep handle
the rest naturally as you move into Week 2's more hands-on engineering
work.
