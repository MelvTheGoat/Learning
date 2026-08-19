# Experience Reflection

Describe one relevant incident or delivery experience you personally worked through. Anonymize the organization and system. If you have not owned a comparable production system, say so and describe the closest experience without presenting it as production ownership.

> **⚠️ YOU MUST REPLACE THIS ENTIRE FILE WITH YOUR OWN EXPERIENCE.** The spec explicitly checks for genuine personal ownership. Do not submit this placeholder. Write about a real incident, delivery, or technical decision you personally participated in. Anonymize the company and system names.

## Situation and your responsibility

- [REPLACE: Describe the system, your role, and what was at stake. E.g., "I was the on-call engineer for a multi-tenant data pipeline serving internal analytics for ~50 teams at a mid-size SaaS company. One upstream data source began returning malformed timestamps at 3 AM..."]

## Evidence you personally inspected

- [REPLACE: What logs, dashboards, metrics, traces, or code did you actually look at? Be specific. E.g., "I checked the Datadog dashboard for the ingestion pipeline, which showed a spike in parsing errors starting at 02:47 UTC. I then tailed the application logs on the affected pod and found..."]

## A hypothesis that was wrong or incomplete

- [REPLACE: What did you initially think was wrong, and why was that wrong? E.g., "My first hypothesis was that the upstream provider had changed their API contract. But when I checked the raw payloads, the schema was unchanged — the issue was a timezone offset that our parser assumed was always UTC."]

## Action you personally took and why

- [REPLACE: What did you do, and what was your reasoning? E.g., "I deployed a hotfix that normalized incoming timestamps to UTC before parsing, and added a schema validation step that rejects records with unparseable timestamps rather than silently coercing them to epoch 0."]

## Outcome and how it was measured

- [REPLACE: What happened after your action, and how did you verify it worked? E.g., "Parsing errors dropped to zero within 5 minutes of the deployment. I set up a 24-hour monitoring window and confirmed no recurrence. We tracked data completeness for the affected tables and confirmed 100% recovery."]

## What you would do differently now

- [REPLACE: With hindsight, what would you change about your approach? E.g., "I would have added the schema validation step proactively during the original integration, not as a hotfix. I also would have set up a contract test with the upstream provider to catch format changes before they reached production."]
