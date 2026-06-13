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
 * Response shapes are typed against the generated OpenAPI types in
 * src/api-types.ts (generated from proto via proto:clients:types). TypeScript
 * enforces that every response field matches the proto contract — a field
 * rename in the proto surfaces here as a compile error.
 *
 * Caller identity comes from the X-Device-Id request header (anonymous phase).
 * It never appears in resource names, so the sign-in upgrade is transparent.
 */

import type { components } from "./src/api-types";
import {
  type CorsHeaders,
  type Env,
  resolveBucket,
  rfc3339,
  jsonResponse,
  errorResponse,
  encodePageToken,
  decodePageToken,
  resolvePageSize,
} from "./shared.js";

// Response shapes enforced by the proto contract.
type Review = components["schemas"]["Review"];
type ReviewSummary = components["schemas"]["ReviewSummary"];
type ListReviewsResponse = components["schemas"]["ListReviewsResponse"];
type ListReviewSummariesResponse =
  components["schemas"]["ListReviewSummariesResponse"];

const MAX_ID_LENGTH = 200;

// D1 row shapes returned by SQL queries.
interface ReviewRow {
  star_rating: number | null;
  recommend: number | null;
  updated_at: number;
}
interface ReviewListRow extends ReviewRow {
  drink_id: string;
}
interface SummaryRow {
  rating_count: number;
  avg_rating: number | null;
  response_count: number;
  recommend_count: number | null;
  drink_id?: string;
}
interface TotalRow {
  n: number;
}

interface ReviewCtx {
  db: D1Database;
  bucket: string;
  festivalId: string;
  drinkId: string;
  deviceId: string;
  corsHeaders: CorsHeaders;
}
interface SummaryCtx {
  db: D1Database;
  bucket: string;
  festivalId: string;
  drinkId: string;
  corsHeaders: CorsHeaders;
}
interface ListCtx {
  db: D1Database;
  bucket: string;
  festivalId: string;
  deviceId: string;
  url: URL;
  corsHeaders: CorsHeaders;
}
interface ListSummaryCtx {
  db: D1Database;
  bucket: string;
  festivalId: string;
  url: URL;
  corsHeaders: CorsHeaders;
}

function isValidId(value: string | null): value is string {
  return (
    typeof value === "string" &&
    value.length > 0 &&
    value.length <= MAX_ID_LENGTH
  );
}

function getDeviceId(
  request: Request,
  corsHeaders: CorsHeaders,
): { deviceId: string } | { error: Response } {
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

function parseV1alphaPath(pathname: string): string[] | null {
  if (pathname !== "/v1alpha" && !pathname.startsWith("/v1alpha/")) return null;
  return pathname
    .slice("/v1alpha/".length)
    .split("/")
    .filter((s) => s.length > 0)
    .map((s) => decodeURIComponent(s));
}

/** Route a request, or return null if the path doesn't match any review route. */
export async function handleReviews(
  request: Request,
  url: URL,
  env: Env,
  corsHeaders: CorsHeaders,
): Promise<Response | null> {
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

  if (!env?.RATINGS_DB) {
    return errorResponse(
      503,
      "UNAVAILABLE",
      "Storage is not configured",
      "STORAGE_UNCONFIGURED",
      corsHeaders,
    );
  }

  const origin = request.headers.get("Origin") ?? "";
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
    if ("error" in deviceResult) return deviceResult.error;

    switch (request.method) {
      case "GET":
        return getReview({ db, bucket, festivalId, drinkId, deviceId: deviceResult.deviceId, corsHeaders });
      case "PATCH":
        return upsertReview(request, { db, bucket, festivalId, drinkId, deviceId: deviceResult.deviceId, corsHeaders });
      case "DELETE":
        return deleteReview({ db, bucket, festivalId, drinkId, deviceId: deviceResult.deviceId, corsHeaders });
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
    if ("error" in deviceResult) return deviceResult.error;
    return listReviews({ db, bucket, festivalId, deviceId: deviceResult.deviceId, url, corsHeaders });
  }

  // isSummary
  if (segments.length === 4) {
    const drinkId = segments[3];
    if (!isValidId(drinkId)) {
      return errorResponse(
        400,
        "INVALID_ARGUMENT",
        "Invalid resource name",
        "INVALID_RESOURCE_NAME",
        corsHeaders,
      );
    }
    return getReviewSummary({ db, bucket, festivalId, drinkId, corsHeaders });
  }
  return listReviewSummaries({ db, bucket, festivalId, url, corsHeaders });
}

function methodNotAllowed(corsHeaders: CorsHeaders): Response {
  return errorResponse(
    405,
    "UNIMPLEMENTED",
    "Method not allowed for this resource",
    "METHOD_NOT_ALLOWED",
    corsHeaders,
  );
}

function reviewName(festivalId: string, drinkId: string): string {
  return `festivals/${festivalId}/drinks/${drinkId}/review`;
}

function summaryName(festivalId: string, drinkId: string): string {
  return `festivals/${festivalId}/reviewSummaries/${drinkId}`;
}

function serializeReview(name: string, row: ReviewRow): Review {
  const resource: Review = { name, updateTime: rfc3339(row.updated_at) };
  if (row.star_rating != null) resource.starRating = row.star_rating;
  if (row.recommend != null) resource.wouldRecommend = Boolean(row.recommend);
  return resource;
}

function round1(value: number): number {
  return Math.round(value * 10) / 10;
}

function round2(value: number): number {
  return Math.round(value * 100) / 100;
}

function summaryFields(row: Partial<SummaryRow>): Omit<ReviewSummary, "name"> {
  const ratingCount = row.rating_count ?? 0;
  const responseCount = row.response_count ?? 0;
  const recommendCount = row.recommend_count ?? 0;
  return {
    ratingCount,
    averageRating: ratingCount && row.avg_rating != null ? round1(row.avg_rating) : 0,
    responseCount,
    recommendCount,
    recommendRate: responseCount ? round2(recommendCount / responseCount) : 0,
  };
}

async function readRow(
  db: D1Database,
  bucket: string,
  festivalId: string,
  drinkId: string,
  deviceId: string,
): Promise<ReviewRow | null> {
  return db
    .prepare(
      "SELECT star_rating, recommend, updated_at FROM reviews " +
        "WHERE bucket = ? AND festival_id = ? AND drink_id = ? AND device_id = ?",
    )
    .bind(bucket, festivalId, drinkId, deviceId)
    .first<ReviewRow>();
}

async function getReview(ctx: ReviewCtx): Promise<Response> {
  const { db, bucket, festivalId, drinkId, deviceId, corsHeaders } = ctx;
  const row = await readRow(db, bucket, festivalId, drinkId, deviceId);
  if (!row) {
    return errorResponse(404, "NOT_FOUND", "No review found", "NOT_FOUND", corsHeaders);
  }
  return jsonResponse<Review>(
    serializeReview(reviewName(festivalId, drinkId), row),
    200,
    corsHeaders,
  );
}

async function upsertReview(request: Request, ctx: ReviewCtx): Promise<Response> {
  const { db, bucket, festivalId, drinkId, deviceId, corsHeaders } = ctx;

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return errorResponse(400, "INVALID_ARGUMENT", "Invalid JSON body", "INVALID_BODY", corsHeaders);
  }
  if (body === null || typeof body !== "object") {
    return errorResponse(400, "INVALID_ARGUMENT", "Body must be a JSON object", "INVALID_BODY", corsHeaders);
  }

  // Parse updateMask: comma-separated field names. Absent/empty = all provided fields.
  const KNOWN_FIELDS = new Set(["starRating", "wouldRecommend"]);
  const patch = body as Record<string, unknown>;
  const maskRaw = patch.updateMask;
  let mask: Set<string> | null = null;
  if (typeof maskRaw === "string" && maskRaw.length > 0) {
    const fields = maskRaw.split(",").map((s) => s.trim());
    const unknown = fields.filter((f) => !KNOWN_FIELDS.has(f));
    if (unknown.length > 0) {
      return errorResponse(
        400,
        "INVALID_ARGUMENT",
        `Unknown updateMask field(s): ${unknown.join(", ")}`,
        "UNKNOWN_FIELD_MASK",
        corsHeaders,
      );
    }
    mask = new Set(fields);
  }

  const updateStar = mask === null ? "starRating" in patch : mask.has("starRating");
  const updateRec = mask === null ? "wouldRecommend" in patch : mask.has("wouldRecommend");

  if (!updateStar && !updateRec) {
    return errorResponse(
      400,
      "INVALID_ARGUMENT",
      "Provide at least one of starRating or wouldRecommend",
      "NO_FIELDS_TO_UPDATE",
      corsHeaders,
    );
  }

  let starRating: number | undefined;
  if (updateStar) {
    const v = patch.starRating;
    if (!Number.isInteger(v) || (v as number) < 1 || (v as number) > 5) {
      return errorResponse(
        400,
        "INVALID_ARGUMENT",
        "starRating must be an integer between 1 and 5",
        "STAR_RATING_OUT_OF_RANGE",
        corsHeaders,
      );
    }
    starRating = v as number;
  }

  let recommend: number | undefined;
  if (updateRec) {
    const v = patch.wouldRecommend;
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

  // Compute the final column values upfront so we can build the response
  // without a second DB read — avoids a round trip and the race where a
  // concurrent DELETE between write and re-read would make row! throw.
  const finalStarRating = updateStar ? (starRating ?? null) : (existing?.star_rating ?? null);
  const finalRecommend = updateRec ? (recommend ?? null) : (existing?.recommend ?? null);

  if (existing) {
    await db
      .prepare(
        "UPDATE reviews SET star_rating = ?, recommend = ?, updated_at = ? " +
          "WHERE bucket = ? AND festival_id = ? AND drink_id = ? AND device_id = ?",
      )
      .bind(finalStarRating, finalRecommend, now, bucket, festivalId, drinkId, deviceId)
      .run();
  } else {
    await db
      .prepare(
        "INSERT INTO reviews (bucket, festival_id, drink_id, device_id, star_rating, recommend, updated_at) " +
          "VALUES (?, ?, ?, ?, ?, ?, ?)",
      )
      .bind(bucket, festivalId, drinkId, deviceId, finalStarRating, finalRecommend, now)
      .run();
  }

  return jsonResponse<Review>(
    serializeReview(reviewName(festivalId, drinkId), {
      star_rating: finalStarRating,
      recommend: finalRecommend,
      updated_at: now,
    }),
    200,
    corsHeaders,
  );
}

async function deleteReview(ctx: ReviewCtx): Promise<Response> {
  const { db, bucket, festivalId, drinkId, deviceId, corsHeaders } = ctx;
  const result = await db
    .prepare(
      "DELETE FROM reviews " +
        "WHERE bucket = ? AND festival_id = ? AND drink_id = ? AND device_id = ?",
    )
    .bind(bucket, festivalId, drinkId, deviceId)
    .run();

  const changes = result.meta?.changes ?? 0;
  if (!changes) {
    return errorResponse(404, "NOT_FOUND", "No review found", "NOT_FOUND", corsHeaders);
  }
  return jsonResponse({}, 200, corsHeaders);
}

async function listReviews(ctx: ListCtx): Promise<Response> {
  const { db, bucket, festivalId, deviceId, url, corsHeaders } = ctx;

  const sizeResult = resolvePageSize(url.searchParams.get("page_size"));
  if ("error" in sizeResult) {
    return errorResponse(400, "INVALID_ARGUMENT", "page_size must be >= 0", "INVALID_PAGE_SIZE", corsHeaders);
  }
  const pageSize = sizeResult.value;

  const cursor = decodePageToken(url.searchParams.get("page_token"));
  if (cursor === undefined) {
    return errorResponse(400, "INVALID_ARGUMENT", "Invalid page_token", "INVALID_PAGE_TOKEN", corsHeaders);
  }

  const where = ["bucket = ?", "festival_id = ?", "device_id = ?"];
  const binds: unknown[] = [bucket, festivalId, deviceId];
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
    .all<ReviewListRow>();

  const page = results.slice(0, pageSize);
  const reviews: Review[] = page.map((row) =>
    serializeReview(reviewName(festivalId, row.drink_id), row),
  );

  let nextPageToken = "";
  if (results.length > pageSize) {
    nextPageToken = encodePageToken(page[page.length - 1].drink_id);
  }

  return jsonResponse<ListReviewsResponse>(
    { reviews, nextPageToken },
    200,
    corsHeaders,
  );
}

async function getReviewSummary(ctx: SummaryCtx): Promise<Response> {
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
    .first<SummaryRow>();

  return jsonResponse<ReviewSummary>(
    { name: summaryName(festivalId, drinkId), ...summaryFields(row ?? {}) },
    200,
    corsHeaders,
  );
}

async function listReviewSummaries(ctx: ListSummaryCtx): Promise<Response> {
  const { db, bucket, festivalId, url, corsHeaders } = ctx;

  const sizeResult = resolvePageSize(url.searchParams.get("page_size"));
  if ("error" in sizeResult) {
    return errorResponse(400, "INVALID_ARGUMENT", "page_size must be >= 0", "INVALID_PAGE_SIZE", corsHeaders);
  }
  const pageSize = sizeResult.value;

  const cursor = decodePageToken(url.searchParams.get("page_token"));
  if (cursor === undefined) {
    return errorResponse(400, "INVALID_ARGUMENT", "Invalid page_token", "INVALID_PAGE_TOKEN", corsHeaders);
  }

  const where = ["bucket = ?", "festival_id = ?"];
  const binds: unknown[] = [bucket, festivalId];
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
    .all<SummaryRow & { drink_id: string }>();

  const page = results.slice(0, pageSize);
  const reviewSummaries: ReviewSummary[] = page.map((row) => ({
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
    .first<TotalRow>();

  return jsonResponse<ListReviewSummariesResponse>(
    {
      reviewSummaries,
      nextPageToken,
      totalSize: totalRow?.n ?? 0,
    },
    200,
    corsHeaders,
  );
}
