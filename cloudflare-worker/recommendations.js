/**
 * "Would recommend" API (v1).
 *
 * A yes/no signal, separate from the star rating, so we can surface a
 * "% would recommend" for each drink. Endpoints mirror the ratings API and
 * share the same D1 database (RATINGS_DB), in a separate `recommendations`
 * table:
 *   POST   /v1/recommendations                         upsert a device's yes/no
 *   DELETE /v1/recommendations                         remove a device's answer
 *   GET    /v1/recommendations/{festivalId}/{drinkId}  aggregate for one drink
 *   GET    /v1/recommendations/{festivalId}            aggregate for every drink
 *
 * `recommend` is stored as 0/1 (SQLite has no boolean) and exposed as a JSON
 * boolean. The aggregate reports total responses, the count of "yes", and the
 * percentage that would recommend.
 */

import {
  validateIds,
  jsonResponse,
  parseJsonBody,
  routeResource,
} from "./shared.js";

/**
 * Validate a write payload. POST requires a boolean `recommend`; DELETE only
 * needs ids. Returns { ok: true, value } or { ok: false, error }.
 */
export function validateRecommendPayload(body, { requireRecommend }) {
  const ids = validateIds(body);
  if (!ids.ok) return ids;

  const { recommend } = body;
  if (requireRecommend && typeof recommend !== "boolean") {
    return { ok: false, error: "recommend must be a boolean" };
  }
  return { ok: true, value: { ...ids.value, recommend } };
}

/** Whole-number "% would recommend", or null when there are no responses. */
export function formatPercent(recommendCount, count) {
  if (!count) return null;
  return Math.round((recommendCount / count) * 100);
}

function aggregateShape(count, recommendCount, youRecommend) {
  return {
    count,
    recommendCount,
    recommendPercent: formatPercent(recommendCount, count),
    youRecommend,
  };
}

/** Aggregate (responses + yes count + percentage) for one drink. */
async function readRecommendation(db, bucket, festivalId, drinkId, deviceId) {
  const agg = await db
    .prepare(
      "SELECT COUNT(*) AS count, SUM(recommend) AS yes " +
        "FROM recommendations WHERE bucket = ? AND festival_id = ? AND drink_id = ?",
    )
    .bind(bucket, festivalId, drinkId)
    .first();

  let youRecommend = null;
  if (deviceId) {
    const own = await db
      .prepare(
        "SELECT recommend FROM recommendations " +
          "WHERE bucket = ? AND festival_id = ? AND drink_id = ? AND device_id = ?",
      )
      .bind(bucket, festivalId, drinkId, deviceId)
      .first();
    youRecommend = own ? Boolean(own.recommend) : null;
  }

  const count = agg ? agg.count : 0;
  const recommendCount = agg && agg.yes != null ? agg.yes : 0;
  return {
    festivalId,
    drinkId,
    ...aggregateShape(count, recommendCount, youRecommend),
  };
}

async function handlePost(request, db, bucket, corsHeaders) {
  const parsed = await parseJsonBody(request);
  if (!parsed.ok) {
    return jsonResponse({ error: "Invalid JSON body" }, 400, corsHeaders);
  }

  const result = validateRecommendPayload(parsed.body, {
    requireRecommend: true,
  });
  if (!result.ok) {
    return jsonResponse({ error: result.error }, 400, corsHeaders);
  }

  const { festivalId, drinkId, deviceId, recommend } = result.value;
  await db
    .prepare(
      "INSERT INTO recommendations (bucket, festival_id, drink_id, device_id, recommend, updated_at) " +
        "VALUES (?, ?, ?, ?, ?, ?) " +
        "ON CONFLICT (bucket, festival_id, drink_id, device_id) " +
        "DO UPDATE SET recommend = excluded.recommend, updated_at = excluded.updated_at",
    )
    .bind(bucket, festivalId, drinkId, deviceId, recommend ? 1 : 0, Date.now())
    .run();

  const aggregate = await readRecommendation(
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

  const result = validateRecommendPayload(parsed.body, {
    requireRecommend: false,
  });
  if (!result.ok) {
    return jsonResponse({ error: result.error }, 400, corsHeaders);
  }

  const { festivalId, drinkId, deviceId } = result.value;
  await db
    .prepare(
      "DELETE FROM recommendations " +
        "WHERE bucket = ? AND festival_id = ? AND drink_id = ? AND device_id = ?",
    )
    .bind(bucket, festivalId, drinkId, deviceId)
    .run();

  const aggregate = await readRecommendation(
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
  const aggregate = await readRecommendation(
    db,
    bucket,
    festivalId,
    drinkId,
    deviceId,
  );
  return jsonResponse(aggregate, 200, corsHeaders);
}

/** Batch: every drink with a response for a festival, keyed by drink id. */
async function handleGetFestival(
  db,
  bucket,
  festivalId,
  deviceId,
  corsHeaders,
) {
  const { results } = await db
    .prepare(
      "SELECT drink_id, COUNT(*) AS count, SUM(recommend) AS yes " +
        "FROM recommendations WHERE bucket = ? AND festival_id = ? GROUP BY drink_id",
    )
    .bind(bucket, festivalId)
    .all();

  const own = new Map();
  if (deviceId) {
    const ownRows = await db
      .prepare(
        "SELECT drink_id, recommend FROM recommendations " +
          "WHERE bucket = ? AND festival_id = ? AND device_id = ?",
      )
      .bind(bucket, festivalId, deviceId)
      .all();
    for (const row of ownRows.results) {
      own.set(row.drink_id, Boolean(row.recommend));
    }
  }

  const aggregates = {};
  for (const row of results) {
    const recommendCount = row.yes != null ? row.yes : 0;
    aggregates[row.drink_id] = aggregateShape(
      row.count,
      recommendCount,
      own.has(row.drink_id) ? own.get(row.drink_id) : null,
    );
  }

  return jsonResponse({ festivalId, aggregates }, 200, corsHeaders);
}

/** Route and handle a /v1/recommendations request, or null if not one. */
export function handleRecommendations(request, url, env, corsHeaders) {
  return routeResource(request, url, env, corsHeaders, {
    basePath: "/v1/recommendations",
    db: "RATINGS_DB",
    post: handlePost,
    del: handleDelete,
    getSingle: handleGetSingle,
    getFestival: handleGetFestival,
  });
}
