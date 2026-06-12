import { describe, it, expect, beforeEach } from "vitest";
import {
  env,
  createExecutionContext,
  waitOnExecutionContext,
} from "cloudflare:test";
import worker from "../worker.js";
import { validateRecommendPayload, formatPercent } from "../recommendations.js";

const TEST_ORIGIN = "http://localhost:8080"; // non-prod -> 'test' bucket
const PROD_ORIGIN = "https://cambeerfestival.app"; // -> 'prod' bucket
const BASE = "/v1/recommendations";

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

const post = (body, opts) => send("POST", BASE, { body, ...opts });
const del = (body, opts) => send("DELETE", BASE, { body, ...opts });

// This pool version shares D1 storage across tests in a file, so reset the
// table before each test to keep aggregates deterministic.
beforeEach(async () => {
  await env.RATINGS_DB.prepare("DELETE FROM recommendations").run();
});

describe("recommendations — pure helpers", () => {
  it("validateRecommendPayload accepts a boolean recommend", () => {
    for (const recommend of [true, false]) {
      const result = validateRecommendPayload(
        {
          festivalId: "cbf2025",
          drinkId: "beer-1",
          deviceId: "dev-1",
          recommend,
        },
        { requireRecommend: true },
      );
      expect(result.ok).toBe(true);
      expect(result.value.recommend).toBe(recommend);
    }
  });

  it("validateRecommendPayload rejects non-boolean recommend", () => {
    for (const recommend of [1, 0, "yes", null, undefined]) {
      const result = validateRecommendPayload(
        { festivalId: "f", drinkId: "d", deviceId: "x", recommend },
        { requireRecommend: true },
      );
      expect(result.ok).toBe(false);
    }
  });

  it("validateRecommendPayload rejects missing ids", () => {
    expect(
      validateRecommendPayload(
        { drinkId: "d", deviceId: "x", recommend: true },
        { requireRecommend: true },
      ).ok,
    ).toBe(false);
  });

  it("validateRecommendPayload skips recommend when not required (DELETE)", () => {
    const result = validateRecommendPayload(
      { festivalId: "f", drinkId: "d", deviceId: "x" },
      { requireRecommend: false },
    );
    expect(result.ok).toBe(true);
  });

  it("formatPercent is a rounded whole number, null when empty", () => {
    expect(formatPercent(3, 4)).toBe(75);
    expect(formatPercent(1, 3)).toBe(33);
    expect(formatPercent(2, 3)).toBe(67);
    expect(formatPercent(0, 2)).toBe(0);
    expect(formatPercent(0, 0)).toBe(null);
  });
});

describe("recommendations — POST upsert", () => {
  it("records a recommendation and returns the aggregate", async () => {
    const response = await post({
      festivalId: "cbf2025",
      drinkId: "beer-1",
      deviceId: "dev-1",
      recommend: true,
    });
    expect(response.status).toBe(200);
    const data = await response.json();
    expect(data).toMatchObject({
      festivalId: "cbf2025",
      drinkId: "beer-1",
      count: 1,
      recommendCount: 1,
      recommendPercent: 100,
      youRecommend: true,
    });
  });

  it("changing answer from the same device updates rather than duplicates", async () => {
    await post({
      festivalId: "cbf2025",
      drinkId: "beer-1",
      deviceId: "dev-1",
      recommend: true,
    });
    const response = await post({
      festivalId: "cbf2025",
      drinkId: "beer-1",
      deviceId: "dev-1",
      recommend: false,
    });
    const data = await response.json();
    expect(data.count).toBe(1);
    expect(data.recommendCount).toBe(0);
    expect(data.recommendPercent).toBe(0);
    expect(data.youRecommend).toBe(false);
  });

  it("aggregates yes/no across multiple devices", async () => {
    await post({
      festivalId: "cbf2025",
      drinkId: "beer-1",
      deviceId: "dev-1",
      recommend: true,
    });
    await post({
      festivalId: "cbf2025",
      drinkId: "beer-1",
      deviceId: "dev-2",
      recommend: true,
    });
    const response = await post({
      festivalId: "cbf2025",
      drinkId: "beer-1",
      deviceId: "dev-3",
      recommend: false,
    });
    const data = await response.json();
    expect(data.count).toBe(3);
    expect(data.recommendCount).toBe(2);
    expect(data.recommendPercent).toBe(67); // 2/3
    expect(data.youRecommend).toBe(false); // dev-3
  });
});

describe("recommendations — validation", () => {
  it("rejects a non-boolean recommend with 400", async () => {
    const response = await post({
      festivalId: "cbf2025",
      drinkId: "beer-1",
      deviceId: "dev-1",
      recommend: "yes",
    });
    expect(response.status).toBe(400);
  });

  it("rejects missing fields with 400", async () => {
    const response = await post({ drinkId: "beer-1", recommend: true });
    expect(response.status).toBe(400);
  });

  it("rejects malformed JSON with 400", async () => {
    const response = await post("{not json", {});
    expect(response.status).toBe(400);
  });

  it("rejects unsupported methods on the collection with 405", async () => {
    const response = await send("PUT", BASE, {
      body: { festivalId: "f", drinkId: "d", deviceId: "x", recommend: true },
    });
    expect(response.status).toBe(405);
  });
});

describe("recommendations — GET", () => {
  it("returns an empty aggregate for a drink with no responses", async () => {
    const response = await send("GET", `${BASE}/cbf2025/never-rated`);
    expect(response.status).toBe(200);
    const data = await response.json();
    expect(data).toMatchObject({
      count: 0,
      recommendCount: 0,
      recommendPercent: null,
      youRecommend: null,
    });
  });

  it("includes youRecommend only when deviceId is supplied", async () => {
    await post({
      festivalId: "cbf2025",
      drinkId: "beer-1",
      deviceId: "dev-1",
      recommend: true,
    });

    const anon = await send("GET", `${BASE}/cbf2025/beer-1`);
    expect((await anon.json()).youRecommend).toBe(null);

    const known = await send("GET", `${BASE}/cbf2025/beer-1?deviceId=dev-1`);
    expect((await known.json()).youRecommend).toBe(true);
  });

  it("returns a festival-wide map of aggregates", async () => {
    await post({
      festivalId: "cbf2025",
      drinkId: "beer-1",
      deviceId: "dev-1",
      recommend: true,
    });
    await post({
      festivalId: "cbf2025",
      drinkId: "beer-2",
      deviceId: "dev-1",
      recommend: false,
    });
    await post({
      festivalId: "cbf2025",
      drinkId: "beer-2",
      deviceId: "dev-2",
      recommend: true,
    });

    const response = await send("GET", `${BASE}/cbf2025?deviceId=dev-1`);
    const data = await response.json();
    expect(data.festivalId).toBe("cbf2025");
    expect(data.aggregates["beer-1"]).toMatchObject({
      count: 1,
      recommendCount: 1,
      recommendPercent: 100,
      youRecommend: true,
    });
    expect(data.aggregates["beer-2"]).toMatchObject({
      count: 2,
      recommendCount: 1,
      recommendPercent: 50,
      youRecommend: false,
    });
  });

  it("returns 404 for an over-long path", async () => {
    const response = await send("GET", `${BASE}/cbf2025/beer-1/extra`);
    expect(response.status).toBe(404);
  });
});

describe("recommendations — DELETE", () => {
  it("removes a device's answer and returns the fresh aggregate", async () => {
    await post({
      festivalId: "cbf2025",
      drinkId: "beer-1",
      deviceId: "dev-1",
      recommend: false,
    });
    await post({
      festivalId: "cbf2025",
      drinkId: "beer-1",
      deviceId: "dev-2",
      recommend: true,
    });

    const response = await del({
      festivalId: "cbf2025",
      drinkId: "beer-1",
      deviceId: "dev-1",
    });
    const data = await response.json();
    expect(data.count).toBe(1); // only dev-2 remains
    expect(data.recommendCount).toBe(1);
    expect(data.recommendPercent).toBe(100);
    expect(data.youRecommend).toBe(null); // dev-1's answer is gone
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

describe("recommendations — bucket isolation", () => {
  it("keeps test and prod traffic in separate buckets", async () => {
    await post(
      {
        festivalId: "cbf2025",
        drinkId: "beer-1",
        deviceId: "dev-1",
        recommend: true,
      },
      { origin: PROD_ORIGIN },
    );
    await post(
      {
        festivalId: "cbf2025",
        drinkId: "beer-1",
        deviceId: "dev-1",
        recommend: false,
      },
      { origin: TEST_ORIGIN },
    );

    const prodView = await send("GET", `${BASE}/cbf2025/beer-1`, {
      origin: PROD_ORIGIN,
    });
    const testView = await send("GET", `${BASE}/cbf2025/beer-1`, {
      origin: TEST_ORIGIN,
    });

    expect((await prodView.json()).recommendPercent).toBe(100);
    expect((await testView.json()).recommendPercent).toBe(0);
  });
});
