# API contract (proto-first)

The online "my festival" API (ratings + recommendations) is defined here as
Protocol Buffers following [Google's API Improvement Proposals](https://google.aip.dev)
(AIP). The proto is the source of truth; an OpenAPI v3 document is generated
from it for the (hand-written) Cloudflare Worker implementation and any HTTP
clients.

The transport is plain HTTP/JSON — the `google.api.http` annotations map each
RPC to a REST route. We do **not** run a gRPC server; the proto is the contract
and OpenAPI is the generated artifact.

## Layout

```
proto/
├── buf.yaml                  # module + lint/breaking config, BSR deps
├── buf.gen.yaml              # codegen: OpenAPI via BSR remote plugin
└── cambeerfestival/myfestival/v1/
    ├── rating.proto              # Rating + RatingSummary resources
    ├── recommendation.proto      # Recommendation + RecommendationSummary
    └── my_festival_service.proto # service + request/response messages
```

## Resource model (AIP-121/122)

| Resource | Name pattern | Methods |
| --- | --- | --- |
| `Rating` | `festivals/{f}/drinks/{d}/ratings/{device}` | Get, Update (upsert), Delete |
| `RatingSummary` | `festivals/{f}/ratingSummaries/{d}` | Get, List (paginated) |
| `Recommendation` | `festivals/{f}/drinks/{d}/recommendations/{device}` | Get, Update (upsert), Delete |
| `RecommendationSummary` | `festivals/{f}/recommendationSummaries/{d}` | Get, List (paginated) |

Writes use **Update with `allow_missing`** (AIP-134 upsert) because the device
assigns the resource id; **Delete** takes the id in the path with no body
(AIP-135). Aggregates are read-only computed resources, listed with pagination
(AIP-158). Errors follow the structured `google.rpc.Status` shape (AIP-193).

## Generating

Requires the `buf` toolchain (provided by mise) and network access to
`buf.build` (BSR module deps + the remote OpenAPI plugin).

```bash
MISE_ENV=dev ./bin/mise run proto:dep-update   # writes buf.lock (first time)
MISE_ENV=dev ./bin/mise run proto:lint          # AIP-aware lint
MISE_ENV=dev ./bin/mise run proto:generate       # -> docs/code/api/openapi/openapi.yaml
```

`buf format -w` (via `proto:format`) keeps the files canonically formatted.
