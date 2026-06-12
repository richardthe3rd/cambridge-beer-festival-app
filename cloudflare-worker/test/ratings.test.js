import { describe, it, expect, beforeEach } from "vitest";
import {
  env,
  createExecutionContext,
  waitOnExecutionContext,
} from "cloudflare:test";
import worker from "../worker.js";
import { isProductionOrigin, resolveBucket } from "../shared.js";
import { validateWritePayload, formatAverage } from "../ratings.js";

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

const post = (body, opts) => send("POST", "/v1/ratings", { body, ...opts });
const del = (body, opts) => send("DELETE", "/v1/ratings", { body, ...opts });

// This pool version shares D1 storage across tests in a file, so reset the
// table before each test to keep aggregates deterministic.
beforeEach(async () => {
  await env.RATINGS_DB.prepare("DELETE FROM ratings").run();
});

describe("ratings — pure helpers", () => {
  it("only the production web origin is a production origin", () => {
    expect(isProductionOrigin("https://cambeerfestival.app")).toBe(true);
    expect(isProductionOrigin("https://staging.cambeerfestival.app")).toBe(
      false,
    );
    expect(isProductionOrigin("http://localhost:8080")).toBe(false);
    expect(isProductionOrigin("")).toBe(false);
  });

  it("resolveBucket derives from origin", () => {
    expect(resolveBucket(PROD_ORIGIN, {})).toBe("prod");
    expect(resolveBucket(TEST_ORIGIN, {})).toBe("test");
    expect(resolveBucket("", {})).toBe("test");
  });

  it("resolveBucket honours an explicit RATINGS_BUCKET override", () => {
    expect(resolveBucket(PROD_ORIGIN, { RATINGS_BUCKET: "test" })).toBe("test");
    expect(resolveBucket(TEST_ORIGIN, { RATINGS_BUCKET: "prod" })).toBe("prod");
    expect(resolveBucket(TEST_ORIGIN, { RATINGS_BUCKET: "" })).toBe("test");
  });

  it("validateWritePayload accepts a well-formed rating", () => {
    const result = validateWritePayload(
      {
        festivalId: "cbf2025",
        drinkId: "beer-1",
        deviceId: "dev-1",
        rating: 4,
      },
      { requireRating: true },
    );
    expect(result.ok).toBe(true);
    expect(result.value.rating).toBe(4);
  });

  it("validateWritePayload rejects out-of-range and non-integer ratings", () => {
    for (const rating of [0, 6, 3.5, "4", null, undefined]) {
      const result = validateWritePayload(
        { festivalId: "f", drinkId: "d", deviceId: "x", rating },
        { requireRating: true },
      );
      expect(result.ok).toBe(false);
    }
  });

  it("validateWritePayload rejects missing ids", () => {
    expect(
      validateWritePayload(
        { drinkId: "d", deviceId: "x", rating: 3 },
        { requireRating: true },
      ).ok,
    ).toBe(false);
    expect(
      validateWritePayload(
        { festivalId: "f", deviceId: "x", rating: 3 },
        { requireRating: true },
      ).ok,
    ).toBe(false);
    expect(
      validateWritePayload(
        { festivalId: "f", drinkId: "d", rating: 3 },
        { requireRating: true },
      ).ok,
    ).toBe(false);
  });

  it("validateWritePayload skips rating when not required (DELETE)", () => {
    const result = validateWritePayload(
      { festivalId: "f", drinkId: "d", deviceId: "x" },
      { requireRating: false },
    );
    expect(result.ok).toBe(true);
  });

  it("formatAverage rounds to one decimal and is null when empty", () => {
    expect(formatAverage(4.25, 4)).toBe(4.3);
    expect(formatAverage(3, 1)).toBe(3);
    expect(formatAverage(null, 0)).toBe(null);
    expect(formatAverage(5, 0)).toBe(null);
  });
});

describe("ratings — POST upsert", () => {
  it("records a rating and returns the aggregate", async () => {
    const response = await post({
      festivalId: "cbf2025",
      drinkId: "beer-1",
      deviceId: "dev-1",
      rating: 4,
    });
    expect(response.status).toBe(200);
    const data = await response.json();
    expect(data).toMatchObject({
      festivalId: "cbf2025",
      drinkId: "beer-1",
      count: 1,
      average: 4,
      yourRating: 4,
    });
  });

  it("re-rating from the same device updates rather than duplicates", async () => {
    await post({
      festivalId: "cbf2025",
      drinkId: "beer-1",
      deviceId: "dev-1",
      rating: 2,
    });
    const response = await post({
      festivalId: "cbf2025",
      drinkId: "beer-1",
      deviceId: "dev-1",
      rating: 5,
    });
    const data = await response.json();
    expect(data.count).toBe(1);
    expect(data.average).toBe(5);
    expect(data.yourRating).toBe(5);
  });

  it("aggregates across multiple devices", async () => {
    await post({
      festivalId: "cbf2025",
      drinkId: "beer-1",
      deviceId: "dev-1",
      rating: 4,
    });
    await post({
      festivalId: "cbf2025",
      drinkId: "beer-1",
      deviceId: "dev-2",
      rating: 5,
    });
    const response = await post({
      festivalId: "cbf2025",
      drinkId: "beer-1",
      deviceId: "dev-3",
      rating: 3,
    });
    const data = await response.json();
    expect(data.count).toBe(3);
    expect(data.average).toBe(4); // (4+5+3)/3
    expect(data.yourRating).toBe(3); // dev-3
  });
});

describe("ratings — validation", () => {
  it("rejects an invalid rating with 400", async () => {
    const response = await post({
      festivalId: "cbf2025",
      drinkId: "beer-1",
      deviceId: "dev-1",
      rating: 9,
    });
    expect(response.status).toBe(400);
  });

  it("rejects missing fields with 400", async () => {
    const response = await post({ drinkId: "beer-1", rating: 4 });
    expect(response.status).toBe(400);
  });

  it("rejects malformed JSON with 400", async () => {
    const response = await post("{not json", {});
    expect(response.status).toBe(400);
  });

  it("rejects unsupported methods on the collection with 405", async () => {
    const response = await send("PUT", "/v1/ratings", {
      body: { festivalId: "f", drinkId: "d", deviceId: "x", rating: 3 },
    });
    expect(response.status).toBe(405);
  });
});

describe("ratings — GET", () => {
  it("returns an empty aggregate for an unrated drink", async () => {
    const response = await send("GET", "/v1/ratings/cbf2025/never-rated");
    expect(response.status).toBe(200);
    const data = await response.json();
    expect(data).toMatchObject({
      count: 0,
      average: null,
      yourRating: null,
    });
  });

  it("includes yourRating only when deviceId is supplied", async () => {
    await post({
      festivalId: "cbf2025",
      drinkId: "beer-1",
      deviceId: "dev-1",
      rating: 4,
    });

    const anon = await send("GET", "/v1/ratings/cbf2025/beer-1");
    expect((await anon.json()).yourRating).toBe(null);

    const known = await send(
      "GET",
      "/v1/ratings/cbf2025/beer-1?deviceId=dev-1",
    );
    expect((await known.json()).yourRating).toBe(4);
  });

  it("returns a festival-wide map of aggregates", async () => {
    await post({
      festivalId: "cbf2025",
      drinkId: "beer-1",
      deviceId: "dev-1",
      rating: 4,
    });
    await post({
      festivalId: "cbf2025",
      drinkId: "beer-2",
      deviceId: "dev-1",
      rating: 2,
    });
    await post({
      festivalId: "cbf2025",
      drinkId: "beer-2",
      deviceId: "dev-2",
      rating: 4,
    });

    const response = await send("GET", "/v1/ratings/cbf2025?deviceId=dev-1");
    const data = await response.json();
    expect(data.festivalId).toBe("cbf2025");
    expect(data.aggregates["beer-1"]).toMatchObject({
      count: 1,
      average: 4,
      yourRating: 4,
    });
    expect(data.aggregates["beer-2"]).toMatchObject({
      count: 2,
      average: 3,
      yourRating: 2,
    });
  });

  it("returns 404 for an over-long ratings path", async () => {
    const response = await send("GET", "/v1/ratings/cbf2025/beer-1/extra");
    expect(response.status).toBe(404);
  });
});

describe("ratings — DELETE", () => {
  it("removes a device's rating and returns the fresh aggregate", async () => {
    await post({
      festivalId: "cbf2025",
      drinkId: "beer-1",
      deviceId: "dev-1",
      rating: 4,
    });
    await post({
      festivalId: "cbf2025",
      drinkId: "beer-1",
      deviceId: "dev-2",
      rating: 2,
    });

    const response = await del({
      festivalId: "cbf2025",
      drinkId: "beer-1",
      deviceId: "dev-1",
    });
    const data = await response.json();
    expect(data.count).toBe(1); // only dev-2 remains
    expect(data.average).toBe(2);
    expect(data.yourRating).toBe(null); // dev-1's rating is gone
  });

  it("is a no-op when there is nothing to delete", async () => {
    const response = await del({
      festivalId: "cbf2025",
      drinkId: "beer-1",
      deviceId: "ghost",
    });
    expect(response.status).toBe(200);
    expect((await response.json()).count).toBe(0);
  });
});

describe("ratings — bucket isolation", () => {
  it("keeps test and prod traffic in separate buckets", async () => {
    await post(
      {
        festivalId: "cbf2025",
        drinkId: "beer-1",
        deviceId: "dev-1",
        rating: 5,
      },
      { origin: PROD_ORIGIN },
    );
    await post(
      {
        festivalId: "cbf2025",
        drinkId: "beer-1",
        deviceId: "dev-1",
        rating: 1,
      },
      { origin: TEST_ORIGIN },
    );

    const prodView = await send("GET", "/v1/ratings/cbf2025/beer-1", {
      origin: PROD_ORIGIN,
    });
    const testView = await send("GET", "/v1/ratings/cbf2025/beer-1", {
      origin: TEST_ORIGIN,
    });

    expect((await prodView.json()).average).toBe(5);
    expect((await testView.json()).average).toBe(1);
  });
});
