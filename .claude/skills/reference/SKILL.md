---
name: reference
description: Domain-theory knowledge pack for the Cambridge Beer Festival app — what the festival is operationally and why that shapes the code, drink-domain vocabulary (categories, dispense, ABV, allergens, vegan, availability status), the data-feed reality (which API fields are type-unions and why), festival-registry (data/festivals.json) semantics, the API surface map (static feeds vs v1alpha Review API vs paper-only proto CatalogService), and a jargon glossary (AIP, D1, workerd, etag, keyset pagination, CalVer, etc). Load when you need to understand what a domain term MEANS in this codebase — "what is dispense", "what does status_text `arrived` mean", "why is allergens sometimes a bool", "what's the difference between v1alpha and the proto contract", "what does D1/workerd/etag/AIP mean here", "is this field stable year to year" — not when you need to run a task or edit the API contract.
---

# Reference: Domain Theory for the Cambridge Beer Festival App

This is background knowledge, not a runbook. It explains *what things mean* so
you can read code, triage a bug, or read a review comment without having to
reverse-engineer intent from field names. For "how do I run/build/fix this" go
to the sibling skills named throughout and in "When NOT to use" at the end.

## 1. The domain: what the festival actually is

The **Cambridge Beer Festival** is a real-ale festival organised in the
tradition of **CAMRA** (the Campaign for Real Ale) — the app's own festival
descriptions call it "the longest-running CAMRA beer festival in the UK
(since 1974)" (`data/festivals.json`, `cbf2025.description`) and the Play
Store listing points users to "the official Cambridge CAMRA website" for
authoritative festival info (`docs/tooling/play-store.md:90`). **This app
itself is an unaffiliated community app** — "not affiliated with or endorsed
by the Cambridge Beer Festival organizers" (`docs/tooling/play-store.md:88`)
— built and maintained independently of CAMRA.

Two editions exist, both modelled as `Festival` entries in the registry (see
§4):
- **Main festival** (`cbf{year}`) — the big summer event, roughly a week long,
  on Jesus Green, Cambridge (`data/festivals.json`: `cbf2026` runs
  2026-05-18..05-23). Full beverage range: beer, international beer, cider,
  perry, mead, wine, apple juice, low/no-alcohol.
- **Winter festival** (`cbfw{year}`) — a smaller winter edition at the Corn
  Exchange (`cbfw2025`: 2025-12-10..12-13, `available_beverage_types: [beer,
  low-no]` only — a genuinely narrower catalogue, not a data gap).

Three operational facts drive real design decisions in this repo — they are
not incidental:

1. **Burst usage, one week a year.** The app's entire yearly value is
   concentrated into ~6 days. There is no ops capacity during the festival
   (one maintainer, often on-site) — this is *why* the project enforces a
   pre-festival deploy freeze (skill `change-control` §5) and a free-tier-only
   infrastructure rule (same skill §4 Rule 2).
2. **The venue has patchy, mobile-only data.** Confirmed both by the
   maintainer and in writing: `docs/planning/rating-service/design.md:18`
   states the offline design choice ("Optimistic local + background sync")
   is because "Festival venues have patchy signal." Jesus Green and the Corn
   Exchange are marquees/halls with no reliable venue WiFi — attendees are on
   mobile data, often congested (thousands of people, one cell tower). This is
   *the* design-driving constraint behind the whole SWR (stale-while-revalidate,
   see §6 glossary) caching architecture: render cached data instantly, refresh
   in the background, never block the UI on a network round-trip, keep showing
   stale data with a dismissible notice rather than an error screen. See skill
   `architecture-contract` for the mechanism and its historical bug family
   (`#302`, `#306`–`#309`).
3. **Volunteers update availability ad hoc.** `status_text` (see §2) is typed
   in free text by festival volunteers at the bar as casks run low or arrive —
   not from a structured inventory system. That is why the vocabulary is
   inconsistent, why it can change between festivals (the `_statusMap` carries
   an `arrived` entry — historical winter vocabulary per issue #348/#349
   records, not reproduced in the current live feeds), and why the parser
   cannot assume an ordinal/structured field exists (§3).

## 2. Drink domain vocabulary

**Categories** (`lib/models/beverage_categories.dart`, `BeverageCategories`) —
verified in code:

| Constant | Wire value | Notes |
|---|---|---|
| `beer` | `"beer"` | default category when absent |
| `internationalBeer` | `"international-beer"` | app-side name; the *upstream feed* calls this category `"foreign beer"` inside `international-beer.json` — the feed's `category` field and its own filename disagree (`docs/code/api/data-api-reference.md` §Beer vs International Beer) |
| `cider` | `"cider"` | `style` often null; `dispense` typically `"cider tub"` |
| `perry` | `"perry"` | pear cider |
| `mead` | `"mead"` | honey wine; higher ABV (10–17%); `dispense` typically `"bottle"`/`"mead polypin"` |
| `wine` | `"wine"` | |
| `lowNo` | `"low-no"` | low/no-alcohol; ABV typically < 0.5% |
| `appleJuice` | `"apple-juice"` | non-alcoholic; only offered at some festivals |

Categories are **data-driven, not code-driven** — a new category needs no code
change (AGENTS.md). Each festival's registry entry (`available_beverage_types`)
says which categories it fetches; a category not listed there is simply never
requested for that festival.

**Dispense methods** (`Product.dispense`, `lib/models/drink.dart:73`,
defaults to `"cask"` when absent) — how the drink is served, verified against
`docs/code/api/data-api-reference.md` §Dispense Methods:

| Value | Meaning | Typically used for |
|---|---|---|
| `cask` | Traditional cask ale — served by gravity or handpump, no added CO2 | Beer (the CAMRA "real ale" method) |
| `keg` | Standard pressurised keg | Beer |
| `keykeg` | KeyKeg — a bag-in-ball pressurised single-use keg | Beer, low-no |
| `bottle` | Bottled | International beer, mead, wine |
| `cider tub` | Cider-specific serving vessel | Cider, perry |
| `mead polypin` | Mead-specific container | Mead |

Dispense is **free text from the feed, not an enum in this app** — `Product`
stores it as `String dispense`, not a Dart enum. Treat unfamiliar values as
expected, not a parse bug.

**ABV** — `Product.abv`, always parsed to `double`. The feed sends it as
either a numeric type or a numeral string (e.g. `"5.4"`); `Product.fromJson`
(`lib/models/drink.dart:96-104`) handles both, defaulting to `0.0` on anything
else.

**Styles are per-category free text**, not a fixed taxonomy — `Product.style`
is a nullable `String?` (`lib/models/drink.dart:72`). "IPA", "Golden Ale",
"Dry" are all just strings the volunteer/organiser typed; `DrinkFilterService`
derives the *available* styles per category at runtime from whatever values
are actually present that year (see skill `architecture-contract` §2 for
`availableStyles`). Don't assume a fixed style enum exists anywhere.

**Allergens** — `Product.allergens` is a `Map<String, int>` (e.g.
`{"gluten": 1, "sulphites": 1}`). Wire semantics, verified in
`lib/models/drink.dart:106-125`: a present key with value `1` (or `true`
coerced to `1`) means the allergen **is present**; `0`/`false` means absent;
an **absent key** also means "not declared" (no allergen info supplied) —
`Product.isAllergenFree` treats both an empty map and an all-zero map as
allergen-free (`drink.dart:217-218`). The feed's own value spelling varies —
`int` (typical `1`), `bool` (`true`/`false`), or other numeric types — all
three are folded to `int` on parse; non-numeric/non-bool values are silently
dropped as invalid (comment at `drink.dart:106-108`). Common allergens seen in
practice: `gluten`, `sulphites`.

**Vegan flag** — `Product.isVegan`, nullable `bool?`. Two possible JSON keys:
`is_vegan` (current) or legacy `vegan` (fallback, `is_vegan ?? vegan`,
`drink.dart:140`). Accepted spellings: `bool` (`true`/`false`), numeric
(`0`/non-zero), or string (`"true"/"false"/"1"/"0"/"yes"/"no"`, case-insensitive,
`drink.dart:145-154`). `null` means "vegan status not declared" — never treat
absence as "not vegan"; `DrinkVisibilityFilter.veganOnly` explicitly requires
`isVegan == true` (see skill `architecture-contract`), so unset drinks are
excluded from a vegan-only filter, not wrongly included.

**Bar assignments** — `Product.bar`, nullable `String?`, meaning "which bar/
stall serves this drink" (e.g. `"Arctic"`, `"Cider Bar"`). Wire type varies:
`String` (bar name) or `int`/`bool` — a boolean value indicates "present at an
unspecified bar" per API docs, so it is normalised to `null` rather than the
string `"true"` (`drink.dart:128-136`, comment explains the boolean case
explicitly).

**Availability lifecycle and status vocabulary** — `Product.statusText` is the
free-text field volunteers update by hand; `Product.availabilityStatus`
derives an `AvailabilityStatus` enum from it via **exact-match** lookup
(lowercased+trimmed) against `_statusMap` (`lib/models/drink.dart:237-244`,
verified in the working tree):

```dart
const Map<String, AvailabilityStatus> _statusMap = {
  'sold out': AvailabilityStatus.out,
  'nearly finished!': AvailabilityStatus.veryLow,
  'a little remaining': AvailabilityStatus.low,
  'some beer remaining': AvailabilityStatus.good,
  'plenty left': AvailabilityStatus.plenty,
  'arrived': AvailabilityStatus.plenty,
};
```

`AvailabilityStatus` enum: `plenty, good, low, veryLow, out, unknown`. Any
phrase not in the map (including `null`/blank `statusText`, which returns
`null` rather than `unknown` — check `drink.dart:191`) resolves to `unknown`,
and the app shows the **raw statusText** to the user rather than hiding it.

**This vocabulary is NOT stable across festivals** — the `_statusMap` carries
an `arrived` entry (historical winter vocabulary per issue #348/#349 records;
not reproduced in the current live feeds), and there is no
guarantee the exact-match list above is exhaustive or that phrasing won't
change next year. This map was rewritten from a fragile substring-matching
implementation specifically because substring matching mis-bucketed real
phrases (`'out'` ⊂ `'about'`, `'low'` ⊂ `'below'`) — see §3 and skill
`failure-archaeology` §10 for the incident (issues #348/#349, PR #360). If you
add a new exact-match entry, also add a test proving it doesn't collide with
an existing substring-style false-positive.

## 3. The data-feed reality: which fields are unions, and why

The upstream feed (`data.cambridgebeerfestival.com`, proxied at
`data.cambeerfestival.app`) is a set of static JSON files, one per festival
per category, produced by CAMRA's own tooling — **not an API this project
controls**. It is on the Do-Not-Modify / "untouchable upstream" list (skill
`change-control` §4 Rule 4): the app absorbs whatever it emits, defensively,
rather than asking upstream to normalise.

Fields verified in the current parser (`lib/models/drink.dart`) that accept
more than one wire type, and why the union is kept rather than narrowed:

| Field | Union kept | Why |
|---|---|---|
| `abv` | `num` \| numeral `String` | Different festival years/tooling emit ABV as either a JSON number or a quoted string; both are seen in the wild (`docs/code/api/data-api-reference.md` sample shows `"abv": "5.4"`). Narrowing to one type would crash on the other. |
| `allergens.<key>` | `int` \| `bool` \| other `num` | The allergen map's per-entry value spelling varies by producer/tooling that fed the record — folding `bool`→`0/1` and `num`→`toInt()` covers both without guessing which producer used which convention. |
| `year_founded` (Producer) | `int` \| numeral `String` | Same class of drift as ABV — some years' data emits it quoted. |
| `bar` | `String` \| `int` \| `bool` | A boolean specifically means "at an unspecified bar" per API docs — not a malformed string, a genuinely different shape of answer. |
| `is_vegan`/`vegan` | `bool` \| `num` \| `String` (`"yes"/"no"/"true"/"false"/"1"/"0"`) | Newest field (added `docs/code/api/data-api-reference.md` v1.1.0, 2026-05-11); different producers' spreadsheets export it differently, plus a legacy key name (`vegan`) predates the current one (`is_vegan`). |
| `status_text` | free text, no ordinal field | Confirmed by issue #349's field census across the feed: there is **no structured/ordinal availability field anywhere in the data** — `status_text` is the *only* signal, and it's whatever a volunteer typed at the bar. This is why `availabilityStatus` must be an exact-match-with-unknown-fallback over free text rather than parsing a numeric "stock level" (§2). |

Fields the parser does **not** treat as unions — i.e. observed single-typed in
practice, verified by their `fromJson` handling taking exactly one branch:
`id`, `name`, `location`, `notes`, `category` (always a plain lowercased
string), `dispense` (always a plain string), `style` (always string-or-null,
via `.toString()` so no type-branching is needed).

Two further feed realities, both load-bearing for how the app is built:

- **Drink and producer IDs are NOT stable year-to-year.** IDs are content
  hashes (SHA-1 per `docs/code/api/data-api-reference.md` §Producer Object —
  e.g. `"632047e5b2a712a7707f6b28ac722b1e706f1589"`) computed by the upstream
  tooling from that year's record; the same brewery/beer reappearing next year
  gets a *different* ID. Never assume you can join a drink or producer across
  festivals by ID — there is no cross-festival identity, only
  `id + festivalId` uniqueness within one festival (skill
  `architecture-contract` invariant 6). This is also why `MyFestivalEntry`/
  `UserDrinkState` records are keyed per-festival, not globally per-drink.
- **The registry serves only recent festivals; older ones 404.** The static
  feed and the festival registry (`data/festivals.json`) only carry the
  handful of recent festivals actually in rotation (currently cbf2024,
  cbf2025, cbfw2025, cbf2026) — requesting an arbitrary older `festivalId`
  (e.g. `cbf2018`) 404s both at the registry and at the per-category feed.
  `Festival.fromJson` skips malformed/absent entries rather than crashing the
  whole registry parse (issue #273, PR #330).

## 4. Festival registry semantics (`data/festivals.json`)

Root object — validated against `docs/code/api/festival-registry-schema.json`
(draft-07 JSON Schema) via `./bin/mise run validate:festivals`:

```json
{
  "festivals": [ /* array of festival entries, see below */ ],
  "default_festival_id": "cbf2026",
  "version": "1.1.0",
  "last_updated": "2026-05-09T00:00:00Z"
}
```

- **`default_festival_id`** — which festival the app opens to on first launch
  / when no saved selection exists. `FestivalController` falls back to
  `defaultFestival → first → first active` (`festival_controller.dart`, see
  skill `architecture-contract` §2). Currently `cbf2026`.
- **Per-festival `data_base_url`** — relative (`"/cbf2026"`) or absolute. A
  relative value is resolved against the registry's own base URL at parse
  time (`FestivalsResponse.fromJson`, `lib/services/festival_service.dart:33-38`);
  `Festival.getBeverageUrl(type)` then builds `"$dataBaseUrl/$type.json"`.
  This indirection is what lets the worker serve `festivals.json` from one
  place while beverage data is fetched relative to each festival's own base.
- **`is_active`** — marks the current/next festival (exactly one `true` in
  practice today: `cbf2026`). Drives the freeze-window check in skill
  `change-control` §5 and `Festival.isLive()/isUpcoming()` date logic
  (`lib/models/festival.dart:150-181`) — `is_active` and "is the date range
  live right now" are two independent signals; both matter.
- **`hours`** — a `Map<String, String>` keyed by weekday name (`"Monday"`
  etc.), value a free-text time range, sometimes with **two** ranges on one
  day separated by a comma for a lunch closure (e.g.
  `"12:00 - 15:00, 17:00 - 22:00"` on `cbf2026` Wednesday–Friday — the festival
  closes over lunch some days). Not a structured `{open, close}` pair — treat
  as display text, not something to parse into a time range for logic.
- **`available_beverage_types`** — array of the category constants from §2
  that this specific festival fetches. This is the field whose *change*
  between a cached and fresh registry response is the trigger
  `FestivalController.setSource` checks (`_sameBeverageTypes`, unordered
  compare) to decide whether cached drinks need reloading (skill
  `architecture-contract`, `failure-archaeology` #306).

`DefaultFestivals` (`lib/models/festival.dart:262`) is a **separate,
hard-coded fallback list** (cbf2026, cbf2025, cbfw2025, cbf2024) used only
when the network registry is unreachable and there's no cache — it is not the
source of truth and will drift from the live registry; don't treat it as
authoritative for "which festivals exist."

## 5. API surface map

Three genuinely different surfaces answer to "the API" in this repo — they
are at different maturity levels and it's easy to conflate them.

| Surface | Status | Where implemented | What it does |
|---|---|---|---|
| **Static beverage feeds** | Live in production, untouchable upstream data | `data.cambridgebeerfestival.com` (CAMRA's own static files) proxied through `cloudflare-worker/worker.js` at `data.cambeerfestival.app/{festivalId}/{category}.json`; also `/festivals.json` (embedded registry, `no-cache, must-revalidate`) and `/{festivalId}/available_beverage_types.json` (scrapes an upstream Apache directory listing, 1h cache) | The entire catalogue the app renders — Producers→Products, per festival per category (§3). This is what `BeerApiService`/`FestivalService` fetch. |
| **v1alpha Review API** | Live code, deployed worker, **D1 database not yet provisioned** (`wrangler.toml` ships a placeholder `database_id`) | `cloudflare-worker/reviews.ts` + `shared.ts`, routed at `/v1alpha/...` inside the same worker; D1 table `reviews` (`cloudflare-worker/migrations/0001_create_reviews_table.sql`) | Anonymous star-rating + "would recommend" reviews, keyed by `X-Device-Id` header (not signed-in identity yet — `user_id` column reserved for a future sign-in upgrade). GET/PATCH/DELETE one review, list caller's reviews, get/list aggregate summaries per drink. Any unmatched `/v1alpha/*` path 404s — it is never proxied upstream. |
| **proto CatalogService / MyFestivalService** | **Paper contract only** — defines the intended future v1alpha REST surface via `google.api.http` annotations, generates OpenAPI, but has **no server implementation** in the worker (`/v1alpha` routing only wires up `handleReviews`, i.e. the Review API above; `CatalogService`'s `ListFestivals`/`GetFestival`/`ListDrinks` RPCs have no handler) | `proto/cambeerfestival/festival/v1alpha/{catalog_service,my_festival_service,drink_entry,drink_summary,festival,drink,producer}.proto` → `buf generate` → `docs/code/api/openapi/openapi.yaml` (Redoc-published by `api-docs.yml`) | Design-time contract for where the API is headed: a typed, resource-oriented catalogue API (AIP-compliant) and a richer `DrinkEntry`/`MyFestivalService` (favourite/rating/note/pour-count sync with soft-delete tombstones and etag concurrency) intended to eventually replace/extend the anonymous Review API. Full workflow and AIP facts: skill `api-contract`. |

The **static feeds** and the **v1alpha Review API** are the two surfaces that
actually run in production today; the **proto contract** is the target shape
being built toward — don't confuse "it's in the .proto file" with "it's
callable."

## 6. Jargon glossary

Alphabetical; one line each, with a note on how/whether it applies here.

- **AIP** — Google's *API Improvement Proposals*, a public standard for
  resource-oriented API design (naming, pagination, standard methods, etags).
  This project's proto contract follows AIP conventions deliberately (see
  `.proto` file comments citing "AIP-131", "AIP-154" etc). Deep per-rule facts
  live in skill `api-contract`; this skill only says *that* AIPs are the
  standard being followed and why.
- **buf** — the CLI/toolchain for linting, breaking-change detection, and
  code generation over Protocol Buffers (`buf lint`, `buf breaking`, `buf
  generate`). Dev-only mise task here (`mise.dev.toml`); CI runs it via
  `bufbuild/buf-action`, bypassing mise entirely.
- **CalVer** — calendar versioning, this project's scheme:
  `YYYY.M.patch` (month with no leading zero, e.g. `2026.6.0`) for the public
  tag/CHANGELOG version, with `pubspec.yaml`'s `version:` carrying a build
  suffix `+YYYYMMDDPP` (date × 100 + patch, e.g. `2026060500`) for
  Android/store build numbers. Enforced by `cliff.toml`'s strict
  `tag_pattern = "v[0-9]{4}\.[0-9]+\.[0-9]+"`.
- **CORS** — Cross-Origin Resource Sharing; the browser security mechanism
  that would otherwise block the web app (served from `cambeerfestival.app`)
  from fetching `data.cambeerfestival.app`. The Cloudflare Worker exists
  largely *to add CORS headers* to CAMRA's upstream feed, which doesn't send
  any (`cloudflare-worker/worker.js` header comment, top of file).
- **D1** — Cloudflare's managed SQLite-compatible database product; backs the
  v1alpha Review API (`RATINGS_DB` binding, `cloudflare-worker/wrangler.toml`).
  Free-tier-friendly, fitting Rule 2 in skill `change-control`.
- **delta sync** — the general pattern of syncing only *changed* records
  since a last-known point (vs. re-fetching everything). **Candidate/future**
  concept for this project — not implemented today; the current sync design
  (Review API) is whole-collection GET/PATCH, not delta-based. If you see this
  term in a design doc, treat it as aspirational, not shipped.
- **dispense** — the serving method of a drink (`cask`/`keg`/`keykeg`/
  `bottle`/etc). See §2 for the full meaning table.
- **etag** — an opaque version token returned with a resource, echoed back by
  the client to detect "did this change since I last read it" (optimistic
  concurrency). Used by the (not-yet-deployed) `DrinkEntry` resource per
  AIP-154 — see `proto/.../drink_entry.proto` comment on concurrency. Deep
  AIP-154 facts (why it must stay `OUTPUT_ONLY`, how If-Match routes by
  transport) live in skill `api-contract`.
- **goldens** — Flutter's pixel-snapshot regression tests
  (`matchesGoldenFile`). Only 4 exist in this repo, all in `test/goldens/`.
  Update protocol lives in skill `validation-and-qa`.
- **keyset pagination** — a pagination style that encodes "resume after this
  row's key" as the page token (vs. an offset/page-number). This project's
  worker uses it: `cloudflare-worker/shared.ts` encodes "the last drink id" as
  a base64url opaque cursor (AIP-158 style), rather than `?page=3`.
- **mise** — the toolchain/task manager wrapping this whole project (Flutter,
  Dart, Node pinning; `./bin/mise run <task>`). Layering, install traps, and
  the base/dev environment split live in skill `build-and-env`.
- **outbox (pattern)** — a durability pattern for reliably syncing local
  writes to a server (write-then-relay via a persisted queue). **Not
  implemented here** — currently a candidate idea in the "seamless
  offline/online" research space (see skill `research-frontier` if it exists,
  or the my-festival cloud-sync planning docs), not shipped code. Don't assume
  an outbox exists when reading the sync code.
- **SWR (stale-while-revalidate)** — the caching strategy actually shipped:
  render last-known-good data immediately, refresh from network in the
  background, keep the stale data visible (with a dismissible notice) if the
  refresh fails. This is the direct answer to "patchy mobile-only venue data"
  (§1). See `BeerProvider`'s four loading/error signals in skill
  `architecture-contract`.
- **tombstone** — a soft-deleted resource: instead of removing the row, mark
  it deleted (here, by setting `delete_time`) and keep serving it (marked as
  deleted) so other devices/carts can observe the deletion during sync. The
  *design* for `DeleteDrinkEntry` in `my_festival_service.proto` is a
  tombstone (AIP-164 soft delete, returns the resource with `delete_time`
  set) — not yet backed by a live endpoint (§5).
- **workerd** — Cloudflare's open-source JavaScript/Wasm runtime that
  `wrangler dev`/Cloudflare Workers actually execute on; the worker's own
  Vitest suite runs against it via `@cloudflare/vitest-pool-workers`
  (`cloudflare-worker/vitest.config.js`) — genuinely different from the plain
  Node runtime the Pages Functions tests use (mocked `HTMLRewriter`). See
  skill `validation-and-qa` for the distinction.
- **wrangler** — Cloudflare's CLI for developing/deploying Workers, Pages,
  and D1 (`wrangler.toml`, `wrangler deploy`, `wrangler d1 create/migrations
  apply`). Full deploy runbook in skill `run-and-operate`.
- **X-Device-Id** — the HTTP header that stands in for caller identity in the
  anonymous v1alpha Review API (`cloudflare-worker/reviews.ts`/`shared.ts`):
  a non-empty string ≤200 chars, client-generated, no sign-in required. Not
  a Firebase UID (that's a separate, planned upgrade path — see
  `docs/planning/rating-service/design.md`, `user_id` column reserved but
  unused).

## 7. Key external standards, as applied here

- **Google AIPs** — the design standard for the proto contract (resource
  naming, standard methods Get/List/Update/Delete, pagination, etags, batch
  responses). *What* they are and *why* this project follows them: here.
  *Which specific rule facts* to defend against wrong automated-review
  "fixes" (etag OUTPUT_ONLY, soft-delete returns resource not Empty, `type`
  vs `child_type`, batch status arrays, `optional` for signal fields): skill
  `api-contract` (and AGENTS.md "Proto / AIP Design Facts").
- **WCAG 2.1 Level AA** (+ ADA, Section 508) — the accessibility bar every
  interactive element must clear (`Semantics` wrapper with a meaningful
  label, verified in widget tests). Non-optional per AGENTS.md. Concrete
  patterns (filter chips, star ratings, drink cards) and the three semantics-
  testing strategies: skill `ui-and-accessibility`.
- **Conventional Commits** — the commit/PR-title format
  (`type(scope): subject`) that both `pr-lint.yml` enforces and `git-cliff`
  depends on to generate the CHANGELOG. Full gate table: skill
  `change-control`.
- **CalVer `YYYY.M.patch+YYYYMMDDPP`** — see glossary entry above; the full
  release runbook (tagging, workflow chain, Play Store upload) is in skill
  `run-and-operate`.

## When NOT to use this skill

- **Running any task, building, deploying, provisioning D1** → skill
  `run-and-operate` (and `build-and-env` for environment/toolchain setup).
- **Editing the proto contract, AIP compliance details, worker
  implementation patterns for `/v1alpha`** → skill `api-contract` — this
  skill only orients you on *what the surfaces are*, not how to change them.
- **Debugging a specific misbehaviour** → skill `debugging-playbook`
  (symptom → cause → experiment) or `failure-archaeology` (full incident
  history) — this skill has no runbooks.
- **Deciding whether a change is allowed, which CI gates fire, festival
  freeze** → skill `change-control`.
- **Architecture/invariants/code locations for the layers this reference
  describes conceptually** → skill `architecture-contract`.

## Provenance and maintenance

Written 2026-07-02. Verified directly against the working tree at
`/home/user/cambridge-beer-festival-app` (shallow clone): `lib/models/
beverage_categories.dart`, `lib/models/drink.dart` (allergens/vegan/bar/abv/
status-map parsing, all line numbers current as of this date), `data/
festivals.json`, `docs/code/api/festival-registry-schema.json`, `docs/code/
api/data-api-reference.md` (dispense table, category-variation notes, allergen/
vegan wire-type notes), `docs/planning/rating-service/design.md` (patchy-
signal rationale), `docs/tooling/play-store.md` (CAMRA/independence framing),
`cloudflare-worker/worker.js`, `cloudflare-worker/wrangler.toml`,
`cloudflare-worker/migrations/0001_create_reviews_table.sql`,
`proto/cambeerfestival/festival/v1alpha/*.proto`, `proto/buf.yaml`. The §3
"no ordinal availability field" claim and the exact substring-collision
numbers are attributed to issue #349's data census and the #348 fix (PR
#360) per the project's own failure history — the census issue itself was
not re-fetched for this skill; treat the specific field-union list in §3 as
independently verified from code, and the *historical incident framing*
around it as sourced from the project's incident record (skill
`failure-archaeology`).

Re-verification one-liners (run from the repo root):

```bash
# Category constants
cat lib/models/beverage_categories.dart

# Allergen / vegan / bar / ABV union parsing (verify line numbers haven't drifted)
sed -n '95,171p' lib/models/drink.dart

# Availability status exact-match map
sed -n '230,244p' lib/models/drink.dart

# Festival registry: default festival, active flag, beverage types
jq '{default_festival_id, festivals: [.festivals[] | {id, is_active, available_beverage_types}]}' data/festivals.json

# Registry schema
cat docs/code/api/festival-registry-schema.json

# API surface: is CatalogService actually routed in the worker? (expect: no handler, only handleReviews)
grep -n "v1alpha\|handleReviews\|CatalogService" cloudflare-worker/worker.js

# D1 provisioning state (expect: placeholder database_id until provisioned)
grep -n "database_id" cloudflare-worker/wrangler.toml

# Proto promotion path / AIP framing
sed -n '1,40p' proto/buf.yaml

# CalVer tag pattern
grep -n "tag_pattern" cliff.toml
grep -n "^version:" pubspec.yaml

# Patchy-signal design rationale still documented
grep -n "patchy signal" docs/planning/rating-service/design.md
```
