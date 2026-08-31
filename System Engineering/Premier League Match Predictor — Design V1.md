# Premier League Match Predictor — Design (v1, for your review/adjustment)

Built from your original answer, with the fixes from the corrections doc folded in. Treat this as a draft to adjust, not a final answer.

## Step 1 — Load-bearing decisions

- **One model, score-first**: the model predicts a scoreline (e.g., 3-0); outcome (home win/draw/away win) is derived from it. Kept as you had it — this is a coherent, sensible choice.
- **Predictions lock before kickoff**: once a gameweek's predictions are generated, they're final — no regeneration, no leakage from played matches. Kept.
- **Comments are current-gameweek-only, view is current + past gameweeks**: kept as scope, but flagged — this introduces user-generated content (moderation, possibly anonymous vs. identified posters) as a separate concern from the prediction system itself. Treat it as a distinct, smaller sub-feature, not something that needs to affect the prediction pipeline's design.
- **FIFA ratings / transfers / manager changes as strength signals**: good idea, deferred to v2 (see Step 7) — v1 ships on historical match data only, so you have a working baseline before layering in richer features.

## Step 2 — The contract

One combined object per fixture, so everything your UI needs (fixture info + prediction + actual result) lives in one place rather than being split across mismatched response shapes.

```
GET /v1/gameweeks/{gw_number}

200 OK
{
  "gameweek": 15,
  "locked": true,
  "model_version": "predictor-v7",
  "fixtures": [
    {
      "fixture_id": "gw15-che-ars",
      "home_team": "Chelsea",
      "away_team": "Arsenal",
      "home_logo_url": "...",
      "away_logo_url": "...",
      "kickoff": "2026-12-13T15:00:00Z",
      "prediction": {
        "predicted_score": {"home": 3, "away": 0},
        "predicted_outcome": "HOME_WIN",
        "probabilities": {"home_win": 0.60, "draw": 0.25, "away_win": 0.15}
      },
      "actual": {
        "score": null,
        "outcome": null
      },
      "comment_count": 0
    }
  ]
}
```

- `actual` fields are `null` until the match is played, then filled in — exactly matching what you described wanting to show, now actually present in the schema.
- `predicted_outcome` uses unambiguous labels (`HOME_WIN` / `DRAW` / `AWAY_WIN`), resolvable without needing to know "which team is X."
- `probabilities` gives all three outcome probabilities as numbers, not just the favorite's, as a string.
- `fixture_id` gives every match a stable identifier — needed both for the API itself and for attaching comments to a specific match.
- No `limit` parameter — a gameweek's fixture list is naturally small and bounded, nothing to paginate.

```
GET /v1/gameweeks/current      // convenience shortcut to avoid callers tracking GW numbers themselves

POST /v1/fixtures/{fixture_id}/comments   // only accepted if fixture belongs to the current, still-unplayed gameweek — enforced server-side, not just hidden in the UI
```

## Step 3 — Trace one request (corrected: this is precomputed, not live)

Because predictions lock before kickoff and never change, the expensive work happens **once per gameweek**, not on every page view — the same shape as the recommendation system's lookup table, not the fraud detector's live inference.

**Offline, once per gameweek (triggered when the FPL API confirms that gameweek's fixtures are finalized):**
```
Fetch fixtures from FPL API
  → Engineer features per fixture (recent form, head-to-head history, home/away splits — v1 feature set)
  → Run through trained model → get predicted scoreline
  → Derive predicted_outcome + probabilities from the score prediction
  → Store as the gameweek's locked prediction record
  → (no further changes permitted past this point)
```

**Async, after each match is played (triggered by results appearing in the FPL API):**
```
Fetch actual result for the finished fixture
  → Update only the `actual` fields on that fixture's stored record
  → Predictions remain untouched
```

**Live, per visitor:**
```
Visitor requests a gameweek
  → Read the stored fixture+prediction+actual records
  → Render
```
This last step is just a fast read — no model runs here at all.

## Step 4 — What breaks

- **Postponed/rescheduled matches**: excluded from their original gameweek, added back into whichever gameweek they're eventually played in. Kept as you designed — this was correct.
- **Training window**: uses all data up to the most recently *played* match, regardless of gameweek number, so a postponed match doesn't artificially shrink the training set. Kept — this was correct and a genuinely sharp catch.
- **New/promoted teams (cold start, previously left open)**: strawman fallback — use the team's most recent lower-league (Championship) performance stats as a proxy strength signal until they accumulate a handful of Premier League matches of their own, then blend in real PL data as it becomes available. Mark this explicitly as **TBD, needs real research before build** rather than assumed-solved — this is a genuinely tricky problem worth dedicated time later.
- **Retraining validation gate (previously missing)**: every 2 gameweeks, before a newly retrained model replaces the currently deployed one, backtest it against the most recently completed gameweeks. Only promote it if it matches or beats the current model's accuracy; otherwise keep serving the current model and log the retrain attempt for manual review.

## Step 5 — Numbers and their effect on design

- **Historical data**: as far back as available (1992-present), but worth treating recency as its own experiment — the league has changed a lot over three decades, so very old matches may add noise more than signal. Consider testing a recency-weighted or windowed training set against the full-history version, rather than assuming "more data" is automatically better.
- **Model choice**: XGBoost as the starting point (reasonable, flexible, well-understood) — also worth comparing against a Poisson-based scoring model, a classic approach in football analytics specifically because goal counts are non-negative integers, which XGBoost doesn't inherently model as well as a distribution built for count data.
- **Training target vs. headline metric**: kept as you had it — train on score prediction, surface outcome as the primary user-facing metric, with score as a secondary "for fun" addition. This distinction was a good, correct instinct.

## Step 6 — Healthy but wrong

- **Outcome accuracy needs a baseline comparison**: track accuracy against a naive baseline (e.g., "always predict home win," which alone tends to land in the ~45% range in the Premier League) — if your model isn't clearly beating that baseline, it isn't yet doing the interesting part of the job, even if the accuracy number looks reasonable in isolation.
- **Per-class breakdown**: track accuracy separately for predicted home wins, draws, and away wins — a model that's only ever "correct" when it predicts a home win (and wrong every time it predicts a draw or away win) is a different, worse model than the aggregate number would suggest.
- **Score metrics**: track average error in predicted vs. actual goal difference (a softer, more forgiving signal), separately from exact-scoreline hit rate (a much stricter, naturally low-frequency signal) — treat the latter as a bonus stat, not the main quality bar, consistent with your own framing of score as secondary to outcome.

## Step 7 — Flip the assumption / defer for v2

- **If predictions had to update live during a match** (instead of locking pre-kickoff) — this flips the whole shape toward something closer to the fraud detector's real-time model (fast, per-event inference) rather than the recommendation system's precomputed-lookup shape used here.
- **v2 feature enhancement**: incorporate FIFA ratings, transfer activity, and manager changes as team-strength signals, once the v1 pipeline (historical-data-only) is working end-to-end and you have a baseline accuracy to measure the improvement against.
