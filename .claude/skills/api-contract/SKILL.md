---
name: api-contract
description: Proto-first API contract workflow for the Cambridge Beer Festival app — load before editing anything under proto/, before touching cloudflare-worker/reviews.ts or shared.ts, before acting on an automated review comment about the API design (etag/soft-delete/batch/optional/resource-parent annotations), before running any proto:* mise task, or when asked "how do I add a field to the API", "is this AIP fix correct", "what does the worker actually implement vs the proto contract", "why did buf fail to install", or "how do I regenerate the OpenAPI spec". Covers the buf/api-linter toolchain and exact command order, the AIP known-facts table for resisting wrong reviewer suggestions, existing lint suppressions and why, the CatalogService/MyFestivalService resource model, the deployed /v1alpha Review API surface and its honest gap versus the DrinkEntry proto contract, and the rules for evolving the contract without breaking it.
---

# API contract (proto-first)

The whole API surface — `CatalogService` (read-only festival/drink catalogue)
and `MyFestivalService` (personal state + aggregates) — is defined once as
Protocol Buffers in `proto/cambeerfestival/festival/v1alpha/*.proto`. **The
proto is the source of truth.** There is no gRPC server: `google.api.http`
annotations on each RPC define its REST route, and an OpenAPI v3 document
(`docs/code/api/openapi/openapi.yaml`, gitignored — always generated, never
committed) is derived from the proto for the hand-written Cloudflare Worker
and any HTTP client. That OpenAPI doc is published as a Redoc site to GitHub
Pages on every push to `main` (`.github/workflows/api-docs.yml`); PRs get it
attached as a downloadable artifact instead.

If you need the plain-English meaning of a term used below (AIP, D1,
workerd, etag, keyset pagination, CalVer, ...), see skill `reference` — this
skill assumes you already know what they mean and focuses on what this repo
specifically does with them.

## 1. Doctrine, in one paragraph

Design the resource in proto first (message + service + `google.api.http`
binding), never in the Worker. `docs/code/api/openapi/openapi.yaml` and
`cloudflare-worker/src/api-types.ts` are **generated artifacts** — both are
gitignored (`proto/docs/code/api/.gitignore` has `openapi/`;
`cloudflare-worker/.gitignore` has `src/`). Never hand-edit either; if a type
looks wrong, fix the `.proto` and regenerate. The same applies to
`packages/myfestival_client` (gitignored at the repo root, `packages/`) —
the generated Dart/Dio sync client for Flutter.

## 2. Edit workflow — exact commands

Run in this order after any `.proto` change (all dev-only tasks, so prefix
`MISE_ENV=dev` off Claude Code Web; on Claude Code Web the `.miserc.toml`
auto-env already includes `dev`, so plain `./bin/mise` works there):

```bash
MISE_ENV=dev ./bin/mise run proto:format      # buf format -w — formats .proto in place
MISE_ENV=dev ./bin/mise run proto:lint        # buf lint — STANDARD ruleset (minus 2 exceptions, see §4)
MISE_ENV=dev ./bin/mise run proto:api-lint    # AIP design-guideline linter (googleapis/api-linter)
MISE_ENV=dev ./bin/mise run proto:generate    # buf generate -> docs/code/api/openapi/openapi.yaml
```

Then regenerate whichever client(s) the change affects:

```bash
MISE_ENV=dev ./bin/mise run proto:clients:types   # -> cloudflare-worker/src/api-types.ts (openapi-typescript)
MISE_ENV=dev ./bin/mise run proto:clients:dart    # -> packages/myfestival_client (dart-dio; needs Java, downloads a jar)
MISE_ENV=dev ./bin/mise run proto:clients         # both, via `depends`
```

`proto:api-lint` under the hood runs `buf build -o /tmp/cambeerfestival.pb`
then invokes `api-linter --config .api-linter.yaml --descriptor-set-in=...`
against the seven `.proto` files explicitly listed in `mise.dev.toml` — if
you add a new `.proto` file, add it to that list or it silently skips
linting.

`proto:dep-update` (`buf dep update`) refreshes `buf.lock` after editing the
`deps:` list in `buf.yaml` (currently one dependency: `buf.build/googleapis/googleapis`).

### What CI actually checks

Two independent workflows, both triggered by `proto/**` changes:

| Workflow | Job | What it does | Notes |
|---|---|---|---|
| `ci.yml` | `proto` | `bufbuild/buf-action@v1`: lint + `breaking_against` `main:proto` | Installs buf itself via the action — **bypasses mise entirely**. Gated by `dorny/paths-filter` (`proto/**`) or `workflow_dispatch`. |
| `api-docs.yml` | `build-api-docs` → `deploy-api-docs` | `buf generate` → assembles a Redoc site → uploads Pages artifact; deploys only on `main` | On PRs, uploads `openapi.yaml` as a plain build artifact instead of deploying. |

Since proto tasks are dev-only (`mise.dev.toml`, not the base `mise.toml`),
they are intentionally **not** part of the base `check` gate — the comment
in `mise.dev.toml` says to move them into CI/base once the API design
stabilises.

### Sandbox 403 trap (verified 2026-07-02, Claude Code Web)

`buf`, `watchexec`, and `github:googleapis/api-linter` are all installed via
GitHub release downloads (aqua backend). In this sandbox the outbound proxy
returned `403 Forbidden` for all three when tested live:

```
mise ERROR Failed to install tools: aqua:bufbuild/buf@latest, aqua:watchexec/watchexec@2.5.1, github:googleapis/api-linter@latest
aqua:bufbuild/buf@latest: HTTP status client error (403 Forbidden) ...
```

Unlike base tasks (`test`, `analyze`), there is **no `MISE_ENV=claude-code-web`
fallback for dev-only proto tasks** — the 403 is on the GitHub release
download itself, not something an env layer can route around. If you can't
install buf locally, you cannot run `proto:lint`/`proto:api-lint`/`proto:generate`
in this sandbox at all. In that situation: make the `.proto` edit carefully
against the AIP facts below, push, and let `ci.yml`'s `proto` job (which
installs buf via `buf-action`, a different code path than mise) be the first
real verification. Don't claim "lint passed" if you couldn't run it — say so
in the PR description.

## 3. AIP known facts — verify before acting on ANY automated review comment

**If a proposed fix requires suppressing an api-linter rule, treat that as a
strong signal the fix is wrong — look up the AIP first.** This is the
**canonical** AIP fact table (AGENTS.md's "Review-Comment Defence Facts"
section points here); each row adds the concrete evidence in this repo's own
contract so you can check a claim against real code instead of memory.

| AIP | Fact | Evidence in this repo |
|---|---|---|
| **154 (etag)** | `etag` is `OUTPUT_ONLY` on the resource. Do **not** add a duplicate `string etag` request field to satisfy REST clients — proto-native clients echo `resource.etag` back in the resource field of an Update request; REST/HTTP clients send `If-Match`. A reviewer citing "OpenAPI clients need an etag field" is wrong; the fix is documenting `If-Match`, not a request field. | `drink_entry.proto:54` (`OUTPUT_ONLY`); `UpdateDrinkEntryRequest` (`my_festival_service.proto:134-149`) carries `drink_entry` + `update_mask` + `allow_missing` — no duplicate etag field. `DeleteDrinkEntryRequest.etag` (line 165) is legitimate: Delete has no resource-typed field to embed it in, so it's a genuine request-level If-Match token, not a duplicate. |
| **164 (soft delete)** | A soft-delete `Delete` (sets `delete_time` instead of removing the row) must return the resource, not `google.protobuf.Empty`, so the caller gets the tombstone's `delete_time`/new `etag` in one round trip. | `DeleteDrinkEntry` returns `(DrinkEntry)` (`my_festival_service.proto:79`), documented as setting `delete_time` and advancing `update_time`. |
| **132 (List parent annotation)** | Use `type = "..."` (not `child_type`) on a List's `parent` field when the List is scoped at a **grandparent**, not the resource's immediate parent. `child_type` means "this field holds the immediate parent of the listed type." | `ListDrinkEntriesRequest.parent` correctly uses `type = "api.cambeerfestival.app/Festival"` (`my_festival_service.proto:171-174`) — `DrinkEntry`'s pattern (`festivals/{f}/drinks/{d}/entry`) makes its *immediate* parent `Drink`, but the List is festival-scoped (grandparent), so `type` not `child_type` is correct. Contrast with `ListDrinksRequest.parent` in `catalog_service.proto:122-125`, which correctly uses `child_type = ".../Drink"` because `Festival` really is `Drink`'s immediate parent there. |
| **235 (batch responses)** | `BatchUpdateXxx` responses need a parallel `repeated google.rpc.Status statuses` field (same length as the request list) so callers can identify per-item failures. A response with only `repeated Resource items` can't represent partial failure. | `BatchUpdateDrinkEntriesResponse` (`my_festival_service.proto:222-231`) has both `repeated DrinkEntry drink_entries` and `repeated google.rpc.Status statuses`, documented as "always the same length as requests." |
| **`optional` keyword** | Signal fields where "caller hasn't set this" must be distinguishable from an explicit zero/false use `optional T`. Fields where the zero value is meaningful on its own (e.g. a free-text field where `""` = "no note") don't need it, but document the zero-value semantics explicitly. | `is_favourite`, `star_rating`, `would_recommend`, `pours` are all `optional` (`drink_entry.proto:58,61,64,74`). `note` (line 69) is a plain `string`, explicitly documented: "Empty string means no note; to clear an existing note, send `note=""` with `note` in `update_mask`." This is the documented exception, not an oversight. |

## 4. Existing suppressions — read the comments before adding more

`proto/.api-linter.yaml` disables exactly three rule families, each justified
inline:

| Suppressed rule | Why |
|---|---|
| `core::0191::java-package`, `-java-multiple-files`, `-java-outer-classname` | Not building Java clients; Java file options are irrelevant. |
| `core::0156::forbidden-methods` | `DrinkEntry` is a singleton that exposes `Delete` — normally forbidden for singletons, but a personal entry is *absent* until the caller writes one (not an always-present singleton); AIP-156's "absent singletons" carve-out applies. |
| `core::0123::resource-pattern-singular` | `DrinkSummary` uses `{drink}` as the final URL segment (not `{drink_summary}`) so `.../drinkSummaries/{drinkId}` reads as a natural lookup key. |

`proto/buf.yaml`'s `lint.except` disables `RPC_RESPONSE_STANDARD_NAME` and
`RPC_REQUEST_RESPONSE_UNIQUE`, with a comment explaining that Get/Update
return the resource itself (not a `GetXResponse` wrapper) and citing "Delete
returns `google.protobuf.Empty`" as the general AIP rationale. **That last
clause doesn't describe this repo's actual contract** — verified: no RPC in
any `.proto` file here returns `google.protobuf.Empty` (`DeleteDrinkEntry`
returns `DrinkEntry`, per AIP-164 above); `grep -rn protobuf/empty proto/`
only turns up the `breaking.ignore` entry, which is precautionary, not in
use. The comment is generic boilerplate carried over from the standard
AIP justification, not a claim about a specific RPC — don't be confused if
you go looking for the Empty-returning method.

`buf.yaml`'s `breaking` config uses `FILE + WIRE` with
`ignore_unstable_packages: true` (alpha packages can churn freely) and
`ignore: [google/protobuf/empty.proto]`. The promotion path (documented
inline in `buf.yaml` and in `proto/README.md`'s "Independent maturity"
section) is granular **down to the individual RPC**, not the whole package:
the catalogue graduates to `cambeerfestival.festival.v1` first (catalogue
only), while `v1alpha` keeps a copy of the stable catalogue plus whatever of
`MyFestivalService` is still in flux. When the first `v1` package lands,
switch `breaking.use` to `WIRE_JSON_COMPATIBLE` (superset of `WIRE`, also
checks JSON field-name stability) — only `v1` and later are guarded;
`v1alpha` stays exempt.

## 5. Resource model

Two services share one resource hierarchy, mirroring the app's two
destinations ("The Festival" / "My Festival"):

| Service | Resources | Status |
|---|---|---|
| `CatalogService` | `Festival` (`festivals/{f}`), `Producer` (`festivals/{f}/producers/{p}`), `Drink` (`festivals/{f}/drinks/{d}`) — all read-only, every data field `OUTPUT_ONLY` | **Contract-only.** No server implements it; the app still fetches the static JSON feeds directly via `BeerApiService`. Whether to ever build a real backing service is an explicitly open, low-priority decision — GitHub issue #432 lists the trigger conditions (server-side search/filter across festivals, a single denormalised "grid in one round-trip" call combining catalogue+DrinkSummary+DrinkEntry, or a partner-facing surface). Until one of those becomes true, "the documented REST binding can be served by the existing static feeds (or a thin reshaping Worker)" — issue #432's own words. |
| `MyFestivalService` | `DrinkEntry` (singleton, `festivals/{f}/drinks/{d}/entry`), `DrinkSummary` (read-only aggregate, `festivals/{f}/drinkSummaries/{d}`) | **Contract exists; a narrower slice is deployed** — see §6. |

`DrinkEntry` consolidates what were four separate singletons (Bookmark,
Note, Tasting, Review) into one resource: `is_favourite`, `star_rating`,
`would_recommend`, `note`, `pours`, plus `etag`/`create_time`/`update_time`/
`delete_time`. Hydrating "my festival state on app open" costs one
`ListDrinkEntries` call instead of four. **The caller's identity (device ID,
eventually a signed-in user ID) is resolved from the auth context and never
appears in the resource name** (`festivals/{f}/drinks/{d}/entry` — no device
segment) — this keeps device IDs private and means a future sign-in upgrade
doesn't change any client-visible resource name.

**Pour-increment pattern** (read-modify-write guarded by etag, avoiding a
bespoke `:addPour` method):
1. `GetDrinkEntry` → read `pours` and `etag`.
2. Set `drink_entry.pours = current + 1`, `drink_entry.etag = etag`.
3. `UpdateDrinkEntry` with `update_mask = ["pours"]`.
4. On `ABORTED` (stale etag — someone else wrote first), go to step 1 and retry.

## 6. The implemented slice — honest status

**The proto contract (`DrinkEntry`/`DrinkSummary`) and the deployed worker
(`cloudflare-worker/reviews.ts`) are not the same surface.** The worker
implements an older, narrower resource pair called `Review`/`ReviewSummary` —
only `starRating` + `wouldRecommend`, no `etag`/optimistic concurrency, no
`is_favourite`/`note`/`pours`, no soft delete (its `DELETE` does a real SQL
`DELETE FROM reviews` and returns `{}`), no `BatchUpdate`. This predates the
`DrinkEntry` consolidation (PR #429) and has not been reconciled since.
Concretely verified in this sandbox (2026-07-02): `reviews.ts` does
`import type { components } from "./src/api-types"` and pulls out
`Review`/`ReviewSummary`/`ListReviewsResponse`/`ListReviewSummariesResponse`
— but no `.proto` file defines any message named `Review` or `ReviewSummary`
anywhere (`grep -rn "message Review" proto/` finds nothing). `src/api-types.ts`
is gitignored and wasn't present in this checkout; running
`npx tsc --noEmit` in `cloudflare-worker/` failed immediately with
`Cannot find module './src/api-types'`, while `npm test` (vitest) passed all
86 tests unmodified — because `import type` is erased by esbuild/vite at
transpile time and only matters to `tsc`. **CI's `cloudflare-worker.yml`
`test-worker` job runs only `npm test`, not `npm run typecheck`**, so this
gap has never blocked a merge or deploy; the base mise task `test:worker`
(`npm ci && npm run typecheck && npm test`) *would* fail on a fresh checkout
until `MISE_ENV=dev ./bin/mise run proto:clients:types` has been run at least
once to produce `src/api-types.ts` — and even then, regenerating from the
current proto would almost certainly rename or drop the `Review`/
`ReviewSummary` types entirely (they don't exist in the contract), which
`reviews.ts` would then fail to import. Don't assume `npm test` passing means
the worker matches the proto — it only means the worker's own hand-written
logic is internally consistent.

### Deployed `/v1alpha` Review API (`reviews.ts`)

| Method | Path | Purpose |
|---|---|---|
| GET | `/v1alpha/festivals/{f}/drinks/{d}/review` | Caller's review |
| PATCH | same | Upsert (`starRating` 1–5, `wouldRecommend` bool; optional `updateMask`) |
| DELETE | same | Hard-remove (404 if absent) |
| GET | `/v1alpha/festivals/{f}/reviews` | List caller's reviews (paginated) |
| GET | `/v1alpha/festivals/{f}/reviewSummaries/{d}` | Aggregate for one drink |
| GET | `/v1alpha/festivals/{f}/reviewSummaries` | Paginated aggregates (+`totalSize`) |

Other implementation details worth knowing:

- **Identity**: `X-Device-Id` request header, validated non-empty and ≤200
  chars (`reviews.ts:94-119`, `MAX_ID_LENGTH = 200`). Missing/invalid → `400
  INVALID_ARGUMENT` / `MISSING_DEVICE_ID`.
- **Bucket resolution** (`shared.ts:19-28`): `resolveBucket(origin, env)` —
  an explicit `env.RATINGS_BUCKET` wins if set; otherwise origin
  `https://cambeerfestival.app` → `"prod"`, everything else → `"test"`. This
  keeps local/staging/PR-preview traffic out of production aggregates by
  default.
- **AIP-193 error shape** (`shared.ts:66-85`): every error is
  `{ error: { code, message, status, details: [{ "@type": ".../ErrorInfo", reason, domain: "cambeerfestival.app", metadata? }] } }`
  — a `google.rpc.Status`-shaped body with one `ErrorInfo` detail.
- **AIP-158 page tokens** (`shared.ts:87-119`): opaque keyset cursor = the
  last `drink_id` on the page, URL-safe-base64-encoded
  (`encodePageToken`/`decodePageToken`). Default page size 100, max 1000
  (`resolvePageSize`); size `0` or absent means default, not "unlimited."
- **D1 schema** (`migrations/0001_create_reviews_table.sql`): single
  `reviews` table, primary key `(bucket, festival_id, drink_id, device_id)` —
  this gives upsert semantics for free (re-reviewing the same drink never
  inflates aggregate counts). `star_rating` has `CHECK (... BETWEEN 1 AND
  5)`, `recommend` has `CHECK (... IN (0, 1))`. `user_id` column exists but
  stays `NULL` — reserved for a future sign-in upgrade.
- **`STORAGE_UNCONFIGURED` 503**: if `env.RATINGS_DB` is unbound,
  `handleReviews` returns `503 UNAVAILABLE`/`STORAGE_UNCONFIGURED` before
  touching D1 (`reviews.ts:158-166`). This is also the state of the *real*
  production database today: `wrangler.toml:26` has a placeholder
  `database_id = "00000000-0000-0000-0000-000000000000"` — D1 has not been
  provisioned. Tests and `wrangler dev` use a simulated local D1 via
  `@cloudflare/vitest-pool-workers`, so the whole test suite runs green
  without a real database. Provisioning is out of scope for this skill — see
  `run-and-operate` for the `wrangler d1 create` runbook, or
  `my-festival-campaign` for how it fits the larger My Festival rollout.

## 7. Rules for evolving the contract

- **Additive only within `v1alpha`.** New fields, new RPCs, new resources —
  fine. `ignore_unstable_packages: true` means buf's breaking-change check
  doesn't even gate `v1alpha`, but don't rely on that as permission to be
  careless: clients (the future Flutter sync client, this worker) still
  break if you rename or retype a field they read.
- **The `WIRE` breaking gate is real once a package is stable.** When
  `cambeerfestival.festival.v1` exists, field-number reuse or type changes
  in it fail CI (`ci.yml`'s `proto` job, `breaking_against: main`). Never
  renumber or retype a field in a stable package; add a new field instead.
- **Never hand-edit generated files.** `docs/code/api/openapi/openapi.yaml`,
  `cloudflare-worker/src/api-types.ts`, `packages/myfestival_client/**` are
  all regenerated from proto — a manual edit is silently discarded (or
  worse, diverges) the next time someone runs `proto:generate`/
  `proto:clients:*`. Fix the `.proto`, regenerate.
- **Freshness/polling model, not item-level delta, for the catalogue.**
  `Drink.update_time`/`Producer.update_time` are per-category (the feed file
  is the unit of change — all drinks in one category share one value);
  `Festival.update_time` is registry-wide. The intended polling pattern is
  conditional re-fetch (`If-None-Match`/`If-Modified-Since` → `304` on no
  change), not `update_time > T` filtering — the feeds are whole-file
  snapshots, so the server genuinely cannot attribute a change to one drink.
  `ListDrinkEntriesRequest.filter` (`update_time > "..."`) is different: that
  *is* real item-level delta sync, but it's on personal `DrinkEntry` state,
  which the D1-backed service can attribute per-row — don't confuse the two
  freshness models or propose delta-filtering the catalogue.

## When NOT to use this skill

- **Flutter-side sync client work** (consuming this API from the app,
  building the offline-first sync engine, `packages/myfestival_client`
  integration) → skill `my-festival-campaign`.
- **Whether a given proto/worker change is even allowed, what CI gate it
  triggers, or how to react to an automated review comment in general**
  (not specifically an AIP claim) → skill `change-control`.
- **What AIP/D1/workerd/etag/etc. actually mean, or what the static-feed vs
  v1alpha-API surface looks like from the domain side** → skill `reference`.
- **Provisioning the real D1 database, deploying the worker, or the release
  train** → skill `run-and-operate`.
- **General architecture questions about the Flutter app** (not the API
  contract) → skill `architecture-contract`.

## Provenance and maintenance

Written 2026-07-02. Verified against: `proto/README.md`, `proto/buf.yaml`,
`proto/buf.gen.yaml`, `proto/.api-linter.yaml`, all seven `.proto` files in
`proto/cambeerfestival/festival/v1alpha/`, `cloudflare-worker/reviews.ts`,
`cloudflare-worker/shared.ts`, `cloudflare-worker/worker.js`,
`cloudflare-worker/wrangler.toml`, `cloudflare-worker/migrations/0001_create_reviews_table.sql`,
`cloudflare-worker/package.json`, `cloudflare-worker/tsconfig.json`,
`mise.dev.toml` (proto tasks), `mise.toml` (`test:worker` task),
`.github/workflows/ci.yml` (`proto` job), `.github/workflows/api-docs.yml`,
`.github/workflows/cloudflare-worker.yml` (`test-worker` job), and GitHub
issue #432 (fetched live via the GitHub MCP `issue_read` tool). The `buf`
403 and the `tsc`/`npm test` divergence over `src/api-types.ts` were
reproduced live in this sandbox, not inferred.

Re-verification commands:

```bash
# AIP facts still match the contract (line numbers may drift; the fact shouldn't):
grep -n "field_behavior) = OUTPUT_ONLY" proto/cambeerfestival/festival/v1alpha/drink_entry.proto
grep -n "returns (DrinkEntry)" proto/cambeerfestival/festival/v1alpha/my_festival_service.proto
grep -n "child_type\|resource_reference).type" proto/cambeerfestival/festival/v1alpha/my_festival_service.proto proto/cambeerfestival/festival/v1alpha/catalog_service.proto
grep -n "repeated google.rpc.Status" proto/cambeerfestival/festival/v1alpha/my_festival_service.proto

# Suppressions still read the same:
cat proto/.api-linter.yaml proto/buf.yaml

# Confirm no Review/ReviewSummary message exists yet in the proto (the drift this skill flags):
grep -rn "^message Review" proto/

# Confirm the api-types.ts / typecheck gap is still real (needs `cd cloudflare-worker && npm ci` first):
ls cloudflare-worker/src/api-types.ts 2>&1   # expect: No such file (until proto:clients:types has run)
(cd cloudflare-worker && npx tsc --noEmit)   # expect: fails on missing ./src/api-types if not yet generated
(cd cloudflare-worker && npm test)           # expect: passes regardless (86 tests, 5 files as of writing)

# CI job wiring still matches (job names, triggers):
grep -n "proto:" -A 15 .github/workflows/ci.yml | head -25
grep -n "npm test\|npm run typecheck" .github/workflows/cloudflare-worker.yml

# GitHub issue #432 still reflects the "no server yet" decision (needs network/gh auth):
# gh issue view 432 --repo richardthe3rd/cambridge-beer-festival-app
```
