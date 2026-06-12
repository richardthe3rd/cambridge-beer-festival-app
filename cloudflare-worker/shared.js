/**
 * Shared engine for the resource-oriented /v1 "my festival" APIs.
 *
 * Routes follow AIP resource names. For a "family" (ratings, recommendations)
 * with write-collection W and summary-collection S:
 *
 *   GET    /v1/festivals/{f}/drinks/{d}/W/{device}   get this device's record
 *   PATCH  /v1/festivals/{f}/drinks/{d}/W/{device}   upsert (allow_missing)
 *   DELETE /v1/festivals/{f}/drinks/{d}/W/{device}   remove this device's record
 *   GET    /v1/festivals/{f}/S/{d}                    aggregate for one drink
 *   GET    /v1/festivals/{f}/S                        list aggregates (paginated)
 *
 * Errors use the structured google.rpc.Status shape (AIP-193). Lists paginate
 * with opaque keyset tokens (AIP-158).
 */

const MAX_ID_LENGTH = 200;
const DEFAULT_PAGE_SIZE = 100;
const MAX_PAGE_SIZE = 1000;
const ERROR_DOMAIN = "cambeerfestival.app";

export function isProductionOrigin(origin) {
  return origin === "https://cambeerfestival.app";
}

export function resolveBucket(origin, env) {
  if (env && typeof env.RATINGS_BUCKET === "string" && env.RATINGS_BUCKET) {
    return env.RATINGS_BUCKET;
  }
  return isProductionOrigin(origin) ? "prod" : "test";
}

export function rfc3339(epochMillis) {
  return new Date(epochMillis).toISOString();
}

function isValidId(value) {
  return (
    typeof value === "string" &&
    value.length > 0 &&
    value.length <= MAX_ID_LENGTH
  );
}

// --- Responses (AIP-193) ---------------------------------------------------

export function jsonResponse(body, status, corsHeaders) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      ...corsHeaders,
    },
  });
}

/** Structured error body per AIP-193 (google.rpc.Status + ErrorInfo). */
export function errorResponse(
  httpCode,
  status,
  message,
  reason,
  corsHeaders,
  metadata,
) {
  const errorInfo = {
    "@type": "type.googleapis.com/google.rpc.ErrorInfo",
    reason,
    domain: ERROR_DOMAIN,
  };
  if (metadata) errorInfo.metadata = metadata;
  return jsonResponse(
    { error: { code: httpCode, message, status, details: [errorInfo] } },
    httpCode,
    corsHeaders,
  );
}

// --- Pagination (AIP-158) --------------------------------------------------

/** Encode a keyset cursor (last drink id) as an opaque URL-safe token. */
export function encodePageToken(drinkId) {
  return btoa(unescape(encodeURIComponent(drinkId)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

/** Decode a page token back to its cursor, or null if absent. */
export function decodePageToken(token) {
  if (!token) return null;
  try {
    const b64 = token.replace(/-/g, "+").replace(/_/g, "/");
    return decodeURIComponent(escape(atob(b64)));
  } catch {
    return undefined; // signal "invalid token"
  }
}

/** Resolve an effective page size, or { error } for a bad value. */
export function resolvePageSize(raw) {
  if (raw == null || raw === "") return { value: DEFAULT_PAGE_SIZE };
  const n = Number(raw);
  if (!Number.isInteger(n) || n < 0) return { error: true };
  if (n === 0) return { value: DEFAULT_PAGE_SIZE };
  return { value: Math.min(n, MAX_PAGE_SIZE) };
}

// --- Routing ---------------------------------------------------------------

function parseV1Path(pathname) {
  if (pathname !== "/v1" && !pathname.startsWith("/v1/")) return null;
  return pathname
    .slice("/v1/".length)
    .split("/")
    .filter((s) => s.length > 0)
    .map((s) => decodeURIComponent(s));
}

/**
 * Handle a request for one resource family. Returns a Response if the path
 * belongs to this family, otherwise null so the caller can try the next.
 *
 * `family` provides: table, valueColumn, writeCollection, summaryCollection,
 * parseValue(body), serializeResource(name,row), summaryColumns,
 * summaryFields(row).
 */
export async function handleResourceFamily(
  request,
  url,
  env,
  corsHeaders,
  family,
) {
  const segments = parseV1Path(url.pathname);
  if (!segments || segments[0] !== "festivals" || segments.length < 3) {
    return null;
  }

  // /v1/festivals/{f}/drinks/{d}/{writeCollection}/{device}
  const isWrite =
    segments.length === 6 &&
    segments[2] === "drinks" &&
    segments[4] === family.writeCollection;
  // /v1/festivals/{f}/{summaryCollection}[/{drink}]
  const isSummary =
    (segments.length === 3 || segments.length === 4) &&
    segments[2] === family.summaryCollection;

  if (!isWrite && !isSummary) return null;

  if (!env || !env.RATINGS_DB) {
    return errorResponse(
      503,
      "UNAVAILABLE",
      "Storage is not configured",
      "STORAGE_UNCONFIGURED",
      corsHeaders,
    );
  }

  const origin = request.headers.get("Origin") || "";
  const bucket = resolveBucket(origin, env);
  const db = env.RATINGS_DB;

  if (isWrite) {
    const [, festivalId, , drinkId, , deviceId] = segments;
    if (!isValidId(festivalId) || !isValidId(drinkId) || !isValidId(deviceId)) {
      return errorResponse(
        400,
        "INVALID_ARGUMENT",
        "Invalid resource name",
        "INVALID_RESOURCE_NAME",
        corsHeaders,
      );
    }
    const ctx = {
      db,
      bucket,
      family,
      festivalId,
      drinkId,
      deviceId,
      corsHeaders,
    };
    switch (request.method) {
      case "GET":
        return getRecord(ctx);
      case "PATCH":
        return upsertRecord(request, ctx);
      case "DELETE":
        return deleteRecord(ctx);
      default:
        return methodNotAllowed(corsHeaders);
    }
  }

  // Summary read / list
  if (request.method !== "GET") return methodNotAllowed(corsHeaders);
  const festivalId = segments[1];
  if (!isValidId(festivalId)) {
    return errorResponse(
      400,
      "INVALID_ARGUMENT",
      "Invalid resource name",
      "INVALID_RESOURCE_NAME",
      corsHeaders,
    );
  }
  if (segments.length === 4) {
    return getSummary({
      db,
      bucket,
      family,
      festivalId,
      drinkId: segments[3],
      corsHeaders,
    });
  }
  return listSummaries({ db, bucket, family, festivalId, url, corsHeaders });
}

function methodNotAllowed(corsHeaders) {
  return errorResponse(
    405,
    "UNIMPLEMENTED",
    "Method not allowed for this resource",
    "METHOD_NOT_ALLOWED",
    corsHeaders,
  );
}

function writeResourceName(family, festivalId, drinkId, deviceId) {
  return `festivals/${festivalId}/drinks/${drinkId}/${family.writeCollection}/${deviceId}`;
}

function summaryResourceName(family, festivalId, drinkId) {
  return `festivals/${festivalId}/${family.summaryCollection}/${drinkId}`;
}

async function readRow(ctx) {
  const { db, family, bucket, festivalId, drinkId, deviceId } = ctx;
  return db
    .prepare(
      `SELECT ${family.valueColumn} AS value, updated_at FROM ${family.table} ` +
        "WHERE bucket = ? AND festival_id = ? AND drink_id = ? AND device_id = ?",
    )
    .bind(bucket, festivalId, drinkId, deviceId)
    .first();
}

async function getRecord(ctx) {
  const { family, festivalId, drinkId, deviceId, corsHeaders } = ctx;
  const row = await readRow(ctx);
  if (!row) {
    return errorResponse(
      404,
      "NOT_FOUND",
      "No such rating",
      "NOT_FOUND",
      corsHeaders,
    );
  }
  const name = writeResourceName(family, festivalId, drinkId, deviceId);
  return jsonResponse(family.serializeResource(name, row), 200, corsHeaders);
}

async function upsertRecord(request, ctx) {
  const { db, family, bucket, festivalId, drinkId, deviceId, corsHeaders } =
    ctx;

  let body;
  try {
    body = await request.json();
  } catch {
    return errorResponse(
      400,
      "INVALID_ARGUMENT",
      "Invalid JSON body",
      "INVALID_BODY",
      corsHeaders,
    );
  }

  const parsed = family.parseValue(body);
  if (!parsed.ok) {
    return errorResponse(
      400,
      "INVALID_ARGUMENT",
      parsed.message,
      parsed.reason,
      corsHeaders,
    );
  }

  await db
    .prepare(
      `INSERT INTO ${family.table} ` +
        `(bucket, festival_id, drink_id, device_id, ${family.valueColumn}, updated_at) ` +
        "VALUES (?, ?, ?, ?, ?, ?) " +
        "ON CONFLICT (bucket, festival_id, drink_id, device_id) " +
        `DO UPDATE SET ${family.valueColumn} = excluded.${family.valueColumn}, ` +
        "updated_at = excluded.updated_at",
    )
    .bind(bucket, festivalId, drinkId, deviceId, parsed.columnValue, Date.now())
    .run();

  const row = await readRow(ctx);
  const name = writeResourceName(family, festivalId, drinkId, deviceId);
  return jsonResponse(family.serializeResource(name, row), 200, corsHeaders);
}

async function deleteRecord(ctx) {
  const { db, family, bucket, festivalId, drinkId, deviceId, corsHeaders } =
    ctx;
  const result = await db
    .prepare(
      `DELETE FROM ${family.table} ` +
        "WHERE bucket = ? AND festival_id = ? AND drink_id = ? AND device_id = ?",
    )
    .bind(bucket, festivalId, drinkId, deviceId)
    .run();

  // AIP-135: deleting a missing resource is NOT_FOUND.
  const changes = result.meta ? result.meta.changes : 0;
  if (!changes) {
    return errorResponse(
      404,
      "NOT_FOUND",
      "No such rating",
      "NOT_FOUND",
      ctx.corsHeaders,
    );
  }
  return jsonResponse({}, 200, corsHeaders);
}

async function getSummary(ctx) {
  const { db, family, bucket, festivalId, drinkId, corsHeaders } = ctx;
  const row = await db
    .prepare(
      `SELECT ${family.summaryColumns} FROM ${family.table} ` +
        "WHERE bucket = ? AND festival_id = ? AND drink_id = ?",
    )
    .bind(bucket, festivalId, drinkId)
    .first();

  const name = summaryResourceName(family, festivalId, drinkId);
  return jsonResponse(
    { name, ...family.summaryFields(row || {}) },
    200,
    corsHeaders,
  );
}

async function listSummaries(ctx) {
  const { db, family, bucket, festivalId, url, corsHeaders } = ctx;

  const sizeResult = resolvePageSize(url.searchParams.get("page_size"));
  if (sizeResult.error) {
    return errorResponse(
      400,
      "INVALID_ARGUMENT",
      "page_size must be >= 0",
      "INVALID_PAGE_SIZE",
      corsHeaders,
    );
  }
  const pageSize = sizeResult.value;

  const cursor = decodePageToken(url.searchParams.get("page_token"));
  if (cursor === undefined) {
    return errorResponse(
      400,
      "INVALID_ARGUMENT",
      "Invalid page_token",
      "INVALID_PAGE_TOKEN",
      corsHeaders,
    );
  }

  const where = ["bucket = ?", "festival_id = ?"];
  const binds = [bucket, festivalId];
  if (cursor !== null) {
    where.push("drink_id > ?");
    binds.push(cursor);
  }

  // Fetch one extra row to detect whether another page follows.
  const { results } = await db
    .prepare(
      `SELECT drink_id, ${family.summaryColumns} FROM ${family.table} ` +
        `WHERE ${where.join(" AND ")} GROUP BY drink_id ORDER BY drink_id LIMIT ?`,
    )
    .bind(...binds, pageSize + 1)
    .all();

  const page = results.slice(0, pageSize);
  const items = page.map((row) => ({
    name: summaryResourceName(family, festivalId, row.drink_id),
    ...family.summaryFields(row),
  }));

  let nextPageToken = "";
  if (results.length > pageSize) {
    nextPageToken = encodePageToken(page[page.length - 1].drink_id);
  }

  const totalRow = await db
    .prepare(
      `SELECT COUNT(DISTINCT drink_id) AS n FROM ${family.table} ` +
        "WHERE bucket = ? AND festival_id = ?",
    )
    .bind(bucket, festivalId)
    .first();

  return jsonResponse(
    {
      [family.summaryCollection]: items,
      nextPageToken,
      totalSize: totalRow ? totalRow.n : 0,
    },
    200,
    corsHeaders,
  );
}
