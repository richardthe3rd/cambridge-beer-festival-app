/**
 * Review resource handler for the /v1alpha "my festival" API.
 *
 * Routes (AIP resource-oriented, conforms to proto contract in proto/):
 *   GET    /v1alpha/festivals/{f}/drinks/{d}/review   get caller's review
 *   PATCH  /v1alpha/festivals/{f}/drinks/{d}/review   upsert caller's review
 *   DELETE /v1alpha/festivals/{f}/drinks/{d}/review   remove caller's review
 *   GET    /v1alpha/festivals/{f}/reviews              list caller's reviews
 *   GET    /v1alpha/festivals/{f}/reviewSummaries/{d} aggregate for one drink
 *   GET    /v1alpha/festivals/{f}/reviewSummaries     list aggregates (paginated)
 *
 * The Review is a singleton per (caller, drink). Caller identity comes from
 * the X-Device-Id request header in the anonymous phase; it never appears in
 * resource names, so the sign-in upgrade is transparent to clients.
 *
 * Both signals (starRating, wouldRecommend) are independently optional:
 * a caller can rate without answering the recommendation question, or vice
 * versa. Use the updateMask field in the PATCH body to update only one signal
 * without clearing the other.
 */

import {
  resolveBucket,
  rfc3339,
  jsonResponse,
  errorResponse,
  encodePageToken,
  decodePageToken,
  resolvePageSize,
} from "./shared.js";

const MAX_ID_LENGTH = 200;

function isValidId(value) {
  return (
    typeof value === "string" &&
    value.length > 0 &&
    value.length <= MAX_ID_LENGTH
  );
}

function getDeviceId(request, corsHeaders) {
  const deviceId = request.headers.get("X-Device-Id");
  if (!isValidId(deviceId)) {
    return {
      error: errorResponse(
        400,
        "INVALID_ARGUMENT",
        "X-Device-Id header is required (non-empty, max 200 chars)",
        "MISSING_DEVICE_ID",
        corsHeaders,
      ),
    };
  }
  return { deviceId };
}

function parseV1alphaPath(pathname) {
  if (pathname !== "/v1alpha" && !pathname.startsWith("/v1alpha/")) return null;
  return pathname
    .slice("/v1alpha/".length)
    .split("/")
    .filter((s) => s.length > 0)
    .map((s) => decodeURIComponent(s));
}

/** Route a request, or return null if the path doesn't match any review route. */
export async function handleReviews(request, url, env, corsHeaders) {
  const segments = parseV1alphaPath(url.pathname);
  if (!segments || segments[0] !== "festivals" || segments.length < 3) {
    return null;
  }

  // /v1alpha/festivals/{f}/drinks/{d}/review
  const isReviewRecord =
    segments.length === 5 &&
    segments[2] === "drinks" &&
    segments[4] === "review";

  // /v1alpha/festivals/{f}/reviews
  const isReviewList = segments.length === 3 && segments[2] === "reviews";

  // /v1alpha/festivals/{f}/reviewSummaries[/{drink}]
  const isSummary =
    (segments.length === 3 || segments.length === 4) &&
    segments[2] === "reviewSummaries";

  if (!isReviewRecord && !isReviewList && !isSummary) return null;

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

  if (isReviewRecord) {
    const festivalId = segments[1];
    const drinkId = segments[3];
    if (!isValidId(festivalId) || !isValidId(drinkId)) {
      return errorResponse(
        400,
        "INVALID_ARGUMENT",
        "Invalid resource name",
        "INVALID_RESOURCE_NAME",
        corsHeaders,
      );
    }
    const deviceResult = getDeviceId(request, corsHeaders);
    if (deviceResult.error) return deviceResult.error;

    switch (request.method) {
      case "GET":
        return getReview({
          db,
          bucket,
          festivalId,
          drinkId,
          deviceId: deviceResult.deviceId,
          corsHeaders,
        });
      case "PATCH":
        return upsertReview(request, {
          db,
          bucket,
          festivalId,
          drinkId,
          deviceId: deviceResult.deviceId,
          corsHeaders,
        });
      case "DELETE":
        return deleteReview({
          db,
          bucket,
          festivalId,
          drinkId,
          deviceId: deviceResult.deviceId,
          corsHeaders,
        });
      default:
        return methodNotAllowed(corsHeaders);
    }
  }

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

  if (isReviewList) {
    const deviceResult = getDeviceId(request, corsHeaders);
    if (deviceResult.error) return deviceResult.error;
    return listReviews({
      db,
      bucket,
      festivalId,
      deviceId: deviceResult.deviceId,
      url,
      corsHeaders,
    });
  }

  // isSummary
  if (segments.length === 4) {
    return getReviewSummary({
      db,
      bucket,
      festivalId,
      drinkId: segments[3],
      corsHeaders,
    });
  }
  return listReviewSummaries({ db, bucket, festivalId, url, corsHeaders });
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

function reviewName(festivalId, drinkId) {
  return `festivals/${festivalId}/drinks/${drinkId}/review`;
}

function summaryName(festivalId, drinkId) {
  return `festivals/${festivalId}/reviewSummaries/${drinkId}`;
}

function serializeReview(name, row) {
  const resource = { name, updateTime: rfc3339(row.updated_at) };
  if (row.star_rating != null) resource.starRating = row.star_rating;
  if (row.recommend != null) resource.wouldRecommend = Boolean(row.recommend);
  return resource;
}

function round1(value) {
  return Math.round(value * 10) / 10;
}

function round2(value) {
  return Math.round(value * 100) / 100;
}

function summaryFields(row) {
  const ratingCount = row.rating_count || 0;
  const responseCount = row.response_count || 0;
  const recommendCount = row.recommend_count || 0;
  return {
    ratingCount,
    averageRating: ratingCount ? round1(row.avg_rating) : 0,
    responseCount,
    recommendCount,
    recommendRate: responseCount ? round2(recommendCount / responseCount) : 0,
  };
}

async function readRow(db, bucket, festivalId, drinkId, deviceId) {
  return db
    .prepare(
      "SELECT star_rating, recommend, updated_at FROM reviews " +
        "WHERE bucket = ? AND festival_id = ? AND drink_id = ? AND device_id = ?",
    )
    .bind(bucket, festivalId, drinkId, deviceId)
    .first();
}

async function getReview(ctx) {
  const { db, bucket, festivalId, drinkId, deviceId, corsHeaders } = ctx;
  const row = await readRow(db, bucket, festivalId, drinkId, deviceId);
  if (!row) {
    return errorResponse(404, "NOT_FOUND", "No review found", "NOT_FOUND", corsHeaders);
  }
  return jsonResponse(
    serializeReview(reviewName(festivalId, drinkId), row),
    200,
    corsHeaders,
  );
}

async function upsertReview(request, ctx) {
  const { db, bucket, festivalId, drinkId, deviceId, corsHeaders } = ctx;

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
  if (body === null || typeof body !== "object") {
    return errorResponse(
      400,
      "INVALID_ARGUMENT",
      "Body must be a JSON object",
      "INVALID_BODY",
      corsHeaders,
    );
  }

  // Parse updateMask: comma-separated field names. Absent/empty = all provided fields.
  const maskRaw = body.updateMask;
  const mask =
    typeof maskRaw === "string" && maskRaw.length > 0
      ? new Set(maskRaw.split(",").map((s) => s.trim()))
      : null;

  const updateStar = mask === null ? "starRating" in body : mask.has("starRating");
  const updateRec = mask === null ? "wouldRecommend" in body : mask.has("wouldRecommend");

  if (!updateStar && !updateRec) {
    return errorResponse(
      400,
      "INVALID_ARGUMENT",
      "Provide at least one of starRating or wouldRecommend",
      "NO_FIELDS_TO_UPDATE",
      corsHeaders,
    );
  }

  let starRating;
  if (updateStar) {
    const v = body.starRating;
    if (!Number.isInteger(v) || v < 1 || v > 5) {
      return errorResponse(
        400,
        "INVALID_ARGUMENT",
        "starRating must be an integer between 1 and 5",
        "STAR_RATING_OUT_OF_RANGE",
        corsHeaders,
      );
    }
    starRating = v;
  }

  let recommend;
  if (updateRec) {
    const v = body.wouldRecommend;
    if (typeof v !== "boolean") {
      return errorResponse(
        400,
        "INVALID_ARGUMENT",
        "wouldRecommend must be a boolean",
        "WOULD_RECOMMEND_INVALID",
        corsHeaders,
      );
    }
    recommend = v ? 1 : 0;
  }

  const existing = await readRow(db, bucket, festivalId, drinkId, deviceId);
  const now = Date.now();

  if (existing) {
    await db
      .prepare(
        "UPDATE reviews SET star_rating = ?, recommend = ?, updated_at = ? " +
          "WHERE bucket = ? AND festival_id = ? AND drink_id = ? AND device_id = ?",
      )
      .bind(
        updateStar ? starRating : existing.star_rating,
        updateRec ? recommend : existing.recommend,
        now,
        bucket,
        festivalId,
        drinkId,
        deviceId,
      )
      .run();
  } else {
    await db
      .prepare(
        "INSERT INTO reviews (bucket, festival_id, drink_id, device_id, star_rating, recommend, updated_at) " +
          "VALUES (?, ?, ?, ?, ?, ?, ?)",
      )
      .bind(
        bucket,
        festivalId,
        drinkId,
        deviceId,
        updateStar ? starRating : null,
        updateRec ? recommend : null,
        now,
      )
      .run();
  }

  const row = await readRow(db, bucket, festivalId, drinkId, deviceId);
  return jsonResponse(
    serializeReview(reviewName(festivalId, drinkId), row),
    200,
    corsHeaders,
  );
}

async function deleteReview(ctx) {
  const { db, bucket, festivalId, drinkId, deviceId, corsHeaders } = ctx;
  const result = await db
    .prepare(
      "DELETE FROM reviews " +
        "WHERE bucket = ? AND festival_id = ? AND drink_id = ? AND device_id = ?",
    )
    .bind(bucket, festivalId, drinkId, deviceId)
    .run();

  const changes = result.meta ? result.meta.changes : 0;
  if (!changes) {
    return errorResponse(404, "NOT_FOUND", "No review found", "NOT_FOUND", corsHeaders);
  }
  return jsonResponse({}, 200, corsHeaders);
}

async function listReviews(ctx) {
  const { db, bucket, festivalId, deviceId, url, corsHeaders } = ctx;

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

  const where = ["bucket = ?", "festival_id = ?", "device_id = ?"];
  const binds = [bucket, festivalId, deviceId];
  if (cursor !== null) {
    where.push("drink_id > ?");
    binds.push(cursor);
  }

  const { results } = await db
    .prepare(
      "SELECT drink_id, star_rating, recommend, updated_at FROM reviews " +
        `WHERE ${where.join(" AND ")} ORDER BY drink_id LIMIT ?`,
    )
    .bind(...binds, pageSize + 1)
    .all();

  const page = results.slice(0, pageSize);
  const reviews = page.map((row) =>
    serializeReview(reviewName(festivalId, row.drink_id), row),
  );

  let nextPageToken = "";
  if (results.length > pageSize) {
    nextPageToken = encodePageToken(page[page.length - 1].drink_id);
  }

  return jsonResponse({ reviews, nextPageToken }, 200, corsHeaders);
}

async function getReviewSummary(ctx) {
  const { db, bucket, festivalId, drinkId, corsHeaders } = ctx;
  const row = await db
    .prepare(
      "SELECT " +
        "COUNT(star_rating) AS rating_count, " +
        "AVG(star_rating) AS avg_rating, " +
        "COUNT(recommend) AS response_count, " +
        "SUM(CASE WHEN recommend = 1 THEN 1 ELSE 0 END) AS recommend_count " +
        "FROM reviews WHERE bucket = ? AND festival_id = ? AND drink_id = ?",
    )
    .bind(bucket, festivalId, drinkId)
    .first();

  return jsonResponse(
    { name: summaryName(festivalId, drinkId), ...summaryFields(row || {}) },
    200,
    corsHeaders,
  );
}

async function listReviewSummaries(ctx) {
  const { db, bucket, festivalId, url, corsHeaders } = ctx;

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

  const { results } = await db
    .prepare(
      "SELECT drink_id, " +
        "COUNT(star_rating) AS rating_count, " +
        "AVG(star_rating) AS avg_rating, " +
        "COUNT(recommend) AS response_count, " +
        "SUM(CASE WHEN recommend = 1 THEN 1 ELSE 0 END) AS recommend_count " +
        "FROM reviews " +
        `WHERE ${where.join(" AND ")} GROUP BY drink_id ORDER BY drink_id LIMIT ?`,
    )
    .bind(...binds, pageSize + 1)
    .all();

  const page = results.slice(0, pageSize);
  const reviewSummaries = page.map((row) => ({
    name: summaryName(festivalId, row.drink_id),
    ...summaryFields(row),
  }));

  let nextPageToken = "";
  if (results.length > pageSize) {
    nextPageToken = encodePageToken(page[page.length - 1].drink_id);
  }

  const totalRow = await db
    .prepare(
      "SELECT COUNT(DISTINCT drink_id) AS n FROM reviews WHERE bucket = ? AND festival_id = ?",
    )
    .bind(bucket, festivalId)
    .first();

  return jsonResponse(
    {
      reviewSummaries,
      nextPageToken,
      totalSize: totalRow ? totalRow.n : 0,
    },
    200,
    corsHeaders,
  );
}
