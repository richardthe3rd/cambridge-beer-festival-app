---
name: proof-and-analysis-toolkit
description: First-principles analysis recipes for the Cambridge Beer Festival app — "prove it, don't just install it." Load before trusting or changing API-field parsing/schema code, before decoding a minified web-release crash, before touching any unawaited() future or shared mutable state, before acting on an automated review comment that looks wrong, before changing staleness/retry/refresh timestamp logic, or before running any experiment (test, curl, jq, coverage check) whose result you haven't predicted in advance. Triggers — "is this field really always a string", "prove this branch is dead code", "decode this crash stack", "audit this for races", "the reviewer says X, is that true", "will this be stale after this change", "what should I expect this command to return". Provides six worked recipes, each with the exact repo incident it comes from, copy-pasteable commands, and what counts as proof (not vibes).
---

# Proof and Analysis Toolkit

Doctrine: a claim about this codebase is not true because it sounds plausible, because
a doc says so, or because a past PR title implies it — it is true because you counted,
decoded, or modeled it yourself and the numbers came out the way your model predicted.
Every recipe below ends in a **number, a matched frame, or a written prediction that
either held or didn't** — never in "should be fine."

Six recipes. Each has: when to use, steps, a worked example from this repo's real
history (issue/PR numbers you can hand to `gh issue view` or grep the CHANGELOG for),
and what counts as proof.

---

## Recipe 1 — Empirical data census

**When to use**: before writing or trusting any `fromJson` branch, before believing a
claim like "field X is always a string," before changing a status/enum mapping, or
before filing a bug that assumes one festival's data shape applies to all festivals.

**Why it matters here**: the live feeds at `data.cambeerfestival.app` are described in
AGENTS.md as having type-union fields (abv, allergens, year_founded, bar) — but a union
described in prose can silently be wrong, incomplete, or stale. The only way to know
what a field actually does is to fetch every festival/category combination and count.

### Steps

1. List the categories to check: `beer, cider, perry, mead, wine, international-beer,
   low-no, apple-juice` (see `lib/models/beverage_categories.dart`), scoped to whichever
   festival(s) matter — check `available_beverage_types` in `data/festivals.json` first,
   since **per-festival unions differ** (a winter festival may omit categories a summer
   one has, or use different vocabulary in free-text fields).
2. Fetch each `{festivalId}/{category}.json` — the shape is `{"producers": [...],
   "timestamp": ...}`, NOT a bare array (verify this before assuming the top-level type;
   see `lib/services/beer_api_service.dart:110-127`, `parseProducers`).
3. Run a `jq group_by(type)` census over every field you're about to parse or change.
4. Compare across at least two festivals from different seasons before concluding a
   union is "always X" — a summer-only sample under-counts winter-only vocabulary (or
   vice versa).
5. State the conclusion as a fraction, never a vibe: **"branch X fires in N/M records"**
   or **"never fires in N/M records — candidate dead code"** or **"genuinely mixed —
   keep the branch."**

### Copy-pasteable recipe (run against the live feed)

```bash
FESTIVAL=cbf2026   # swap in whatever festival you're checking
CATS="beer cider perry mead wine international-beer low-no apple-juice"
DIR=$(mktemp -d)
for c in $CATS; do
  curl -sS --max-time 20 "https://data.cambeerfestival.app/$FESTIVAL/$c.json" -o "$DIR/$c.json"
done

# Runtime type census for one field across every category fetched:
jq -s -r '[.[] | .producers[]?.products[]?.abv] | group_by(.|type)
          | map({type:(.[0]|type), count: length})' "$DIR"/*.json

# Same for allergens VALUES (they are nested under a Map, not a top field):
jq -s -r '[.[] | .producers[]?.products[]?.allergens? // {} | to_entries[].value]
          | group_by(type) | map({type:(.[0]|type), count: length})' "$DIR"/*.json

# Exact-string census for status_text (drives the AvailabilityStatus map,
# lib/models/drink.dart _statusMap, ~line 237):
jq -s -r '[.[] | .producers[]?.products[]?.status_text] | group_by(.)
          | map({status: .[0], count: length}) | sort_by(-.count)' "$DIR"/*.json

# year_founded on producers (int | String | null per Producer.fromJson):
jq -s -r '[.[] | .producers[]?.year_founded] | group_by(.|type)
          | map({type:(.[0]|type), count: length})' "$DIR"/*.json
```

### Worked example (issue #349, backing issue #348 / PR #360)

The #349 census (~900 drinks surveyed) proved there is **no ordinal availability
field** in the feed — only free-text `status_text` — which is why #348's fix
(`lib/models/drink.dart` — exact-match `_statusMap`, `AvailabilityStatus.unknown` for
anything unrecognised) replaced a substring-matching cascade that had been silently
misclassifying **~32% of one festival's statuses** (`'out'` is a substring of `'about'`;
`'low'`/`'about'`/`'below'` collided). The lesson generalises: a substring or "looks
like it should always be true" branch is a liability until a census proves otherwise.

### Fresh re-run, done for this skill (2026-07-02, live `cbf2026` + `cbfw2025` feeds)

Re-running the recipe above today against 695 products across all 8 `cbf2026`
categories, and separately against `cbfw2025` (the winter festival), gave:

| Field | Result | Verdict |
|---|---|---|
| `abv` | 686/695 string, 9/695 null (all in `low-no`/`apple-juice`), **0/695 numeric** | The `num` branch at `lib/models/drink.dart:98-99` never fired in today's live sample — keep it defensively (older festival years may differ; this is a "candidate dead code, re-check before removing" verdict, not a "delete it" verdict) |
| `allergens` values | 359/359 boolean, **0 numeric** | The `int`/`num` branches at `lib/models/drink.dart:116-117,120-121` never fired today — same "keep, don't delete" verdict; `cider`/`perry`/`apple-juice` had zero allergen keys at all this year |
| `bar` | 217/695 string, 478/695 null, **0 boolean/int observed** | The `int` branch at `lib/models/drink.dart:134-135` and the "boolean → null" case (comment at 128-129) didn't fire today — keep, don't delete; the comment implies it fired in some past year's data |
| `year_founded` | 120/303 numeric, 183/303 null, **0 String observed** | Genuinely mixed int/null today — the defensive branch in `Producer.fromJson` (`lib/models/drink.dart:22-30`) is earning its keep; String variant not reproduced live, flag as unverified rather than deleting |
| `status_text` (`cbf2026` beer, 242 records) | `Some beer remaining` 80, `Sold Out` 55, `A little remaining` 44, `Plenty left` 32, null 25, `Nearly finished!` 6 | Matches the 5 known keys in `_statusMap` exactly; **`Arrived` (claimed as a winter-only value in the #348/#349 history) did not appear in either `cbf2026` or the current `cbfw2025` feed** — treat that historical claim as *unverified today*, not false; re-run this census closer to the next winter festival before relying on it |

That last row is itself the point of this recipe: a plausible historical claim
(`Arrived` exists in winter data) did not reproduce on a fresh pull. Don't silently
keep citing it — either re-run the census against a fresher winter snapshot, or mark it
"unconfirmed as of 2026-07-02" wherever it's used.

### What counts as proof

A count with a denominator ("55/242", "0/695"), from a command you actually ran, on
data fetched *today or as fresh as practical* — not a paraphrase of what a past issue
said, and not "most records look like X."

---

## Recipe 2 — Minified-crash forensics

**When to use**: a Flutter web release build crashes — a Crashlytics report, a
Playwright `console.error`, or a CI e2e failure — and the stack trace is minified JS
(`main.dart.js:89998:16`).

**Steps**:

1. Build with source maps and decode **every frame**, not just the top one — the exact
   commands (source-map build flags, the `source-map` npm decode script, the CI-vs-local
   ~4-line dart-define offset) are the mechanics; see skill `diagnostics-and-tooling`
   and AGENTS.md's "Debugging Flutter Web Crashes" section rather than re-deriving them
   here.
2. For any decoded frame that lands inside `flutter/lib/...` (SDK internals, not this
   repo's code), read the actual SDK source under
   `.mise/http-tarballs/<hash>/packages/flutter/lib/src/...` — don't guess what the SDK
   does from memory or a changelog entry.
3. Build **one mechanism that explains every frame**, including frames that look like
   unrelated noise. If your hypothesis only explains the crash frame and hand-waves the
   caller frames, it's not done.
4. Apply the minimal fix at the layer where the invariant was actually violated — not a
   broad catch-and-suppress at the error-reporting layer.
5. Add a regression guard that would have caught the original bug (not just a test of
   the fix in isolation).

### Worked example (issue #386 → PR #408)

Crash: `Null check operator used on a null value` at `navigator.dart:6047`, surfaced by
CI e2e after the Flutter 3.44 upgrade (PR #384) shifted minified line numbers.

Frame-by-frame mechanism (every frame accounted for, verified against
`lib/router.dart:76-90` in the working tree):
- `router.dart`'s `/` route was **redirect-only, with no `builder`**.
- While `BeerProvider` initializes, the redirect callback returns `null` (waiting).
- `go_router` then has nothing to build for `/` and mounts a `Navigator` with an empty
  `pages` list and no `onGenerateRoute`.
- `WidgetsApp` hardcodes `restorationScopeId: 'router'`; Flutter's state-restoration
  path calls `_routeNamed` which does `widget.onGenerateRoute!` — null-checked, and
  null in release builds → crash.

Fix (PR #408, `d9af94d` per the change history): give the `/` route a real `builder`
(`const Scaffold(body: Center(child: CircularProgressIndicator()))`) — the comment at
`lib/router.dart:81-89` documents exactly this mechanism inline so nobody re-derives it
from scratch again.

**Rejected/removed dead end** (do not resurrect): a prior workaround,
`isBenignRestorationError()`, downgraded *every* "Null check operator..." web-release
error to non-fatal by matching on the message string alone — deleted as dangerously
overbroad (it would have masked unrelated real crashes with the same generic message).

**Proper fix NOT taken** (know this before proposing it again): setting
`restorationScopeId: 'go-router'` on `GoRouter` might sidestep the hardcoded scope
entirely, but it changes Android/iOS back-stack restoration behavior and needs manual
device smoke-testing that an agent cannot perform — deliberately deferred, not
forgotten.

### What counts as proof

Every frame in the decoded trace is individually explained by your one mechanism (not
just the top frame), and you can state why routes *without* this pattern (a route with
a real builder) don't crash — a working differential diagnosis, not just a matching
story for the failure case.

---

## Recipe 3 — Async/race audit

**When to use**: before touching any `unawaited(...)` call, any field mutated from more
than one call site, or any bug report that smells like "sometimes X, but only if you're
fast" (flashing, reverting, stale data after a quick action).

**Steps**:

1. Enumerate every `unawaited(...)` future and every future that mutates shared state
   without being awaited by its caller (`grep -n "unawaited(" lib/...`).
2. For each one, answer two questions in writing:
   - **What happens if a second call starts before this one resolves?** (Is there a
     token/guard, or can the older result clobber the newer one?)
   - **What happens if it throws?** (Does the failure propagate somewhere that matters,
     or does it silently poison a shared queue/future chain for the rest of the
     session?)
3. If you can't answer both questions for a given call site in one sentence each, it's
   an **unaudited race** — audit it before shipping a change nearby.

### The two certified fix patterns in this codebase

**A. Serialized, catchError-guarded write chain** — `lib/services/cache_service.dart`
(`DrinkCacheService`). A private `Future<void> _writeChain` field is chained on every
`merge()` call:

```dart
final writeTask = _writeChain.then((_) => _persistTypes(festivalId, types));
_writeChain = writeTask.catchError((_) {});
```

Fixed by issue #309 / PR #419 — concurrent `merge()` calls used to each fire an
unawaited `_persistTypes()` independently, so the *last write to finish* (not the
last-called) won on disk, and a crashed cold start could revert to stale data. The
`.catchError((_) {})` on the **chain variable** (not the caller-observable `writeTask`)
is the second half of the fix: without it, one write failure poisons `_writeChain`
forever and every subsequent `.then()` silently no-ops for the rest of the session.

**B. Monotonic load token** — `lib/providers/beer_provider.dart`. `_drinksLoadToken`
(field at line 86) is incremented at the start of every load
(`loadDrinks()` line 401, `setFestival()` line 447) and checked before applying any
result (lines 406, 451, 480, 495, 519). A load started before a festival switch can
never overwrite the newer festival's data, because its token no longer matches by the
time it resolves. Fixed by issue #266 / PR #275 (originally #263).

### What counts as proof

For every `unawaited(...)` or shared-state-mutating future you touch, you can state in
one sentence each: "on overlap, X happens (guarded/not guarded)" and "on throw, Y
happens (propagates/swallowed/poisons the chain)." If your change adds a new
shared-state mutation, it must use pattern A or B above, not a third ad hoc scheme.

---

## Recipe 4 — Review-comment refutation

**When to use**: an automated reviewer (or anyone) flags something that looks wrong to
you, but "I don't think that's right" isn't good enough to ignore a review comment.

**Steps**:

1. Don't argue from intuition — look up the primary standard: `aip.dev` for
   proto/API-shape comments, the Dart SDK source/docs for language-type comments.
2. Construct a **discriminating check**: if the reviewer's proposed fix were applied,
   would it trip a linter rule (`api-linter`, `buf lint`) or would `flutter analyze` /
   `./bin/mise run test` fail? A negative result (the fix gets rejected by tooling) is
   strong evidence the reviewer is wrong.
3. **If a proposed fix would require suppressing a linter rule, treat that as a strong
   signal the fix itself is wrong** — this is stated directly in AGENTS.md and is the
   load-bearing heuristic of this recipe.
4. Record the verdict as a **reusable, durable fact** — in AGENTS.md's Proto/AIP or
   Dart/Flutter fact lists, or in a relevant skill — not just as a one-off PR reply, so
   the next reviewer (human or automated) doesn't re-raise the same wrong comment.

### Worked example A — AIP-154 etag (AGENTS.md fact)

A reviewer suggested that `etag` being `OUTPUT_ONLY` breaks OpenAPI/REST clients and
proposed adding a duplicate `string etag` field to Update request messages so REST
clients could send it back. Discriminating check: `api-linter` rejects exactly this
change under `0134::request-unknown-fields` and `0154::no-duplicate-etag` — a fix that
requires suppressing two linter rules is the tell. The correct fix per AIP-154 is
documented behavior: proto-native clients echo `resource.etag` in the resource field;
REST/HTTP clients use the standard `If-Match` header — no new request field needed.

### Worked example B — dart:io exception facts (issue #324 / PR #376)

A reviewer's mental model assumed `dart:io` exception types need `.runtimeType`
string-matching (because, e.g., they might not be `const`-constructible, or
`HandshakeException` needs its own branch alongside `TlsException`). Discriminating
check: `flutter analyze` and the test suite pass with `const` constructors on
`SocketException`/`HandshakeException`/`HttpException`/`TlsException`/
`CertificateException`, and `HandshakeException extends TlsException` (so `e is
TlsException` already subsumes it — a separate branch is dead code, not a missing
case). Both facts are now pinned in AGENTS.md's "Dart / Flutter Type Facts" precisely
so nobody re-litigates them from a plausible-sounding review comment.

### What counts as proof

You can name the exact rule ID or SDK fact the proposed fix would violate, and you have
run (or can point to CI having run) the tool that would reject it — not just a
counter-assertion.

---

## Recipe 5 — Staleness/retry semantics analysis

**When to use**: before changing any code that decides "is this data stale," "should we
retry," or "did that refresh count as success" — SWR caches, festival/drinks refresh
timestamps, any timestamp-gated retry logic.

**Steps**:

1. Model the state as a machine with **two separate timestamps**: last-success and
   last-attempt. Conflating them creates either a retry storm (offline user hammers the
   network every foreground) or an offline lockout (a legitimate failure blocks retries
   forever because "last success" never got a chance to update).
2. Explicitly check every `Future.wait([])` or empty-collection code path: an empty
   list resolves **instantly and "successfully"** with no network contact — is that
   really a successful refresh, or a vacuous no-op masquerading as one?
3. Before writing code, build the matrix **(cache: hit/miss) × (network: ok/fail/empty)**
   and write a one-sentence prediction for each of the (typically 6) cells: what the
   user sees, and whether the staleness/retry state updates correctly.
4. Only then implement, and check the shipped behavior against every cell.

### Worked example — contrast #307 vs #308

**#307** (last-attempt vs last-success conflation): `_lastFestivalsRefresh` was only set
on network *success*; a persistently offline user's cache-fallback path never set it,
so `isFestivalsDataStale` stayed `true` forever and `loadFestivals()` re-fired on every
single app resume. Two options were weighed — treat cache-fallback as success (risks
masking real offline-recovery lockout) vs. add a **separate** `_lastFestivalsRefreshAttempt`
rate-limiter. PR #336 shipped the second: last-success and last-attempt are tracked
independently.

**#308** (vacuous empty-success): `Future.wait([])` for a festival with an empty
`availableBeverageTypes` resolves immediately with `isCompleteFailure` false (both
`drinksByType` and `failedTypes` are empty) — the provider used to treat this as a
genuine refresh and stamp `_lastDrinksRefresh = now()`, locking a user on stale/absent
data for up to the 1-hour staleness window with no retry. Fixed in
`lib/providers/beer_provider.dart:486-492` (verified in the working tree):

```dart
if (festival.availableBeverageTypes.isNotEmpty) {
  _lastDrinksRefresh = DateTime.now();
} else {
  _lastDrinksRefresh = null;   // stays stale/retriable — no real work happened
}
```

### The matrix, for `_refreshDrinksFromNetwork` (`beer_provider.dart:476-521`)

| | network OK | network fails | `availableBeverageTypes` empty |
|---|---|---|---|
| **cache hit** | drinks replace cache, `_lastDrinksRefresh = now()`, notice/error cleared | cached drinks stay on screen, dismissible `_refreshNotice` set, `_error` stays null | drinks replace cache (trivially, nothing to fetch), `_lastDrinksRefresh = null` — stays stale/retriable |
| **cache miss** | drinks load, `_lastDrinksRefresh = now()` | `_error` set, drinks cleared to `[]` | drinks set to `[]`, `_lastDrinksRefresh = null` |

Writing this table down (or one like it) before editing `_refreshDrinksFromNetwork` is
the whole recipe — #307 and #308 are both cases where the actual shipped code silently
violated one cell of a matrix like this.

### What counts as proof

You wrote the matrix (or state-machine diagram) down **before** changing the code, and
the shipped behavior matches your written prediction in every cell — ideally with one
test per cell.

---

## Recipe 6 — Hypothesis-predicts-numbers

**When to use**: universally, before running any experiment — a test suite, a curl/jq
census, a coverage check, a source-map decode, a manual repro.

**Steps**:

1. Before running anything, write down the number you expect: how many tests should
   pass/fail, what HTTP status you expect, how many records should hit each branch,
   what the coverage delta should be.
2. Run it.
3. If the actual result **matches** your prediction, that's confirming evidence — say so.
4. If it **doesn't match**, that means your model of the system is wrong. **Stop and
   revise the model — do not just edit the assertion, retry with different flags until
   it passes, or rationalize the surprise away.** A surprising number is the most
   valuable output of the experiment, not an inconvenience to route around.

### Worked example (from Recipe 1's fresh re-run today)

Before running the allergens `jq` census in Recipe 1, the prediction — based on
AGENTS.md's stated variant list ("allergens: `int`/`bool`/`num`") and the parsing code
at `lib/models/drink.dart:116-121` — was "expect a mix of boolean and integer values."
The actual result: **359/359 boolean, 0 numeric**, across every `cbf2026` category
sampled. That's a real mismatch between the documented union and today's live data.
The correct move (and the one taken in this file) is **not** to silently rewrite
AGENTS.md's variant list to "boolean only" — that would overwrite a fact possibly true
in some other year's data — but to flag it explicitly: "0/359 numeric observed live on
2026-07-02; the numeric branch may be historical or festival-specific; re-verify before
relying on it, and definitely before deleting the branch." See skill
`research-methodology` for the longer-lived version of this discipline (planning →
issue → PR → ADR, and when a surprising number is big enough to justify a GitHub
issue).

### What counts as proof

A prediction written down *before* the command ran (not reconstructed afterward to fit
the result), and an explicit statement of match-or-mismatch — a mismatch is treated as
a finding to chase, never quietly absorbed into "close enough."

---

## When NOT to use this skill

- Routine debugging of a known symptom class (festival-switch flash, stuck cache,
  release crash you haven't decoded yet, flaky widget test) → use `debugging-playbook`
  for the symptom→cause→fix triage table first; come back here only once you need to
  *prove* a hypothesis it points you toward.
- The mechanics of running a tool (how to invoke `./bin/mise run test`, how to build
  with `--source-maps`, how to read `TEST_LOG`/`ANALYZE_LOG`, coverage inspection) →
  `diagnostics-and-tooling`.
- Process/lifecycle questions — when an idea needs an ADR, how to close out an
  investigation, where good ideas have historically come from, the evidence bar for
  calling something "the root cause" → `research-methodology`.

---

## Provenance and maintenance

Written 2026-07-02. Verified against, on that date:
- Live HTTP fetch of `https://data.cambeerfestival.app/{cbf2026,cbfw2025}/{beer,cider,
  perry,mead,wine,international-beer,low-no,apple-juice}.json` (Recipe 1's numbers are
  from this exact run, not copied from a prior report).
- Working-tree reads of `lib/models/drink.dart` (abv/allergens/bar/vegan/year_founded
  parsing, `_statusMap`), `lib/services/beer_api_service.dart` (`parseProducers`,
  `isConnectivityFailure`), `lib/services/cache_service.dart` (`_writeChain`/`merge`),
  `lib/providers/beer_provider.dart` (`_drinksLoadToken`, `_refreshDrinksFromNetwork`),
  `lib/router.dart` (the `/` route builder and its inline comment).
- `CHANGELOG.md` for PR-number cross-checks (#365, #366, #375, #376, #380, #382, #360,
  #300, #303, #327, #328, #330, #331, #332, #334, #336, #339, #362 all confirmed
  present with matching one-line descriptions).

Re-verification commands (all read-only):

```bash
# Re-run the live census (numbers WILL drift as festivals/data change year to year):
FESTIVAL=cbf2026; CATS="beer cider perry mead wine international-beer low-no apple-juice"
for c in $CATS; do curl -sS "https://data.cambeerfestival.app/$FESTIVAL/$c.json"; done \
  | jq -s -r '[.[].producers[]?.products[]?.abv] | group_by(.|type) | map({type:(.[0]|type), count:length})'

# Confirm the write-chain / load-token line numbers haven't drifted:
grep -n "_writeChain" lib/services/cache_service.dart
grep -n "_drinksLoadToken" lib/providers/beer_provider.dart

# Confirm the router '/' builder comment still references issue #386:
sed -n '76,90p' lib/router.dart

# Confirm PR/issue numbers against the changelog (shallow clone — no full git history):
grep -n "#386\|#408\|#309\|#419\|#307\|#308\|#336\|#382\|#348\|#349\|#360\|#324\|#376" CHANGELOG.md
```

Unverifiable from this sandbox (flagged, not asserted): exact GitHub issue body text for
#348/#349/#386 (no live GitHub fetch performed for this skill — repo digests and
CHANGELOG one-liners were used instead); the historical claim that `cbfw2025` (or any
past winter festival) ever emitted `status_text: "Arrived"` — not reproduced in today's
live pull, see Recipe 1's table.
