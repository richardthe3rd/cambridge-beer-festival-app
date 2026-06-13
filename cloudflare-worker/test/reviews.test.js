import { describe, it, expect, beforeEach } from "vitest";
import {
  env,
  createExecutionContext,
  waitOnExecutionContext,
} from "cloudflare:test";
import worker from "../worker.js";
import {
  isProductionOrigin,
  resolveBucket,
  resolvePageSize,
  encodePageToken,
  decodePageToken,
} from "../shared.js";

const TEST_ORIGIN = "http://localhost:8080"; // non-prod → 'test' bucket
const PROD_ORIGIN = "https://cambeerfestival.app"; // → 'prod' bucket
const DEVICE = "dev-1";

async function send(
  method,
  path,
  { body, origin = TEST_ORIGIN, device = DEVICE } = {},
) {
  const init = {
    method,
    headers: { Origin: origin, "X-Device-Id": device },
  };
  if (body !== undefined) {
    init.headers["Content-Type"] = "application/json";
    init.body = typeof body === "string" ? body : JSON.stringify(body);
  }
  const request = new Request(`https://worker.example.com${path}`, init);
  const ctx = createExecutionContext();
  const response = await worker.fetch(request, env, ctx);
  await waitOnExecutionContext(ctx);
  return response;
}

const reviewPath = (f, d) => `/v1alpha/festivals/${f}/drinks/${d}/review`;
const patch = (f, d, body, opts) =>
  send("PATCH", reviewPath(f, d), { body, ...opts });

beforeEach(async () => {
  await env.RATINGS_DB.prepare("DELETE FROM reviews").run();
});

// ---------------------------------------------------------------------------
// Pure helpers
// ---------------------------------------------------------------------------

describe("shared — pure helpers", () => {
  it("resolves the bucket from origin, with override", () => {
    expect(isProductionOrigin(PROD_ORIGIN)).toBe(true);
    expect(resolveBucket(PROD_ORIGIN, {})).toBe("prod");
    expect(resolveBucket(TEST_ORIGIN, {})).toBe("test");
    expect(resolveBucket(PROD_ORIGIN, { RATINGS_BUCKET: "test" })).toBe("test");
  });

  it("resolvePageSize applies defaults, caps, and rejects negatives", () => {
    expect(resolvePageSize(null).value).toBe(100);
    expect(resolvePageSize("").value).toBe(100);
    expect(resolvePageSize("0").value).toBe(100);
    expect(resolvePageSize("25").value).toBe(25);
    expect(resolvePageSize("9999").value).toBe(1000);
    expect(resolvePageSize("-1").error).toBe(true);
  });

  it("page tokens round-trip and reject garbage", () => {
    expect(decodePageToken(encodePageToken("beer-1"))).toBe("beer-1");
    expect(decodePageToken("")).toBe(null);
    expect(decodePageToken(null)).toBe(null);
    expect(decodePageToken("!!!not-base64!!!")).toBe(undefined);
  });
});

// ---------------------------------------------------------------------------
// PATCH — upsert
// ---------------------------------------------------------------------------

describe("reviews — PATCH (upsert)", () => {
  it("creates a review with starRating and returns the resource", async () => {
    const response = await patch("cbf2025", "beer-1", { starRating: 4 });
    expect(response.status).toBe(200);
    const data = await response.json();
    expect(data.name).toBe("festivals/cbf2025/drinks/beer-1/review");
    expect(data.starRating).toBe(4);
    expect(data.wouldRecommend).toBeUndefined();
    expect(typeof data.updateTime).toBe("string");
    expect(Number.isNaN(Date.parse(data.updateTime))).toBe(false);
  });

  it("creates a review with wouldRecommend only", async () => {
    const response = await patch("cbf2025", "beer-1", { wouldRecommend: true });
    expect(response.status).toBe(200);
    const data = await response.json();
    expect(data.wouldRecommend).toBe(true);
    expect(data.starRating).toBeUndefined();
  });

  it("creates a review with both signals at once", async () => {
    const response = await patch("cbf2025", "beer-1", {
      starRating: 3,
      wouldRecommend: false,
    });
    const data = await response.json();
    expect(data.starRating).toBe(3);
    expect(data.wouldRecommend).toBe(false);
  });

  it("updateMask restricts which field is written", async () => {
    // Set both signals first
    await patch("cbf2025", "beer-1", { starRating: 2, wouldRecommend: true });
    // Update only starRating — wouldRecommend must survive
    const response = await patch("cbf2025", "beer-1", {
      starRating: 5,
      wouldRecommend: false,
      updateMask: "starRating",
    });
    const data = await response.json();
    expect(data.starRating).toBe(5);
    expect(data.wouldRecommend).toBe(true); // unchanged
  });

  it("re-rating updates in place without inflating aggregates", async () => {
    await patch("cbf2025", "beer-1", { starRating: 2 });
    await patch("cbf2025", "beer-1", { starRating: 5 });
    const summary = await send(
      "GET",
      "/v1alpha/festivals/cbf2025/reviewSummaries/beer-1",
    );
    const data = await summary.json();
    expect(data.ratingCount).toBe(1);
    expect(data.averageRating).toBe(5);
  });

  it("rejects an out-of-range starRating with a structured error", async () => {
    const response = await patch("cbf2025", "beer-1", { starRating: 9 });
    expect(response.status).toBe(400);
    const { error } = await response.json();
    expect(error.status).toBe("INVALID_ARGUMENT");
    expect(error.details[0].reason).toBe("STAR_RATING_OUT_OF_RANGE");
    expect(error.details[0].domain).toBe("cambeerfestival.app");
  });

  it("rejects a non-boolean wouldRecommend", async () => {
    const response = await patch("cbf2025", "beer-1", { wouldRecommend: "yes" });
    expect(response.status).toBe(400);
    expect((await response.json()).error.details[0].reason).toBe(
      "WOULD_RECOMMEND_INVALID",
    );
  });

  it("rejects a body with no recognised fields", async () => {
    const response = await patch("cbf2025", "beer-1", { something: "else" });
    expect(response.status).toBe(400);
    expect((await response.json()).error.details[0].reason).toBe(
      "NO_FIELDS_TO_UPDATE",
    );
  });

  it("rejects malformed JSON", async () => {
    const response = await send("PATCH", reviewPath("cbf2025", "beer-1"), {
      body: "{not json",
    });
    expect(response.status).toBe(400);
    expect((await response.json()).error.details[0].reason).toBe("INVALID_BODY");
  });
});

// ---------------------------------------------------------------------------
// GET / DELETE
// ---------------------------------------------------------------------------

describe("reviews — GET and DELETE", () => {
  it("gets a review back after creating it", async () => {
    await patch("cbf2025", "beer-1", { starRating: 3, wouldRecommend: true });
    const response = await send("GET", reviewPath("cbf2025", "beer-1"));
    expect(response.status).toBe(200);
    const data = await response.json();
    expect(data.starRating).toBe(3);
    expect(data.wouldRecommend).toBe(true);
  });

  it("returns 404 for a missing review", async () => {
    const response = await send("GET", reviewPath("cbf2025", "beer-ghost"));
    expect(response.status).toBe(404);
    expect((await response.json()).error.status).toBe("NOT_FOUND");
  });

  it("deletes a review then reads 404", async () => {
    await patch("cbf2025", "beer-1", { starRating: 4 });
    const del = await send("DELETE", reviewPath("cbf2025", "beer-1"));
    expect(del.status).toBe(200);
    expect(await del.json()).toEqual({});
    const after = await send("GET", reviewPath("cbf2025", "beer-1"));
    expect(after.status).toBe(404);
  });

  it("deleting a missing review is 404 (AIP-135)", async () => {
    const response = await send("DELETE", reviewPath("cbf2025", "beer-ghost"));
    expect(response.status).toBe(404);
  });
});

// ---------------------------------------------------------------------------
// List reviews (caller's own)
// ---------------------------------------------------------------------------

describe("reviews — list caller reviews", () => {
  it("lists reviews for the caller only", async () => {
    await patch("cbf2025", "beer-1", { starRating: 4 });
    await patch("cbf2025", "beer-2", { wouldRecommend: true });
    // Different device — should not appear
    await patch("cbf2025", "beer-3", { starRating: 2 }, { device: "dev-other" });

    const response = await send(
      "GET",
      "/v1alpha/festivals/cbf2025/reviews",
    );
    expect(response.status).toBe(200);
    const data = await response.json();
    expect(data.reviews).toHaveLength(2);
    const names = data.reviews.map((r) => r.name);
    expect(names).toContain("festivals/cbf2025/drinks/beer-1/review");
    expect(names).toContain("festivals/cbf2025/drinks/beer-2/review");
  });

  it("returns empty list when caller has no reviews", async () => {
    const response = await send("GET", "/v1alpha/festivals/cbf2025/reviews");
    const data = await response.json();
    expect(data.reviews).toHaveLength(0);
    expect(data.nextPageToken).toBe("");
  });
});

// ---------------------------------------------------------------------------
// Review summaries
// ---------------------------------------------------------------------------

describe("reviews — summaries", () => {
  it("aggregates starRating across devices", async () => {
    await patch("cbf2025", "beer-1", { starRating: 4 }, { device: "d1" });
    await patch("cbf2025", "beer-1", { starRating: 5 }, { device: "d2" });
    await patch("cbf2025", "beer-1", { starRating: 3 }, { device: "d3" });
    const response = await send(
      "GET",
      "/v1alpha/festivals/cbf2025/reviewSummaries/beer-1",
    );
    const data = await response.json();
    expect(data.name).toBe("festivals/cbf2025/reviewSummaries/beer-1");
    expect(data.ratingCount).toBe(3);
    expect(data.averageRating).toBe(4);
  });

  it("aggregates wouldRecommend across devices", async () => {
    await patch("cbf2025", "beer-1", { wouldRecommend: true }, { device: "d1" });
    await patch("cbf2025", "beer-1", { wouldRecommend: true }, { device: "d2" });
    await patch("cbf2025", "beer-1", { wouldRecommend: false }, { device: "d3" });
    const data = await (
      await send("GET", "/v1alpha/festivals/cbf2025/reviewSummaries/beer-1")
    ).json();
    expect(data.responseCount).toBe(3);
    expect(data.recommendCount).toBe(2);
    expect(data.recommendRate).toBe(0.67);
  });

  it("counts rating and recommendation independently when only one signal is set", async () => {
    // d1 sets both; d2 sets only starRating
    await patch("cbf2025", "beer-1", { starRating: 4, wouldRecommend: true }, { device: "d1" });
    await patch("cbf2025", "beer-1", { starRating: 2 }, { device: "d2" });
    const data = await (
      await send("GET", "/v1alpha/festivals/cbf2025/reviewSummaries/beer-1")
    ).json();
    expect(data.ratingCount).toBe(2);
    expect(data.responseCount).toBe(1); // only d1 answered recommendation
  });

  it("returns zero summary for a drink with no reviews", async () => {
    const response = await send(
      "GET",
      "/v1alpha/festivals/cbf2025/reviewSummaries/never",
    );
    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({
      ratingCount: 0,
      averageRating: 0,
      responseCount: 0,
      recommendCount: 0,
      recommendRate: 0,
    });
  });

  it("lists summaries with total size", async () => {
    await patch("cbf2025", "beer-1", { starRating: 4 }, { device: "d1" });
    await patch("cbf2025", "beer-2", { wouldRecommend: false }, { device: "d1" });
    const response = await send(
      "GET",
      "/v1alpha/festivals/cbf2025/reviewSummaries",
    );
    const data = await response.json();
    expect(data.totalSize).toBe(2);
    expect(data.nextPageToken).toBe("");
    expect(data.reviewSummaries.map((s) => s.name)).toEqual([
      "festivals/cbf2025/reviewSummaries/beer-1",
      "festivals/cbf2025/reviewSummaries/beer-2",
    ]);
  });

  it("paginates summaries with opaque tokens", async () => {
    for (const d of ["beer-1", "beer-2", "beer-3"]) {
      await patch("cbf2025", d, { starRating: 4 }, { device: "d1" });
    }
    const first = await (
      await send(
        "GET",
        "/v1alpha/festivals/cbf2025/reviewSummaries?page_size=2",
      )
    ).json();
    expect(first.reviewSummaries).toHaveLength(2);
    expect(first.nextPageToken).not.toBe("");

    const second = await (
      await send(
        "GET",
        `/v1alpha/festivals/cbf2025/reviewSummaries?page_size=2&page_token=${first.nextPageToken}`,
      )
    ).json();
    expect(second.reviewSummaries).toHaveLength(1);
    expect(second.reviewSummaries[0].name).toBe(
      "festivals/cbf2025/reviewSummaries/beer-3",
    );
    expect(second.nextPageToken).toBe("");
  });

  it("rejects a negative page_size", async () => {
    const response = await send(
      "GET",
      "/v1alpha/festivals/cbf2025/reviewSummaries?page_size=-1",
    );
    expect(response.status).toBe(400);
    expect((await response.json()).error.details[0].reason).toBe(
      "INVALID_PAGE_SIZE",
    );
  });
});

// ---------------------------------------------------------------------------
// Routing
// ---------------------------------------------------------------------------

describe("reviews — routing", () => {
  it("returns 405 for an unsupported method on a review record", async () => {
    const response = await send("POST", reviewPath("cbf2025", "beer-1"), {
      body: { starRating: 3 },
    });
    expect(response.status).toBe(405);
    expect((await response.json()).error.status).toBe("UNIMPLEMENTED");
  });

  it("returns 404 for an unknown /v1alpha route", async () => {
    const response = await send("GET", "/v1alpha/festivals/cbf2025/bogus");
    expect(response.status).toBe(404);
    expect((await response.json()).error.details[0].reason).toBe(
      "ROUTE_NOT_FOUND",
    );
  });

  it("returns 400 when X-Device-Id header is missing", async () => {
    const request = new Request(
      "https://worker.example.com" + reviewPath("cbf2025", "beer-1"),
      { method: "GET", headers: { Origin: TEST_ORIGIN } },
    );
    const ctx = createExecutionContext();
    const response = await worker.fetch(request, env, ctx);
    await waitOnExecutionContext(ctx);
    expect(response.status).toBe(400);
    expect((await response.json()).error.details[0].reason).toBe(
      "MISSING_DEVICE_ID",
    );
  });
});

// ---------------------------------------------------------------------------
// Bucket isolation
// ---------------------------------------------------------------------------

describe("reviews — bucket isolation", () => {
  it("keeps test and prod traffic separate", async () => {
    await patch("cbf2025", "beer-1", { starRating: 5 }, { origin: PROD_ORIGIN });
    await patch("cbf2025", "beer-1", { starRating: 1 }, { origin: TEST_ORIGIN });

    const prod = await (
      await send("GET", "/v1alpha/festivals/cbf2025/reviewSummaries/beer-1", {
        origin: PROD_ORIGIN,
      })
    ).json();
    const test = await (
      await send("GET", "/v1alpha/festivals/cbf2025/reviewSummaries/beer-1", {
        origin: TEST_ORIGIN,
      })
    ).json();
    expect(prod.averageRating).toBe(5);
    expect(test.averageRating).toBe(1);
  });
});
