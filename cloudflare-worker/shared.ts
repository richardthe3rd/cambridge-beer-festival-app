/**
 * Shared utilities for the /v1alpha "my festival" API.
 *
 * Bucket resolution, structured error responses (AIP-193), and opaque keyset
 * page tokens (AIP-158).
 */

const DEFAULT_PAGE_SIZE = 100;
const MAX_PAGE_SIZE = 1000;
const ERROR_DOMAIN = "cambeerfestival.app";

export type CorsHeaders = Record<string, string>;

export interface Env {
  RATINGS_DB: D1Database;
  RATINGS_BUCKET?: string;
}

export function isProductionOrigin(origin: string): boolean {
  return origin === "https://cambeerfestival.app";
}

export function resolveBucket(origin: string, env: Partial<Env>): string {
  if (env && typeof env.RATINGS_BUCKET === "string" && env.RATINGS_BUCKET) {
    return env.RATINGS_BUCKET;
  }
  return isProductionOrigin(origin) ? "prod" : "test";
}

export function rfc3339(epochMillis: number): string {
  return new Date(epochMillis).toISOString();
}

// --- Responses (AIP-193) ---------------------------------------------------

export function jsonResponse<T>(
  body: T,
  status: number,
  corsHeaders: CorsHeaders,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      ...corsHeaders,
    },
  });
}

interface ErrorInfo {
  "@type": string;
  reason: string;
  domain: string;
  metadata?: Record<string, string>;
}

interface ErrorBody {
  error: {
    code: number;
    message: string;
    status: string;
    details: ErrorInfo[];
  };
}

/** Structured error body per AIP-193 (google.rpc.Status + ErrorInfo). */
export function errorResponse(
  httpCode: number,
  status: string,
  message: string,
  reason: string,
  corsHeaders: CorsHeaders,
  metadata?: Record<string, string>,
): Response {
  const errorInfo: ErrorInfo = {
    "@type": "type.googleapis.com/google.rpc.ErrorInfo",
    reason,
    domain: ERROR_DOMAIN,
  };
  if (metadata) errorInfo.metadata = metadata;
  const body: ErrorBody = {
    error: { code: httpCode, message, status, details: [errorInfo] },
  };
  return jsonResponse(body, httpCode, corsHeaders);
}

// --- Pagination (AIP-158) --------------------------------------------------

/** Encode a keyset cursor (last drink id) as an opaque URL-safe token. */
export function encodePageToken(drinkId: string): string {
  return btoa(unescape(encodeURIComponent(drinkId)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

/** Decode a page token back to its cursor, or null if absent. */
export function decodePageToken(
  token: string | null,
): string | null | undefined {
  if (!token) return null;
  try {
    const b64 = token.replace(/-/g, "+").replace(/_/g, "/");
    return decodeURIComponent(escape(atob(b64)));
  } catch {
    return undefined; // signal "invalid token"
  }
}

/** Resolve an effective page size, or { error } for a bad value. */
export function resolvePageSize(
  raw: string | null,
): { value: number } | { error: true } {
  if (raw == null || raw === "") return { value: DEFAULT_PAGE_SIZE };
  const n = Number(raw);
  if (!Number.isInteger(n) || n < 0) return { error: true };
  if (n === 0) return { value: DEFAULT_PAGE_SIZE };
  return { value: Math.min(n, MAX_PAGE_SIZE) };
}
