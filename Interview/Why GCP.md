---
title: "Defending: Why GCP Cloud Run"
author: "Prepared for Mayungbo Oluwatobi Melvyn"
date: ""
---

**Q: Why GCP Cloud Run specifically, and not AWS, a VM, or Hugging Face Spaces?**

Cost and traffic shape, mostly. Cloud Run scales to zero and bills close to nothing at low or no traffic, which is the right economics for a portfolio deployment that isn't generating revenue — a persistent VM charges the same whether one person or zero people are using it that hour. It also fits the container I'd already built via Docker with almost no adaptation, and Cloud Build gave me a container-image-to-live-URL pipeline without standing up separate CI/CD infrastructure for it.

I did seriously consider Hugging Face Spaces — a lot of my earlier design work (the ONNX embedder, the tight memory budget) was actually built assuming that kind of free-tier, memory-constrained target. Cloud Run gave me the same scale-to-zero economics but with more control over the container runtime and a cleaner path to a custom domain and proper logging later, so the memory discipline I'd already built in paid off either way.

**If pushed further — "why not AWS Lambda/Fargate?"**

Comparable option, genuinely — I picked GCP because Cloud Build's deploy pipeline was the fastest path from "working Docker container" to "live URL" for a solo project, not because of a deep technical advantage over AWS's equivalents. If the team already ran on AWS, I'd have made the same architectural choices there without much friction — the design isn't GCP-specific, the deployment target is a swappable detail sitting on top of it.
