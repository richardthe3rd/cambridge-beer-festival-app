# API contract (proto-first)

📖 **[Browse the rendered API reference](https://richardthe3rd.github.io/cambridge-beer-festival-app/)** — a ReDoc site generated from these protos and deployed to GitHub Pages on every push to `main` (see [`.github/workflows/api-docs.yml`](../.github/workflows/api-docs.yml)). On pull requests the generated `openapi.yaml` is attached as a build artifact for review.

All of the app's API surface lives in a single package,
`cambeerfestival.festival.v1alpha`, defined here as Protocol Buffers following
[Google's API Improvement Proposals](https://google.aip.dev) (AIP), the proto
being the source of truth. An OpenAPI v3 document is generated from it for the
(hand-written) Cloudflare Worker implementation and any HTTP clients.

It exposes two services over the same resource hierarchy, mirroring the app's
two destinations:

| Service | Purpose |
| --- | --- |
| `CatalogService` ("The Festival") | Read-only shared catalogue: festivals and the drinks at each. Same for everyone. |
| `MyFestivalService` ("My Festival") | Caller-scoped personal state (`DrinkEntry`) and public aggregates (`DrinkSummary`). |

The two pair by design: `CatalogService` defines the canonical `Festival` and
`Drink` resources, and the personal/aggregate resources hang off the same names
(`festivals/{f}/drinks/{d}/entry`, `festivals/{f}/drinkSummaries/{d}`). The
catalogue is reshaped from the static JSON data feeds (`Festival.data_base_uri`)
into one versioned, documented, partner-consumable resource model — without
changing the feed format. Lists return the full (small, bounded) set; clients
filter and sort the cached result themselves, so there is no server-side
`filter`/`order_by`.

The transport is plain HTTP/JSON — the `google.api.http` annotations map each
RPC to a REST route. We do **not** run a gRPC server; the proto is the contract
and OpenAPI is the generated artifact.

### Independent maturity within one namespace

Keeping both services in one package does **not** couple their stability. The
version segment is the unit of promotion (the version *is* the package), and the
stable package contains only what is ready — so promotion is granular all the
way down to the individual RPC. Services, and individual methods within a
service, graduate at different times while staying under
`cambeerfestival.festival.*`:

- The catalogue stabilises first → `cambeerfestival.festival.v1` carries the
  catalogue only.
- `cambeerfestival.festival.v1alpha` keeps a copy of the stable catalogue plus
  the still-alpha `MyFestivalService`, so alpha clients still get the whole
  surface in one version.
- A method whose shape is still settling (e.g. `BatchUpdateDrinkEntries`) can be
  held back in alpha even when the rest of its service has graduated — copy only
  the stable RPCs into the `v1` service.
- `MyFestivalService` graduates into a later stable version once its sync
  contract settles.

See `buf.yaml` for the step-by-step promotion path.

### Freshness & polling

Catalogue data changes during a live festival (drink availability especially)
and between festivals (new festivals). Clients poll the List endpoints to stay
current; the contract carries the freshness signal the upstream feeds already
provide:

- Each beverage feed file (`{festival}/{category}.json`) has a top-level
  `timestamp` (last-updated). It surfaces as **`Drink.update_time`** and
  **`Producer.update_time`** — granularity is per festival category (the file is
  the unit of change), so all items from one category share the value. The feed
  does **not** expose per-drink change times.
- The registry feed has a top-level `last_updated`, surfaced as
  **`Festival.update_time`** (registry-wide).

The efficient polling model is therefore **conditional re-fetch**, not item-level
delta sync:

1. Poll with HTTP `If-None-Match`/`If-Modified-Since`; an unchanged collection
   returns `304 Not Modified` and transfers nothing.
2. When it has changed, re-pull the (small, bounded) list and use `update_time`
   to confirm/raise the client's "as of" marker and drive "updated N ago" UI.

Item-level delta (`update_time > T` filtering) is intentionally **not** offered:
the feeds are whole-file snapshots, so the server cannot attribute a change to a
single drink. Re-fetch keyed off the per-category `update_time` matches the data's
real change granularity. (Realising the `304` path needs the worker to honour
conditional requests and shorten the drinks `Cache-Control` TTL — tracked
separately from this contract.)

## Layout

```
proto/
├── buf.yaml                  # module + lint/breaking config, BSR deps
├── buf.gen.yaml              # codegen: OpenAPI via BSR remote plugin
├── .api-linter.yaml          # AIP linter suppressions (see comments in file)
└── cambeerfestival/festival/v1alpha/
    ├── festival.proto            # Festival — festival metadata (canonical)
    ├── producer.proto            # Producer — brewery/cidery (canonical)
    ├── drink.proto               # Drink (canonical) + ProducerReference
    ├── catalog_service.proto     # CatalogService — read-only Get/List
    ├── drink_entry.proto         # DrinkEntry — caller personal state per drink
    ├── drink_summary.proto       # DrinkSummary — public aggregates per drink
    └── my_festival_service.proto # MyFestivalService — personal state + aggregates
```

## Catalogue resource model (AIP-121/122)

`CatalogService` defines the shared, read-only catalogue. Every RPC is a read —
catalogue data is published out-of-band via the festival data feeds, so there
are no create/update/delete methods and every data field is `OUTPUT_ONLY`.

| Resource | Name pattern | Methods |
| --- | --- | --- |
| `Festival` | `festivals/{f}` | Get, List |
| `Producer` | `festivals/{f}/producers/{p}` | Get, List |
| `Drink` | `festivals/{f}/drinks/{d}` | Get, List (paginated) |

`Producer` is a first-class resource so producer metadata stays normalised — the
feed is producer-keyed, so a brewery's location/founding-year/notes live once on
the `Producer`, and each `Drink` carries a `ProducerReference` (the producer
resource name plus its `display_name`, denormalised only for cheap card/search
rendering) rather than embedding the full record. Hydrate the producer directory
with `ListProducers`, or fetch one with `GetProducer`.

`Festival` and `Drink` are defined **canonically here**. `DrinkEntry`'s pattern
references them as parent types; because everything shares one package those
references resolve directly, so no `resource_definition` stubs are needed (a type
defined twice would fail `core::0123::duplicate-resource`). `Producer` is
embedded in `Drink` rather than modelled as its own resource; it can be promoted
to `festivals/{f}/producers/{p}` later if brewery-scoped browsing needs stable
names.

## Resource model (AIP-121/122)

### Personal state: DrinkEntry

`DrinkEntry` is a singleton resource — one per (caller, drink). It consolidates
what were previously four separate singletons (Bookmark, Note, Tasting, Review)
into one resource, so "hydrate my festival state on app open" costs a single
`ListDrinkEntries` call instead of four.

| Resource | Name pattern | Methods |
| --- | --- | --- |
| `DrinkEntry` | `festivals/{f}/drinks/{d}/entry` | Get, Update, Delete, List, BatchUpdate |

The caller's identity is resolved from the auth context and **never appears in
the resource name**, keeping device IDs private and making sign-in upgrades
transparent to existing clients.

### Public aggregates: DrinkSummary

`DrinkSummary` merges the former `ReviewSummary` and `TastingSummary` into one
read-only computed resource, so the festival-wide drinks grid can be populated
in a single paginated `ListDrinkSummaries` call.

| Resource | Name pattern | Methods |
| --- | --- | --- |
| `DrinkSummary` | `festivals/{f}/drinkSummaries/{d}` | Get, List (paginated) |

`{drink}` is used as the final URL segment (rather than `{drink_summary}`) so
the path reads as a natural key: `.../drinkSummaries/{drinkId}`.

## Sync machinery

The `DrinkEntry` contract includes features required for a reliable sync API:

| Feature | How it works |
| --- | --- |
| **Optimistic concurrency** | `DrinkEntry.etag` is an opaque server-assigned token. Echo it in `UpdateDrinkEntryRequest` (`drink_entry.etag`) to enable If-Match. Server returns `ABORTED` on stale etag; client re-fetches and retries. |
| **Upsert / idempotent create** | `UpdateDrinkEntryRequest.allow_missing = true` creates the entry if absent (AIP-134). Required for first-time writes and safe to replay. |
| **Idempotent delete** | `DeleteDrinkEntryRequest.allow_missing = true` suppresses errors when the entry is already absent. Safe to replay after a network timeout. |
| **Soft delete / tombstones** | `DeleteDrinkEntry` sets `delete_time` rather than permanently removing the entry, so the deletion propagates as a delta to other devices. Tombstones appear in `ListDrinkEntries` when `show_deleted = true`. |
| **Delta sync** | `ListDrinkEntriesRequest.filter` accepts AIP-160 expressions, e.g. `update_time > "2025-01-01T00:00:00Z"`. Only changed entries since the last sync are returned. |
| **Offline flush** | `BatchUpdateDrinkEntries` (AIP-235) accepts a batch of `UpdateDrinkEntryRequest` items. Clients queue mutations locally and flush on reconnect. Entries are processed independently; partial failure is possible. |

### Pour increment pattern

Pour increments are handled by read-modify-write guarded by etag:

1. `GetDrinkEntry` → read `pours` and `etag`
2. Set `drink_entry.pours = current + 1`, `drink_entry.etag = etag`
3. `UpdateDrinkEntry` with `update_mask = ["pours"]`
4. On `ABORTED` (stale etag), go to step 1

This avoids a custom `:addPour` method while remaining safe under concurrent
writes. A stale concurrent increment fails the If-Match check and the client
retries with the latest value.

## Service summary

`MyFestivalService` exposes 7 RPCs (consolidated from 20):

| RPC | HTTP | Purpose |
| --- | --- | --- |
| `GetDrinkEntry` | `GET /v1alpha/{name}` | Single entry lookup |
| `UpdateDrinkEntry` | `PATCH /v1alpha/{name}` | Upsert / partial update |
| `DeleteDrinkEntry` | `DELETE /v1alpha/{name}` | Soft delete |
| `ListDrinkEntries` | `GET /v1alpha/{parent}/drinkEntries` | Hydrate / delta sync |
| `BatchUpdateDrinkEntries` | `POST /v1alpha/{parent}/drinkEntries:batchUpdate` | Offline flush |
| `GetDrinkSummary` | `GET /v1alpha/{name}` | Single aggregate lookup |
| `ListDrinkSummaries` | `GET /v1alpha/{parent}/drinkSummaries` | Populate drinks grid |

## Generating

Requires the `buf` toolchain (provided by `MISE_ENV=dev`) and network access
to `buf.build` (BSR module deps + the remote OpenAPI plugin).

```bash
MISE_ENV=dev ./bin/mise run proto:format      # format .proto files in place
MISE_ENV=dev ./bin/mise run proto:lint        # buf STANDARD ruleset
MISE_ENV=dev ./bin/mise run proto:api-lint    # AIP design guidelines
MISE_ENV=dev ./bin/mise run proto:generate    # -> docs/code/api/openapi/openapi.yaml
```

`proto:dep-update` refreshes `buf.lock` from BSR (run after editing `buf.yaml`
dependencies).
