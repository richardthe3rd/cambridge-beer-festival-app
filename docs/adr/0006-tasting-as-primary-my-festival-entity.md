# ADR 0006: Tasting as the Primary My Festival Entity

**Status**: Proposed

**Date**: 2026-07-04

**Deciders**: Maintainer (richardthe3rd)

**Context**: "My Festival" has two jobs for a user: it is a **plan** (a
forward-looking wishlist of drinks they intend to try) *and* a **diary** (a
backward-looking record of what they actually drank, when, and what they
thought). The current data model is **drink-centric**: `UserDrinkState`
(`lib/models/user_drink_state.dart`) hangs `rating`, `notes`, and `photoIds`
off the *drink*, and records tastings only as a bare `List<DateTime>`. That
models the plan well but flattens the diary — a tasting is just a timestamp,
carrying none of the "how was it" that a diary entry wants. Before building the
detail-screen capture flow (#415) and the photo/recommend features (#416/#417)
on top of that flat model, we need to decide what the **primary entity** of My
Festival actually is.

---

## Decision

Make the **Tasting a first-class entity** — a "check-in" — and treat My
Festival as the intersection of two axes:

| Axis | Entity | Direction | Field today |
|---|---|---|---|
| **Plan** (wishlist) | the drink, flagged | forward-looking intent | `wantToTry: bool` |
| **Diary** (log) | the **Tasting** | backward-looking record | `tastingEvents: List<DateTime>` → `List<Tasting>` |

A `Tasting` carries the "how was it" that currently lives at drink level:

```
Tasting {
  when: DateTime          // the check-in moment (identity)
  rating?: int            // 1–5, this pour
  wouldRecommend?: bool   // #417, this pour
  note?: String           // this pour
  photoIds: List<String>  // #416, this pour
}
```

Consequently:

- **`wantToTry` stays drink-level** — it is intent about a *drink*, not an
  event. It is the plan axis and is unchanged.
- **Drink-level `rating`/`notes`/`photoIds` become derived**, not stored: a
  drink's "your rating" is an aggregate/most-recent view over its tastings.
- **My Festival's "Tasted" view becomes a timeline of tastings** (check-ins),
  grouped by day — which is already the direction `vision.md` and #414 took.
- **"Mark as Tasted" becomes the create action for a check-in**, and the
  capture flow (rate / recommend / note / photo) attaches to *that* tasting.

**Local-first boundary (important):** this ADR decides the **local** model
only. The deployed Review API and the `DrinkEntry` proto contract are
**per-drink** (`star_rating`, `would_recommend`, `note`, and `pours` as a bare
count). Per-tasting detail — the timeline, per-pour notes and photos — stays
**device-local** for now; sync continues to carry the per-drink aggregate. Any
change to make the *wire* contract per-tasting is a separate, proto-first
decision (a future ADR), and must not block the local diary. This preserves
the campaign's local-first / free-tier / low-ops constraints.

---

## Alternatives Considered

### A. Keep the drink-centric model (status quo)
- Simplest; no migration; `rating`/`notes` already map 1:1 to the deployed
  per-drink Review API.
- Rejected because: it cannot express the diary. "Was it better the second
  time?" forces an overwrite of a single drink-level rating/note; photos and
  notes have no natural per-moment home. The tasting stays a bare timestamp,
  which is exactly the limitation #415/#416 would be building around.

### B. Hybrid — keep drink-level "overall" fields *and* add per-tasting fields
- Both a drink-level `rating`/`note` (syncs, feeds community aggregate) and a
  richer per-tasting record.
- Rejected as the *primary* model because it doubles the surface (two places a
  rating can live), creates an "which one is truth" ambiguity in the UI, and
  invites drift. A drink-level **aggregate** is still needed for the community
  rating, but it should be **derived** from tastings (see Decision), not a
  second stored source of truth.

### C. Tasting as primary, per-tasting fields (**chosen**)
- The diary becomes first-class; the plan (`wantToTry`) is orthogonal; drink
  aggregates derive from the log.
- Accepted despite a real migration cost and a divergence from the per-drink
  wire contract (see Consequences), because it is the only model that makes My
  Festival a genuine diary and it resolves the per-pour tension cleanly.

---

## Consequences

### Positive
- My Festival becomes a real **diary + plan**, matching how a festival is
  lived (a sequence of moments, plus a wishlist).
- Rating, would-recommend, note, and photo attach to a **moment**, resolving
  the per-pour-vs-per-drink question by construction.
- The "Tasted" timeline (#414) and the capture flow (#415) sit on a model that
  fits them, instead of around a flat one.
- Auto-revert to want-to-try (delete all tastings on a `wantToTry` drink) still
  falls out of the derived section rule — no special-casing.

### Negative
- **Released-app migration.** `UserDataStore` is at schema v1 with real user
  data. Moving `rating`/`notes`/`photoIds` onto tastings is a **v1→v2
  migration**, not an additive field — it must be routed through
  `UserDataStore.migrate` and cannot silently drop existing ratings/notes.
- **Divergence from the wire contract.** The local model becomes richer than
  the deployed per-drink Review API and the `DrinkEntry` proto (`pours` is a
  count, not a list). Per-tasting detail is not synced under this ADR; cross-
  device diary history would require a future proto-first contract change.
- **Rating aggregation semantics.** "Your rating of this beer" must be defined
  as a derivation (latest tasting? mean? last non-null?). The **community**
  aggregate (`reviewSummaries`) assumes one rating per device per drink, so the
  synced value must remain a single per-drink number derived from the log.
- **#415 must be re-scoped** to build against the Tasting entity rather than the
  drink-level action bar it currently specifies. Some of #415-as-written would
  otherwise be interim/throwaway.

### Migration approach (open sub-decision)
On upgrade to schema v2, for each `UserDrinkState`:
- **≥1 tasting:** attach the existing drink-level `rating`/`notes`/`photoIds`
  to the **most recent** tasting (best-effort; the user recorded them "about"
  that drink, and the latest pour is the closest moment).
- **rating/notes but no tasting** (rated without logging a tasting): synthesise
  a single tasting at `updatedAt` carrying them, **or** retain a drink-level
  "overall" specifically for the derived/community rating. Recommended:
  synthesise, to keep one model; flagged as the key migration decision.
- `wantToTry`, `createdAt`, `updatedAt` are unchanged.

No data is discarded either way; the choice only affects *where* an existing
rating lands.

---

## Implementation (outline — not built by this ADR)

- **Model**: introduce a `Tasting` value object; change
  `UserDrinkState.tastingEvents: List<DateTime>` → `tastings: List<Tasting>`;
  make drink-level `rating`/`notes`/`photoIds` getters that derive from
  `tastings`. Thread through `copyWith`/`toJson`/`fromJson`/`isEmpty`/`==`.
- **Storage**: `UserDataStore` schema `currentSchemaVersion` 1→2 with a
  `migrate` step per the approach above; pin nothing new in `PreferenceKeys`
  (the record lives inside the per-drink JSON blob).
- **Provider/derivation**: `myFestivalEntries` gains a tasting-timeline view;
  drink aggregates derive from the log.
- **UI**: #415 re-scoped to create/edit tastings; capture flow attaches
  rating/recommend/note/photo to the tasting.
- **Sync**: unchanged under this ADR — continues to carry the per-drink
  aggregate; per-tasting detail is device-local.

---

## Related Documents

- `docs/planning/my-festival/vision.md` — the multi-phase roadmap (#411–#417)
- `proto/cambeerfestival/festival/v1alpha/drink_entry.proto` — the per-drink
  wire contract this model deliberately diverges from (locally)
- Skills: `architecture-contract` (storage/versioning invariants),
  `api-contract` (wire-contract evolution rules), `my-festival-campaign`
- Issues: #315 (epic), #411 (mutators, done), #414 (timeline screen, done),
  #415 (detail capture — to be re-scoped), #416 (photos), #417 (would-recommend)

## Open Questions

1. Migration of a rating that has no tasting: synthesise a tasting, or keep a
   drink-level "overall"? (Recommended: synthesise.)
2. Derivation rule for a drink's displayed/synced rating: latest tasting, mean,
   or last non-null? (Community aggregate constrains this to one per drink.)
3. When, if ever, does the *wire* contract go per-tasting? (Deferred to a
   future proto-first ADR; not required for the local diary.)
