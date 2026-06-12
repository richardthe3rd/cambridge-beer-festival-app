/**
 * Aggregate drink ratings API (v1).
 *
 * Endpoints (all under /v1/ratings, served by the same worker as the proxy):
 *   POST   /v1/ratings                          upsert a device's rating
 *   DELETE /v1/ratings                          remove a device's rating
 *   GET    /v1/ratings/{festivalId}/{drinkId}   aggregate for one drink
 *   GET    /v1/ratings/{festivalId}             aggregate for every rated drink
 *
 * Writes are local-first on the client; the server is the shared aggregate.
 * Every row and query is scoped by a `bucket` so test traffic never mixes with
 * production data — see resolveBucket().
 */

const MAX_ID_LENGTH = 200;

// Only the production web origin maps to the 'prod' bucket. Everything else
// (staging, Pages previews, localhost, tunnels, native apps with no Origin)
// lands in 'test'. This mirrors EnvironmentService.isProductionHost on the
// client and keeps a single worker deploy serving both buckets safely —
// bucket is a data-hygiene boundary, not a security one.
export function isProductionOrigin(origin) {
  return origin === "https://cambeerfestival.app";
}

/**
 * Resolve the storage bucket for a request.
 *
 * An explicit `RATINGS_BUCKET` worker var wins (lets us pin a deploy to a
 * bucket during rollout); otherwise it is derived from the request origin.
 */
export function resolveBucket(origin, env) {
  if (env && typeof env.RATINGS_BUCKET === "string" && env.RATINGS_BUCKET) {
    return env.RATINGS_BUCKET;
  }
  return isProductionOrigin(origin) ? "prod" : "test";
}

function isValidId(value) {
  return (
    typeof value === "string" &&
    value.length > 0 &&
    value.length <= MAX_ID_LENGTH
  );
}

/**
 * Validate a write payload (POST/DELETE share the same shape, minus `rating`
 * for DELETE). Returns { ok: true, value } or { ok: false, error }.
 */
export function validateWritePayload(body, { requireRating }) {
  if (body === null || typeof body !== "object") {
    return { ok: false, error: "Request body must be a JSON object" };
  }

  const { festivalId, drinkId, deviceId, rating } = body;

  if (!isValidId(festivalId)) {
    return { ok: false, error: "festivalId is required" };
  }
  if (!isValidId(drinkId)) {
    return { ok: false, error: "drinkId is required" };
  }
  if (!isValidId(deviceId)) {
    return { ok: false, error: "deviceId is required" };
  }

  if (requireRating) {
    if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
      return { ok: false, error: "rating must be an integer between 1 and 5" };
    }
  }

  return { ok: true, value: { festivalId, drinkId, deviceId, rating } };
}

/** Round an average to one decimal place, or null when there are no ratings. */
export function formatAverage(average, count) {
  if (!count || average == null) return null;
  return Math.round(average * 10) / 10;
}

function jsonResponse(body, status, corsHeaders) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      ...corsHeaders,
    },
  });
}

async function parseJsonBody(request) {
  try {
    return { ok: true, body: await request.json() };
  } catch {
    return { ok: false };
  }
}

/** Aggregate (count + average) for a single drink in a bucket. */
async function readAggregate(db, bucket, festivalId, drinkId, deviceId) {
  const agg = await db
    .prepare(
      "SELECT COUNT(*) AS count, AVG(rating) AS average " +
        "FROM ratings WHERE bucket = ? AND festival_id = ? AND drink_id = ?",
    )
    .bind(bucket, festivalId, drinkId)
    .first();

  let yourRating = null;
  if (deviceId) {
    const own = await db
      .prepare(
        "SELECT rating FROM ratings " +
          "WHERE bucket = ? AND festival_id = ? AND drink_id = ? AND device_id = ?",
      )
      .bind(bucket, festivalId, drinkId, deviceId)
      .first();
    yourRating = own ? own.rating : null;
  }

  const count = agg ? agg.count : 0;
  return {
    festivalId,
    drinkId,
    count,
    average: formatAverage(agg ? agg.average : null, count),
    yourRating,
  };
}

async function handlePost(request, env, bucket, corsHeaders) {
  const parsed = await parseJsonBody(request);
  if (!parsed.ok) {
    return jsonResponse({ error: "Invalid JSON body" }, 400, corsHeaders);
  }

  const result = validateWritePayload(parsed.body, { requireRating: true });
  if (!result.ok) {
    return jsonResponse({ error: result.error }, 400, corsHeaders);
  }

  const { festivalId, drinkId, deviceId, rating } = result.value;
  await env.RATINGS_DB.prepare(
    "INSERT INTO ratings (bucket, festival_id, drink_id, device_id, rating, updated_at) " +
      "VALUES (?, ?, ?, ?, ?, ?) " +
      "ON CONFLICT (bucket, festival_id, drink_id, device_id) " +
      "DO UPDATE SET rating = excluded.rating, updated_at = excluded.updated_at",
  )
    .bind(bucket, festivalId, drinkId, deviceId, rating, Date.now())
    .run();

  const aggregate = await readAggregate(
    env.RATINGS_DB,
    bucket,
    festivalId,
    drinkId,
    deviceId,
  );
  return jsonResponse(aggregate, 200, corsHeaders);
}

async function handleDelete(request, env, bucket, corsHeaders) {
  const parsed = await parseJsonBody(request);
  if (!parsed.ok) {
    return jsonResponse({ error: "Invalid JSON body" }, 400, corsHeaders);
  }

  const result = validateWritePayload(parsed.body, { requireRating: false });
  if (!result.ok) {
    return jsonResponse({ error: result.error }, 400, corsHeaders);
  }

  const { festivalId, drinkId, deviceId } = result.value;
  await env.RATINGS_DB.prepare(
    "DELETE FROM ratings " +
      "WHERE bucket = ? AND festival_id = ? AND drink_id = ? AND device_id = ?",
  )
    .bind(bucket, festivalId, drinkId, deviceId)
    .run();

  const aggregate = await readAggregate(
    env.RATINGS_DB,
    bucket,
    festivalId,
    drinkId,
    deviceId,
  );
  return jsonResponse(aggregate, 200, corsHeaders);
}

async function handleGetSingle(
  env,
  bucket,
  festivalId,
  drinkId,
  deviceId,
  corsHeaders,
) {
  const aggregate = await readAggregate(
    env.RATINGS_DB,
    bucket,
    festivalId,
    drinkId,
    deviceId,
  );
  return jsonResponse(aggregate, 200, corsHeaders);
}

/** Batch: every rated drink for a festival, keyed by drink id. */
async function handleGetFestival(
  env,
  bucket,
  festivalId,
  deviceId,
  corsHeaders,
) {
  const { results } = await env.RATINGS_DB.prepare(
    "SELECT drink_id, COUNT(*) AS count, AVG(rating) AS average " +
      "FROM ratings WHERE bucket = ? AND festival_id = ? GROUP BY drink_id",
  )
    .bind(bucket, festivalId)
    .all();

  const own = new Map();
  if (deviceId) {
    const ownRows = await env.RATINGS_DB.prepare(
      "SELECT drink_id, rating FROM ratings " +
        "WHERE bucket = ? AND festival_id = ? AND device_id = ?",
    )
      .bind(bucket, festivalId, deviceId)
      .all();
    for (const row of ownRows.results) {
      own.set(row.drink_id, row.rating);
    }
  }

  const aggregates = {};
  for (const row of results) {
    aggregates[row.drink_id] = {
      count: row.count,
      average: formatAverage(row.average, row.count),
      yourRating: own.has(row.drink_id) ? own.get(row.drink_id) : null,
    };
  }

  return jsonResponse({ festivalId, aggregates }, 200, corsHeaders);
}

/**
 * Route and handle a /v1/ratings request. Returns a Response, or null if the
 * path is not a ratings path (so the caller can fall through to the proxy).
 */
export async function handleRatings(request, url, env, corsHeaders) {
  if (
    url.pathname !== "/v1/ratings" &&
    !url.pathname.startsWith("/v1/ratings/")
  ) {
    return null;
  }

  if (!env || !env.RATINGS_DB) {
    return jsonResponse(
      { error: "Ratings storage is not configured" },
      503,
      corsHeaders,
    );
  }

  const origin = request.headers.get("Origin") || "";
  const bucket = resolveBucket(origin, env);

  // Collection endpoint: POST / DELETE on /v1/ratings
  if (url.pathname === "/v1/ratings") {
    if (request.method === "POST") {
      return handlePost(request, env, bucket, corsHeaders);
    }
    if (request.method === "DELETE") {
      return handleDelete(request, env, bucket, corsHeaders);
    }
    return jsonResponse({ error: "Method not allowed" }, 405, corsHeaders);
  }

  // Read endpoints: GET /v1/ratings/{festivalId}[/{drinkId}]
  if (request.method !== "GET") {
    return jsonResponse({ error: "Method not allowed" }, 405, corsHeaders);
  }

  const segments = url.pathname
    .slice("/v1/ratings/".length)
    .split("/")
    .filter((s) => s.length > 0)
    .map((s) => decodeURIComponent(s));
  const deviceId = url.searchParams.get("deviceId") || null;

  if (segments.length === 1) {
    return handleGetFestival(env, bucket, segments[0], deviceId, corsHeaders);
  }
  if (segments.length === 2) {
    return handleGetSingle(
      env,
      bucket,
      segments[0],
      segments[1],
      deviceId,
      corsHeaders,
    );
  }

  return jsonResponse({ error: "Not found" }, 404, corsHeaders);
}
