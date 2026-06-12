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
 * Shared bucket/validation/routing plumbing lives in shared.js.
 */

import {
  validateIds,
  jsonResponse,
  parseJsonBody,
  routeResource,
} from "./shared.js";

/**
 * Validate a write payload. POST requires `rating`; DELETE only needs ids.
 * Returns { ok: true, value } or { ok: false, error }.
 */
export function validateWritePayload(body, { requireRating }) {
  const ids = validateIds(body);
  if (!ids.ok) return ids;

  const { rating } = body;
  if (requireRating) {
    if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
      return { ok: false, error: "rating must be an integer between 1 and 5" };
    }
  }
  return { ok: true, value: { ...ids.value, rating } };
}

/** Round an average to one decimal place, or null when there are no ratings. */
export function formatAverage(average, count) {
  if (!count || average == null) return null;
  return Math.round(average * 10) / 10;
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

async function handlePost(request, db, bucket, corsHeaders) {
  const parsed = await parseJsonBody(request);
  if (!parsed.ok) {
    return jsonResponse({ error: "Invalid JSON body" }, 400, corsHeaders);
  }

  const result = validateWritePayload(parsed.body, { requireRating: true });
  if (!result.ok) {
    return jsonResponse({ error: result.error }, 400, corsHeaders);
  }

  const { festivalId, drinkId, deviceId, rating } = result.value;
  await db
    .prepare(
      "INSERT INTO ratings (bucket, festival_id, drink_id, device_id, rating, updated_at) " +
        "VALUES (?, ?, ?, ?, ?, ?) " +
        "ON CONFLICT (bucket, festival_id, drink_id, device_id) " +
        "DO UPDATE SET rating = excluded.rating, updated_at = excluded.updated_at",
    )
    .bind(bucket, festivalId, drinkId, deviceId, rating, Date.now())
    .run();

  const aggregate = await readAggregate(
    db,
    bucket,
    festivalId,
    drinkId,
    deviceId,
  );
  return jsonResponse(aggregate, 200, corsHeaders);
}

async function handleDelete(request, db, bucket, corsHeaders) {
  const parsed = await parseJsonBody(request);
  if (!parsed.ok) {
    return jsonResponse({ error: "Invalid JSON body" }, 400, corsHeaders);
  }

  const result = validateWritePayload(parsed.body, { requireRating: false });
  if (!result.ok) {
    return jsonResponse({ error: result.error }, 400, corsHeaders);
  }

  const { festivalId, drinkId, deviceId } = result.value;
  await db
    .prepare(
      "DELETE FROM ratings " +
        "WHERE bucket = ? AND festival_id = ? AND drink_id = ? AND device_id = ?",
    )
    .bind(bucket, festivalId, drinkId, deviceId)
    .run();

  const aggregate = await readAggregate(
    db,
    bucket,
    festivalId,
    drinkId,
    deviceId,
  );
  return jsonResponse(aggregate, 200, corsHeaders);
}

async function handleGetSingle(
  db,
  bucket,
  festivalId,
  drinkId,
  deviceId,
  corsHeaders,
) {
  const aggregate = await readAggregate(
    db,
    bucket,
    festivalId,
    drinkId,
    deviceId,
  );
  return jsonResponse(aggregate, 200, corsHeaders);
}

/** Batch: every rated drink for a festival, keyed by drink id. */
async function handleGetFestival(
  db,
  bucket,
  festivalId,
  deviceId,
  corsHeaders,
) {
  const { results } = await db
    .prepare(
      "SELECT drink_id, COUNT(*) AS count, AVG(rating) AS average " +
        "FROM ratings WHERE bucket = ? AND festival_id = ? GROUP BY drink_id",
    )
    .bind(bucket, festivalId)
    .all();

  const own = new Map();
  if (deviceId) {
    const ownRows = await db
      .prepare(
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

/** Route and handle a /v1/ratings request, or null if not a ratings path. */
export function handleRatings(request, url, env, corsHeaders) {
  return routeResource(request, url, env, corsHeaders, {
    basePath: "/v1/ratings",
    db: "RATINGS_DB",
    post: handlePost,
    del: handleDelete,
    getSingle: handleGetSingle,
    getFestival: handleGetFestival,
  });
}
