# ADR 0006: The Check-in as the Primary My Festival Entity

**Status**: Proposed

**Date**: 2026-07-04

**Deciders**: Maintainer (richardthe3rd)

**Context**: "My Festival" has two jobs for a user: it is a **plan** (a
forward-looking wishlist of drinks they intend to try) *and* a **diary** (a
backward-looking record of their festival). The current model is
**drink-centric**: `UserDrinkState` (`lib/models/user_drink_state.dart`) hangs
`rating`, `notes`, and `photoIds` off a *drink*, and records tastings only as a
bare `List<DateTime>`. Three requirements break that model: (1) a tasting wants
to carry "how was it" (rating/note/photo) **per pour**, not per drink; (2) the
diary should capture **non-drink events** — food, a moment, anything — which
have no drink to hang off; and (3) users must be able to **add entries they
forgot**, after the fact, with a chosen time. Before building the capture flow
(#415) and photos/recommend (#416/#417), we need to decide what the **primary
entity** of My Festival is.

---

## Decision

Make the **check-in** — a *My Festival log entry* — the primary entity: a
**festival-scoped, timestamped record that _optionally_ references a drink.**
The diary is a **timeline of these entries**; the plan is a separate,
per-drink `wantToTry` intent.

| Axis | What it is | Scope | Field |
|---|---|---|---|
| **Plan** (wishlist) | drink flagged to try | per drink | `wantToTry: bool` |
| **Diary** (log) | timeline of **check-ins** | per festival | ordered `List<LogEntry>` |

A **tasting is simply the drink-kind check-in.** The entity generalises it:

```
LogEntry {                 // a My Festival check-in
  id: String               // stable UUID — identity (see User Experience)
  when: DateTime           // user-editable; defaults to now, can be backdated
  kind: tasting|food|other // extensible; tasting is the drink-linked kind
  drinkId?: String         // set for a tasting; null for food / other
  title?: String           // for non-drink entries ("Scotch egg from the pie stall")
  rating?: int             // 1–5, any kind
  wouldRecommend?: bool    // #417, any kind
  note?: String
  photoIds: List<String>   // #416
}
```

Consequently:

- **The festival timeline is the source of truth** for the diary. Drink-level
  views derive from it by filtering `entries.where(drinkId == this)`.
- **`wantToTry` stays a per-drink intent**, separate from the timeline — it is
  the plan axis, not an event.
- **Non-drink events are first-class.** Food and other moments are entries with
  no `drinkId` and a free-text `title`; they appear in the timeline and nowhere
  drink-specific.
- **Drink-level `rating`/`notes`/`photoIds` become derived**, not stored — a
  drink's "your rating" is an aggregate over its tasting entries.

**Local-first boundary (important):** this decides the **local** model only.
The deployed Review API and the `DrinkEntry` proto are **per-drink**
(`star_rating`, `would_recommend`, `note`, `pours` as a count). Per-entry detail
— the timeline, per-pour notes/photos, and **all non-drink entries** (which have
no wire home at all) — stays **device-local**. Sync continues to carry only the
per-drink aggregate. Making the wire contract per-entry is a separate,
proto-first decision (a future ADR) and must not block the local diary. This
keeps the campaign's local-first / free-tier / low-ops constraints.

---

## User Experience

The diary only earns its keep if logging is effortless, forgiving, and able to
capture the *whole* festival — not just scanned drinks. Four principles, each
with an architectural consequence.

### Low-friction, inviting create
On a drink page, "Mark as Tasted" is **one tap**: it creates+persists a tasting
check-in at the current time with every other field empty, **before** anything
else. An optional, dismissible capture sheet (rate / recommend / note / photo)
then slides up. Log-and-move-on users are already done. No required fields, no
wizard, no blocking spinner. The festival-conditions bar: one hand, a pint,
patchy signal.

### Add anything, including things you forgot
A **"+" on the My Festival timeline** creates a check-in of any kind: pick a
drink (catalogue search) for a tasting, or type a free-text `title` for food /
a moment. The time **defaults to now but is freely set** — so "add the pie I
forgot to log at lunch" is the same flow with an earlier time. Backfill is not a
special case; it is create-with-a-past-`when`.

### Everything is editable after the fact
A diary gets revised. Every field of an entry — rating, recommend, note, photos,
`kind`/`title`, **and the timestamp** — is editable later; an entry is deletable
(with a confirm, deletion being the one irreversible action).

### It's private
My Festival is a **personal** log — not shared, not moderated, no audience. That
removes a whole class of concerns: no sharing controls, no content moderation,
no "are you sure this is public", no edit-history/audit. Edits and deletes are
unconstrained and freely reversible; notes/photos can be anything and stay
device-local. Design for a personal notebook, not a social feed.

### Architectural consequence: entries need a stable identity
Editable timestamps and non-drink entries both **break the current identity
scheme**. Today a tasting *is* its `DateTime`, and deletion matches by timestamp
value (`user_drink_state.dart` normalises to millisecond precision precisely for
that delete-by-match). Once the time is user-editable — and once entries aren't
keyed under a drink at all — the timestamp can't be the key. So every `LogEntry`
carries a **stable `id`** (a generated UUID) assigned once and never changed;
**edit and delete key off `id`.** This also hands sync (Track B) a natural
per-entry key and idempotency handle if the wire contract ever goes per-entry.

---

## Alternatives Considered

### A. Keep the drink-centric model (status quo)
- Simplest; no migration; `rating`/`notes` map 1:1 to the per-drink Review API.
- Rejected because: it can't express the diary — a tasting is a bare timestamp,
  per-pour detail overwrites a single drink-level value, and there is **nowhere
  to put a non-drink event at all**.

### B. Tastings nested inside `UserDrinkState` (the first draft of this ADR)
- Makes tastings rich (per-pour rating/note/photo) while keeping per-drink
  storage.
- Rejected because: it is still drink-keyed, so **non-drink events have no home**
  — requirement (2) rules it out. Nesting under a drink cannot represent "had a
  scotch egg." This is the decisive constraint that pushed the model to a
  festival-scoped timeline.

### C. Check-in / log entry as primary, festival-scoped timeline (**chosen**)
- The diary is first-class and general (drink and non-drink); the plan
  (`wantToTry`) is orthogonal; drink aggregates derive from the timeline.
- Accepted despite a real storage restructure and wire-contract divergence (see
  Consequences), because it is the only model that captures the whole festival
  and resolves the per-pour tension by construction.

---

## Consequences

### Positive
- My Festival becomes a real **diary + plan** for the *whole* festival, not just
  scanned drinks — matching how a festival is actually lived.
- Rating/recommend/note/photo attach to a **moment**, resolving per-pour vs
  per-drink by construction.
- Backfill and edit fall out of the model (editable `when` + timeline "+"),
  needing no special code paths.
- The "Tasted" timeline (#414) and capture flow (#415) sit on a model built for
  them. Auto-revert to want-to-try still falls out of the derived section rule.

### Negative
- **Storage restructure + released-app migration.** Storage moves from
  per-drink `UserDrinkState` blobs to a **festival-scoped entry collection** plus
  a small per-drink `wantToTry` set. That is a `UserDataStore` schema **v1→v2**
  migration over real user data, routed through `UserDataStore.migrate`.
- **Divergence from the wire contract.** The local model is richer than the
  per-drink Review API / `DrinkEntry`; non-drink entries have **no** wire home.
  Per-entry detail is device-local under this ADR; cross-device diary sync needs
  a future proto-first change.
- **Rating aggregation semantics.** "Your rating of this beer" must be a
  derivation over tasting entries (latest? mean?), and the synced/community value
  (`reviewSummaries` assumes one per device per drink) must stay a single
  per-drink number.
- **Identity scheme change.** Entries move from delete-by-timestamp-match to a
  stable `id`; the delete path and millisecond normalisation in the model are
  reworked.
- **#415 must be re-scoped** to build against the check-in entity (drink and
  non-drink, capture + edit + backfill) rather than the drink-level action bar it
  currently specifies.

### Migration approach (open sub-decision)
On upgrade to schema v2, for each existing per-drink `UserDrinkState`:
- its `wantToTry` flag moves to the per-drink intent set;
- each existing tasting timestamp becomes a `LogEntry` (kind `tasting`, that
  `drinkId`, a **freshly generated `id`**, `when` preserved) appended to the
  festival timeline;
- the drink-level `rating`/`notes`/`photoIds`, if any, attach to that drink's
  **most recent** tasting entry — or, if the drink was rated but never tasted,
  synthesise one tasting at `updatedAt` carrying them.

No data is discarded; the choice only affects *where* an existing rating lands.

---

## Implementation (outline — not built by this ADR)

- **Model**: a `LogEntry` value object with a stable `id`, `kind`, optional
  `drinkId`/`title`, and `when`/`rating`/`wouldRecommend`/`note`/`photoIds`.
  Edit/delete key off `id`. Derive drink-level aggregates by filtering the
  timeline.
- **Storage**: `UserDataStore` gains a festival-scoped entry collection +
  per-drink `wantToTry`; `currentSchemaVersion` 1→2 with the migration above.
- **Provider**: expose the timeline and per-drink derived views; keep
  `myFestivalEntries`' timeline shape (#414).
- **UX**: drink-page one-tap tasting fast path; a timeline "+" for
  any-kind/backfilled entries; edit-any-field; confirm-on-delete.
- **Sync**: unchanged — per-drink aggregate only; per-entry + non-drink detail
  stays device-local.

---

## Related Documents

- `docs/planning/my-festival/vision.md` — the multi-phase roadmap (#411–#417)
- `proto/cambeerfestival/festival/v1alpha/drink_entry.proto` — the per-drink
  wire contract this model deliberately diverges from (locally)
- Skills: `architecture-contract` (storage/versioning invariants),
  `api-contract` (wire-contract evolution), `my-festival-campaign`
- Issues: #315 (epic), #411 (mutators, done), #414 (timeline, done), #415
  (detail capture — to be re-scoped), #416 (photos), #417 (would-recommend)

## Open Questions

1. **Kind taxonomy.** Ship `tasting` + `food` + a generic `other`, or a richer
   set? Keep it small and extensible; free-text `title` absorbs the long tail.
2. **Migration of a rating with no tasting**: synthesise a tasting entry, or keep
   a per-drink "overall"? (Recommended: synthesise, to keep one model.)
3. **Derivation rule** for a drink's displayed/synced rating: latest tasting,
   mean, or last non-null? (Community aggregate constrains this to one per drink.)
4. **When, if ever, does the wire contract go per-entry?** (Deferred to a future
   proto-first ADR; not required for the local diary.)
