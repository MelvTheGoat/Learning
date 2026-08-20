# Self-Assessment

## Strongest part of the submission

The incident analysis. Every claim in it — the queue_depth pattern, the tenant-a error concentration, the fallback latency spike — traces back to an actual row in the trace data. I can point at the exact number for anything I claimed, which is the part I feel most confident explaining live.

## Weakest or least certain part

Running the Dart tests myself. My first attempt didn't go smoothly, and a lot of that comes down to me not having deep hands-on experience with Dart's tooling yet — I know Python far better. That's the part I'd want more time with before the review.

## Incomplete work and why

I haven't personally re-run the Dart test suite from scratch outside of the run already captured in the evidence file. That's the next thing on my list — I want to be comfortable running and modifying the tests myself, not just reading a passing result, before I have to do it live.

## First improvement with one more day

Add tests that throw random or malformed payloads at the normalizer — weird types, missing keys, nested junk — not just the four fixtures I was given. Real providers will send stranger things than what's in those four files.

## One decision I would want reviewed before production

How `normalizeSuccess` tells providers apart — it just checks whether the payload has a `choices` key or an `output` key. That works fine for two providers, but if a third provider's response happened to include a `choices` key that meant something different, it could get misread. I'd rather the provider type be passed in explicitly than guessed from the shape of the response.
