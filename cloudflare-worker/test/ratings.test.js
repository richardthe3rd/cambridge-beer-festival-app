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
import { RATINGS_FAMILY } from "../ratings.js";

const TEST_ORIGIN = "http://localhost:8080"; // non-prod -> 'test' bucket
const PROD_ORIGIN = "https://cambeerfestival.app"; // -> 'prod' bucket

async function send(method, path, { body, origin = TEST_ORIGIN } = {}) {
  const init = { method, headers: { Origin: origin } };
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

const ratingPath = (f, d, device) =>
  `/v1/festivals/${f}/drinks/${d}/ratings/${device}`;
const upsert = (f, d, device, value, opts) =>
  send("PATCH", ratingPath(f, d, device), { body: { value }, ...opts });

beforeEach(async () => {
  await env.RATINGS_DB.prepare("DELETE FROM ratings").run();
});

describe("ratings — pure helpers", () => {
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

  it("RATINGS_FAMILY.parseValue enforces 1..5 integer", () => {
    expect(RATINGS_FAMILY.parseValue({ value: 4 })).toMatchObject({
      ok: true,
      columnValue: 4,
    });
    for (const value of [0, 6, 3.5, "4", null]) {
      expect(RATINGS_FAMILY.parseValue({ value }).ok).toBe(false);
    }
    expect(RATINGS_FAMILY.parseValue(null).ok).toBe(false);
  });

  it("RATINGS_FAMILY.summaryFields handles empty and populated rows", () => {
    expect(RATINGS_FAMILY.summaryFields({})).toEqual({
      ratingCount: 0,
      averageRating: 0,
    });
    expect(
      RATINGS_FAMILY.summaryFields({ agg_count: 2, agg_average: 4.5 }),
    ).toEqual({ ratingCount: 2, averageRating: 4.5 });
  });
});

describe("ratings — upsert (PATCH)", () => {
  it("creates a rating and returns the resource", async () => {
    const response = await upsert("cbf2025", "beer-1", "dev-1", 4);
    expect(response.status).toBe(200);
    const data = await response.json();
    expect(data.name).toBe("festivals/cbf2025/drinks/beer-1/ratings/dev-1");
    expect(data.value).toBe(4);
    expect(typeof data.updateTime).toBe("string");
    expect(Number.isNaN(Date.parse(data.updateTime))).toBe(false);
  });

  it("re-rating updates in place rather than duplicating", async () => {
    await upsert("cbf2025", "beer-1", "dev-1", 2);
    await upsert("cbf2025", "beer-1", "dev-1", 5);
    const summary = await send(
      "GET",
      "/v1/festivals/cbf2025/ratingSummaries/beer-1",
    );
    const data = await summary.json();
    expect(data.ratingCount).toBe(1);
    expect(data.averageRating).toBe(5);
  });

  it("rejects an out-of-range value with a structured error", async () => {
    const response = await upsert("cbf2025", "beer-1", "dev-1", 9);
    expect(response.status).toBe(400);
    const { error } = await response.json();
    expect(error.code).toBe(400);
    expect(error.status).toBe("INVALID_ARGUMENT");
    expect(error.details[0].reason).toBe("RATING_VALUE_OUT_OF_RANGE");
    expect(error.details[0].domain).toBe("cambeerfestival.app");
  });

  it("rejects malformed JSON", async () => {
    const response = await send(
      "PATCH",
      ratingPath("cbf2025", "beer-1", "dev-1"),
      {
        body: "{not json",
      },
    );
    expect(response.status).toBe(400);
    expect((await response.json()).error.details[0].reason).toBe(
      "INVALID_BODY",
    );
  });
});

describe("ratings — get/delete record", () => {
  it("gets a device's own rating", async () => {
    await upsert("cbf2025", "beer-1", "dev-1", 3);
    const response = await send(
      "GET",
      ratingPath("cbf2025", "beer-1", "dev-1"),
    );
    expect(response.status).toBe(200);
    expect((await response.json()).value).toBe(3);
  });

  it("returns 404 for a missing rating", async () => {
    const response = await send(
      "GET",
      ratingPath("cbf2025", "beer-1", "ghost"),
    );
    expect(response.status).toBe(404);
    expect((await response.json()).error.status).toBe("NOT_FOUND");
  });

  it("deletes a rating, then reads 404", async () => {
    await upsert("cbf2025", "beer-1", "dev-1", 3);
    const del = await send("DELETE", ratingPath("cbf2025", "beer-1", "dev-1"));
    expect(del.status).toBe(200);
    expect(await del.json()).toEqual({});
    const after = await send("GET", ratingPath("cbf2025", "beer-1", "dev-1"));
    expect(after.status).toBe(404);
  });

  it("deleting a missing rating is 404 (AIP-135)", async () => {
    const response = await send(
      "DELETE",
      ratingPath("cbf2025", "beer-1", "ghost"),
    );
    expect(response.status).toBe(404);
  });
});

describe("ratings — summaries", () => {
  it("aggregates across devices", async () => {
    await upsert("cbf2025", "beer-1", "dev-1", 4);
    await upsert("cbf2025", "beer-1", "dev-2", 5);
    await upsert("cbf2025", "beer-1", "dev-3", 3);
    const response = await send(
      "GET",
      "/v1/festivals/cbf2025/ratingSummaries/beer-1",
    );
    const data = await response.json();
    expect(data.name).toBe("festivals/cbf2025/ratingSummaries/beer-1");
    expect(data.ratingCount).toBe(3);
    expect(data.averageRating).toBe(4);
  });

  it("returns an empty summary for an unrated drink", async () => {
    const response = await send(
      "GET",
      "/v1/festivals/cbf2025/ratingSummaries/never",
    );
    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({
      ratingCount: 0,
      averageRating: 0,
    });
  });

  it("lists summaries with total size", async () => {
    await upsert("cbf2025", "beer-1", "dev-1", 4);
    await upsert("cbf2025", "beer-2", "dev-1", 2);
    const response = await send("GET", "/v1/festivals/cbf2025/ratingSummaries");
    const data = await response.json();
    expect(data.totalSize).toBe(2);
    expect(data.nextPageToken).toBe("");
    expect(data.ratingSummaries.map((s) => s.name)).toEqual([
      "festivals/cbf2025/ratingSummaries/beer-1",
      "festivals/cbf2025/ratingSummaries/beer-2",
    ]);
  });

  it("paginates with opaque tokens", async () => {
    await upsert("cbf2025", "beer-1", "dev-1", 4);
    await upsert("cbf2025", "beer-2", "dev-1", 4);
    await upsert("cbf2025", "beer-3", "dev-1", 4);

    const first = await send(
      "GET",
      "/v1/festivals/cbf2025/ratingSummaries?page_size=2",
    );
    const firstData = await first.json();
    expect(firstData.ratingSummaries).toHaveLength(2);
    expect(firstData.nextPageToken).not.toBe("");

    const second = await send(
      "GET",
      `/v1/festivals/cbf2025/ratingSummaries?page_size=2&page_token=${firstData.nextPageToken}`,
    );
    const secondData = await second.json();
    expect(secondData.ratingSummaries).toHaveLength(1);
    expect(secondData.ratingSummaries[0].name).toBe(
      "festivals/cbf2025/ratingSummaries/beer-3",
    );
    expect(secondData.nextPageToken).toBe("");
  });

  it("rejects a negative page_size", async () => {
    const response = await send(
      "GET",
      "/v1/festivals/cbf2025/ratingSummaries?page_size=-1",
    );
    expect(response.status).toBe(400);
    expect((await response.json()).error.details[0].reason).toBe(
      "INVALID_PAGE_SIZE",
    );
  });
});

describe("ratings — routing", () => {
  it("returns 405 for an unsupported method on a record", async () => {
    const response = await send(
      "POST",
      ratingPath("cbf2025", "beer-1", "dev-1"),
      {
        body: { value: 3 },
      },
    );
    expect(response.status).toBe(405);
    expect((await response.json()).error.status).toBe("UNIMPLEMENTED");
  });

  it("returns 404 for an unknown /v1 route", async () => {
    const response = await send("GET", "/v1/festivals/cbf2025/bogus/beer-1");
    expect(response.status).toBe(404);
    expect((await response.json()).error.details[0].reason).toBe(
      "ROUTE_NOT_FOUND",
    );
  });
});

describe("ratings — bucket isolation", () => {
  it("keeps test and prod traffic separate", async () => {
    await upsert("cbf2025", "beer-1", "dev-1", 5, { origin: PROD_ORIGIN });
    await upsert("cbf2025", "beer-1", "dev-1", 1, { origin: TEST_ORIGIN });

    const prod = await send(
      "GET",
      "/v1/festivals/cbf2025/ratingSummaries/beer-1",
      {
        origin: PROD_ORIGIN,
      },
    );
    const test = await send(
      "GET",
      "/v1/festivals/cbf2025/ratingSummaries/beer-1",
      {
        origin: TEST_ORIGIN,
      },
    );
    expect((await prod.json()).averageRating).toBe(5);
    expect((await test.json()).averageRating).toBe(1);
  });
});
