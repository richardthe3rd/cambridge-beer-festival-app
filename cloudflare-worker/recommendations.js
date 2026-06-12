/**
 * Recommendations resource family for the /v1 API (AIP resource-oriented).
 *
 *   GET    /v1/festivals/{f}/drinks/{d}/recommendations/{device}   get my answer
 *   PATCH  /v1/festivals/{f}/drinks/{d}/recommendations/{device}   upsert my answer
 *   DELETE /v1/festivals/{f}/drinks/{d}/recommendations/{device}   remove my answer
 *   GET    /v1/festivals/{f}/recommendationSummaries/{d}            aggregate for a drink
 *   GET    /v1/festivals/{f}/recommendationSummaries                list (paginated)
 *
 * A yes/no signal separate from the star rating, surfacing a "% would
 * recommend". Backed by the `recommendations` table (`recommend` stored as 0/1).
 */

import { handleResourceFamily, rfc3339 } from "./shared.js";

function round2(value) {
  return Math.round(value * 100) / 100;
}

export const RECOMMENDATIONS_FAMILY = {
  table: "recommendations",
  valueColumn: "recommend",
  writeCollection: "recommendations",
  summaryCollection: "recommendationSummaries",

  /** Validate the Recommendation body { wouldRecommend: bool }. */
  parseValue(body) {
    if (body === null || typeof body !== "object") {
      return {
        ok: false,
        reason: "INVALID_BODY",
        message: "Body must be a JSON object",
      };
    }
    const { wouldRecommend } = body;
    if (typeof wouldRecommend !== "boolean") {
      return {
        ok: false,
        reason: "RECOMMENDATION_VALUE_INVALID",
        message: "wouldRecommend must be a boolean",
      };
    }
    return { ok: true, columnValue: wouldRecommend ? 1 : 0 };
  },

  /** Serialize a Recommendation resource from a DB row { value, updated_at }. */
  serializeResource(name, row) {
    return {
      name,
      wouldRecommend: Boolean(row.value),
      updateTime: rfc3339(row.updated_at),
    };
  },

  summaryColumns: "COUNT(*) AS agg_count, SUM(recommend) AS agg_yes",

  /** Build RecommendationSummary fields from an aggregate row. */
  summaryFields(row) {
    const count = row.agg_count || 0;
    const yes = row.agg_yes != null ? row.agg_yes : 0;
    return {
      responseCount: count,
      recommendCount: yes,
      recommendRate: count ? round2(yes / count) : 0,
    };
  },
};

/** Route a recommendations request, or null if not a recommendations path. */
export function handleRecommendations(request, url, env, corsHeaders) {
  return handleResourceFamily(
    request,
    url,
    env,
    corsHeaders,
    RECOMMENDATIONS_FAMILY,
  );
}
