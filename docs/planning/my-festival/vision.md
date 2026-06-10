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

Everything stored locally (SharedPreferences). No sign-in required.

**Scope:**
- My Festival tab replaces the current Favourites tab in bottom nav
- Want to Try section — plain list (alphabetical), add/remove drinks
- Tasted section — timeline view, grouped by day, reverse-chronological
- Automatic lifecycle: tasting a want-to-try drink moves it to the Tasted section (but does not clear the want-to-try flag — section membership is derived)
- Notes per drink per festival (text)
- Photos per drink per festival (local device storage) — **separate milestone, does not block the rest of Phase 1**
- Rating unchanged from existing implementation (1–5 integer stars)

**Data model note:** Photo references must use IDs, not absolute file paths — this ensures they can be replaced with cloud URLs in Phase 3 without a migration.

### Visual Design

**Status indicators on drink cards:**
- **Want to Try**: Grey circle outline icon (○)
- **Tasted (once)**: Green checkmark icon (✓)
- **Tasted (multiple)**: Green checkmark + count badge (✓ 3×)

**Design principles:**
- Subtle, clean — badges don't clutter the card
- WCAG AA colour contrast
- 24×24 px minimum touch target
- `Semantics` labels on all badges for screen readers

**Alternatives rejected:**
- Colour-coded card backgrounds — accessibility issues, cluttered
- Opacity fade for tasted items — looks disabled, hard to read

### Interaction Design

**Adding to Want to Try:**
1. Tap bookmark icon on drink card or detail screen
2. Grey circle badge appears; drink added to Want to Try list

**Marking as Tasted:**
1. Open drink detail screen
2. Tap "Mark as Tasted"
3. Timestamp recorded; status changes to green checkmark
4. Drink automatically moves from Want to Try → tasted section

**Multiple tastings:**
1. Tap "Mark as Tasted" again on a subsequent day
2. New timestamp appended to the list
3. Badge shows count (e.g. "3×")
4. Detail screen shows all tasting timestamps

**Deleting a timestamp (v1):**
- Delete only, no editing
- Confirmation dialog before deletion
- If all timestamps deleted → drink reverts to Want to Try

**Timestamp editing (v2, deferred):**
- Edit + delete freely based on user feedback

### My Festival Screen — Layout

Two sections in a single scrollable screen, separated by a clear visual divider. Both sections equally reachable — neither is buried.

**Want to Try** (top): plain alphabetical list of drinks the user has bookmarked. Tapping navigates to the drink detail screen.

**Tasted** (bottom): timeline view, grouped by calendar day, reverse-chronological (most recent day first; within a day, most recently recorded first). Each row shows drink name, brewery, tasting count, and most recent tasting time. Tapping navigates to the drink detail screen.

Empty state when no drinks added: friendly prompt to browse and add.

**Section-membership rule:** derived from `UserDrinkState`, never stored:
- A drink appears in **Tasted** when `tastingEvents.isNotEmpty`.
- A drink appears in **Want to Try** when `wantToTry == true AND tastingEvents.isEmpty`.
- A drink can be in *both* states internally (tasted but still want-to-try flagged), but the Tasted section takes priority in the display.
- Deleting all tasting events for a drink that still has `wantToTry == true` moves it back to Want to Try automatically.

### Analytics Events

| Event | Trigger |
|-------|---------|
| `festival_log_viewed` | Opened My Festival screen |
| `festival_log_add_to_try` | Added drink to Want to Try |
| `festival_log_mark_tasted` | Marked drink as tasted |
| `festival_log_multiple_tasting` | Marked same drink tasted again |
| `festival_log_delete_timestamp` | Deleted a tasting timestamp |

### Pre-Release Note

No migration needed. There are no existing users with saved data. Implement the optimal storage format directly — skip all migration code and tests.

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

See [`../rating-service/design.md`](../rating-service/design.md) for the backend architecture (Cloudflare Worker + D1).

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

- Implementation is tracked on GitHub: feature issue [#315](https://github.com/richardthe3rd/cambridge-beer-festival-app/issues/315) and the data-layer enablers [#390](https://github.com/richardthe3rd/cambridge-beer-festival-app/issues/390)–[#393](https://github.com/richardthe3rd/cambridge-beer-festival-app/issues/393)
- [`../rating-service/design.md`](../rating-service/design.md) — Phase 4 online community ratings service
- [`../../code/accessibility.md`](../../code/accessibility.md) — Accessibility requirements for all new UI
