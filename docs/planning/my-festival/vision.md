# "My Festival" — Product Vision

**Status**: 💡 Vision (multi-phase roadmap)
**Last Updated**: May 2026

---

## What Is "My Festival"?

The app currently has one mode: browsing the shared festival catalogue — same for everyone. "My Festival" is a personal layer on top of it: a diary of what you've drunk, a plan for what you want to drink, and over time a record that spans multiple years.

The navigation shifts from a single experience to two distinct destinations:

| Tab | Description |
|-----|-------------|
| **The Festival** | Shared catalogue. Browse, search, filter. Same for everyone. |
| **My Festival** | Personal companion. Plan, log, remember. |

---

## Core Concepts

### Want to Try
A forward-looking todo list. Drinks you intend to taste. When you log a tasting, the drink automatically moves to your log — but both views remain equally easy to navigate.

### Tasting Log
Each time you drink something, a timestamped event is recorded. You can taste the same drink twice (different days or casks) — both events are kept. The log is the source of truth for "what I've had."

### Per-Drink Personal Record *(scoped per festival)*
Attached to a drink, not a single tasting event:

| Field | Type | Notes |
|-------|------|-------|
| `wantToTry` | `bool` | Forward-looking intent flag |
| `tastingEvents` | `List<DateTime>` | One entry per pour/session |
| `rating` | `int?` | 1–5 stars, overall verdict (not per-tasting) |
| `notes` | `String?` | Free text, one set per drink per festival |
| `photos` | `List<PhotoRef>` | One or more images per drink per festival |

Rating, notes, and photos reflect your overall view of the drink — not a specific pour.

### Favourites
Kept as-is in Phase 1 ("bookmarks"). May be retired or merged once "want to try" + rating covers the same ground.

---

## Phase 1 — Local Diary

> Detailed mechanics: [`../festival-log/design.md`](../festival-log/design.md)

Everything stored locally (SharedPreferences). No sign-in required.

**Scope:**
- My Festival tab replaces the current Favourites tab in bottom nav
- Timeline / diary view — tastings in reverse-chronological order, grouped by day
- Want to Try list — add/remove drinks
- Automatic lifecycle: tasting a want-to-try drink moves it to the log
- Notes per drink per festival (text)
- Photos per drink per festival (local device storage)
- Rating unchanged from existing implementation (1–5 integer stars)

**Data model note:** Photo references must use IDs, not absolute file paths — this ensures they can be replaced with cloud URLs in Phase 3 without a migration.

---

## Phase 2 — Cross-Festival Recommendations *(local inference)*

Personal history from previous festivals informs this year's browsing.

**Scope:**
- "From a brewery you rated highly last year" signals on drink cards / detail
- Style preference inference: "you consistently rate IPAs 4–5 stars"
- Fuzzy cross-year matching — drink IDs and names are **not stable** year-to-year, so matching is best-effort:
  1. Exact name + brewery → high confidence
  2. Same brewery + same style → medium confidence
  3. Style-only → low-confidence genre signal

Signals should surface the confidence level explicitly — never present a fuzzy match as a certain recommendation.

---

## Phase 3 — Cloud Sync + Sign-In *(optional)*

Personal data backed up to cloud. Enables cross-device access and persistent cross-festival history.

**Scope:**
- Optional sign-in (provider TBD: Google / Apple / email)
- Sync: want-to-try list, tasting log, notes, photos, ratings
- Previous festival data persisted in cloud → fuels Phase 2 recommendations across devices
- **Local-first**: unauthenticated users get the full Phase 1 experience unchanged. Sync is strictly additive.

---

## Phase 4 — Community & Recommendations

Anonymised aggregate data feeds a recommendation engine.

**Scope:**
- Opt-in anonymous rating sharing
- Aggregate community rating visible on drink cards (displayed alongside personal rating)
- Recommendation engine: personal history + community signal → "you'd probably like this"

---

## Ratings Design

### Individual vs. aggregate types
- Individual ratings: `int` 1–5 (existing star picker)
- Aggregate / community ratings: `double` — averages of integers. The UI must render fractional stars (e.g. 3.7 ★)

### Self-selection bias
Users mostly try things they expect to enjoy, so individual ratings cluster at 3–5 stars — the bottom of the scale is rarely used, making it a poor signal for ranking.

Approaches to consider (exact choice to be decided before Phase 4):

| Approach | Pros | Cons |
|----------|------|------|
| Named scale labels ("not worth finishing / ok / good / really good / exceptional") | Makes lower scores feel less like a judgement; more usable | Requires UI change |
| "Would you order it again?" binary alongside stars | Simple, decisive, less subject to grade inflation | Adds a second input |
| Session ranking (rank your tastings against each other) | Psychologically easier; highly discriminating | Higher friction |
| Bayesian average for community display | Prevents single ratings dominating | Backend complexity |

**Phase 1 action**: Keep integer stars as-is. Explicitly revisit before Phase 4 rollout, when discrimination matters most for the recommendation engine.

---

## Open Questions

- Does "want to try" need a priority order, or is it an unordered set?
- Can you add notes/rating without logging a tasting (e.g. pre-festival research)?
- What happens to "want to try" items at festival end — archive, clear, or keep?
- What is the sign-in provider for Phase 3?

---

## Related Documents

- [`../festival-log/design.md`](../festival-log/design.md) — Phase 1 detailed design (data model, UX interactions, visual design)
- [`../festival-log/implementation-plan.md`](../festival-log/implementation-plan.md) — Phase 1 step-by-step implementation
- [`../rating-service/design.md`](../rating-service/design.md) — Phase 4 online community ratings service (Cloudflare Worker + D1); Phase 1 local ratings are the existing `RatingsService` in `lib/services/storage_service.dart`
- [`../../code/accessibility.md`](../../code/accessibility.md) — Accessibility requirements for all new UI
