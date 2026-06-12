/**
 * Shared helpers for the /v1 "my festival" APIs (ratings, recommendations, …).
 *
 * These resources are structurally identical — a device upserts a signal for a
 * drink and reads back a bucket-scoped aggregate — so the bucket resolution,
 * id validation, JSON plumbing and REST routing live here once.
 */

export const MAX_ID_LENGTH = 200;

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

export function isValidId(value) {
  return (
    typeof value === "string" &&
    value.length > 0 &&
    value.length <= MAX_ID_LENGTH
  );
}

/**
 * Validate the identity fields every write shares. Returns
 * { ok: true, value: { festivalId, drinkId, deviceId } } or { ok: false, error }.
 */
export function validateIds(body) {
  if (body === null || typeof body !== "object") {
    return { ok: false, error: "Request body must be a JSON object" };
  }
  const { festivalId, drinkId, deviceId } = body;
  if (!isValidId(festivalId)) {
    return { ok: false, error: "festivalId is required" };
  }
  if (!isValidId(drinkId)) {
    return { ok: false, error: "drinkId is required" };
  }
  if (!isValidId(deviceId)) {
    return { ok: false, error: "deviceId is required" };
  }
  return { ok: true, value: { festivalId, drinkId, deviceId } };
}

export function jsonResponse(body, status, corsHeaders) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      ...corsHeaders,
    },
  });
}

export async function parseJsonBody(request) {
  try {
    return { ok: true, body: await request.json() };
  } catch {
    return { ok: false };
  }
}

/**
 * Route a REST request for a /v1 resource. Returns a Response, or null if the
 * path is not for this resource (so the caller can fall through).
 *
 * Routes:
 *   POST   {basePath}                       -> handlers.post(request, db, bucket, cors)
 *   DELETE {basePath}                       -> handlers.del(request, db, bucket, cors)
 *   GET    {basePath}/{festivalId}          -> handlers.getFestival(db, bucket, festivalId, deviceId, cors)
 *   GET    {basePath}/{festivalId}/{drinkId}-> handlers.getSingle(db, bucket, festivalId, drinkId, deviceId, cors)
 */
export async function routeResource(request, url, env, corsHeaders, handlers) {
  const { basePath, db: dbBinding } = handlers;
  const prefix = `${basePath}/`;
  if (url.pathname !== basePath && !url.pathname.startsWith(prefix)) {
    return null;
  }

  if (!env || !env[dbBinding]) {
    return jsonResponse(
      { error: "Storage is not configured" },
      503,
      corsHeaders,
    );
  }

  const origin = request.headers.get("Origin") || "";
  const bucket = resolveBucket(origin, env);
  const db = env[dbBinding];

  if (url.pathname === basePath) {
    if (request.method === "POST") {
      return handlers.post(request, db, bucket, corsHeaders);
    }
    if (request.method === "DELETE") {
      return handlers.del(request, db, bucket, corsHeaders);
    }
    return jsonResponse({ error: "Method not allowed" }, 405, corsHeaders);
  }

  if (request.method !== "GET") {
    return jsonResponse({ error: "Method not allowed" }, 405, corsHeaders);
  }

  const segments = url.pathname
    .slice(prefix.length)
    .split("/")
    .filter((s) => s.length > 0)
    .map((s) => decodeURIComponent(s));
  const deviceId = url.searchParams.get("deviceId") || null;

  if (segments.length === 1) {
    return handlers.getFestival(db, bucket, segments[0], deviceId, corsHeaders);
  }
  if (segments.length === 2) {
    return handlers.getSingle(
      db,
      bucket,
      segments[0],
      segments[1],
      deviceId,
      corsHeaders,
    );
  }

  return jsonResponse({ error: "Not found" }, 404, corsHeaders);
}
