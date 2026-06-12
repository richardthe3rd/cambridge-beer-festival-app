/**
 * Ratings resource family for the /v1 API (AIP resource-oriented).
 *
 *   GET    /v1/festivals/{f}/drinks/{d}/ratings/{device}   get my rating
 *   PATCH  /v1/festivals/{f}/drinks/{d}/ratings/{device}   upsert my rating
 *   DELETE /v1/festivals/{f}/drinks/{d}/ratings/{device}   remove my rating
 *   GET    /v1/festivals/{f}/ratingSummaries/{d}            aggregate for a drink
 *   GET    /v1/festivals/{f}/ratingSummaries                list (paginated)
 *
 * Backed by the `ratings` table in D1. Writes are local-first on the client.
 */

import { handleResourceFamily, rfc3339 } from "./shared.js";

function round1(value) {
  return Math.round(value * 10) / 10;
}

export const RATINGS_FAMILY = {
  table: "ratings",
  valueColumn: "rating",
  writeCollection: "ratings",
  summaryCollection: "ratingSummaries",

  /** Validate the Rating body { value: 1..5 }. */
  parseValue(body) {
    if (body === null || typeof body !== "object") {
      return {
        ok: false,
        reason: "INVALID_BODY",
        message: "Body must be a JSON object",
      };
    }
    const { value } = body;
    if (!Number.isInteger(value) || value < 1 || value > 5) {
      return {
        ok: false,
        reason: "RATING_VALUE_OUT_OF_RANGE",
        message: "value must be an integer between 1 and 5",
      };
    }
    return { ok: true, columnValue: value };
  },

  /** Serialize a Rating resource from a DB row { value, updated_at }. */
  serializeResource(name, row) {
    return { name, value: row.value, updateTime: rfc3339(row.updated_at) };
  },

  // Aggregate columns selected for summary single + list queries.
  summaryColumns: "COUNT(*) AS agg_count, AVG(rating) AS agg_average",

  /** Build RatingSummary fields from an aggregate row. */
  summaryFields(row) {
    const count = row.agg_count || 0;
    return {
      ratingCount: count,
      averageRating: count ? round1(row.agg_average) : 0,
    };
  },
};

/** Route a ratings request, or null if the path is not a ratings path. */
export function handleRatings(request, url, env, corsHeaders) {
  return handleResourceFamily(request, url, env, corsHeaders, RATINGS_FAMILY);
}
