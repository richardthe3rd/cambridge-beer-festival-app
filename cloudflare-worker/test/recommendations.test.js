import { describe, it, expect, beforeEach } from "vitest";
import {
  env,
  createExecutionContext,
  waitOnExecutionContext,
} from "cloudflare:test";
import worker from "../worker.js";
import { RECOMMENDATIONS_FAMILY } from "../recommendations.js";

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

const recPath = (f, d, device) =>
  `/v1/festivals/${f}/drinks/${d}/recommendations/${device}`;
const upsert = (f, d, device, wouldRecommend, opts) =>
  send("PATCH", recPath(f, d, device), { body: { wouldRecommend }, ...opts });

beforeEach(async () => {
  await env.RATINGS_DB.prepare("DELETE FROM recommendations").run();
});

describe("recommendations — pure helpers", () => {
  it("parseValue requires a boolean", () => {
    expect(
      RECOMMENDATIONS_FAMILY.parseValue({ wouldRecommend: true }),
    ).toMatchObject({
      ok: true,
      columnValue: 1,
    });
    expect(
      RECOMMENDATIONS_FAMILY.parseValue({ wouldRecommend: false }),
    ).toMatchObject({
      ok: true,
      columnValue: 0,
    });
    for (const wouldRecommend of [1, 0, "yes", null, undefined]) {
      expect(RECOMMENDATIONS_FAMILY.parseValue({ wouldRecommend }).ok).toBe(
        false,
      );
    }
  });

  it("summaryFields computes a 0..1 rate", () => {
    expect(RECOMMENDATIONS_FAMILY.summaryFields({})).toEqual({
      responseCount: 0,
      recommendCount: 0,
      recommendRate: 0,
    });
    expect(
      RECOMMENDATIONS_FAMILY.summaryFields({ agg_count: 3, agg_yes: 2 }),
    ).toEqual({ responseCount: 3, recommendCount: 2, recommendRate: 0.67 });
  });
});

describe("recommendations — upsert (PATCH)", () => {
  it("creates an answer and returns the resource", async () => {
    const response = await upsert("cbf2025", "beer-1", "dev-1", true);
    expect(response.status).toBe(200);
    const data = await response.json();
    expect(data.name).toBe(
      "festivals/cbf2025/drinks/beer-1/recommendations/dev-1",
    );
    expect(data.wouldRecommend).toBe(true);
    expect(typeof data.updateTime).toBe("string");
  });

  it("changing the answer updates in place", async () => {
    await upsert("cbf2025", "beer-1", "dev-1", true);
    const response = await upsert("cbf2025", "beer-1", "dev-1", false);
    expect((await response.json()).wouldRecommend).toBe(false);
  });

  it("rejects a non-boolean with a structured error", async () => {
    const response = await send(
      "PATCH",
      recPath("cbf2025", "beer-1", "dev-1"),
      {
        body: { wouldRecommend: "yes" },
      },
    );
    expect(response.status).toBe(400);
    expect((await response.json()).error.details[0].reason).toBe(
      "RECOMMENDATION_VALUE_INVALID",
    );
  });
});

describe("recommendations — get/delete record", () => {
  it("gets and deletes a device's own answer", async () => {
    await upsert("cbf2025", "beer-1", "dev-1", true);
    const got = await send("GET", recPath("cbf2025", "beer-1", "dev-1"));
    expect((await got.json()).wouldRecommend).toBe(true);

    const del = await send("DELETE", recPath("cbf2025", "beer-1", "dev-1"));
    expect(del.status).toBe(200);
    const after = await send("GET", recPath("cbf2025", "beer-1", "dev-1"));
    expect(after.status).toBe(404);
  });
});

describe("recommendations — summaries", () => {
  it("aggregates yes/no into a rate", async () => {
    await upsert("cbf2025", "beer-1", "dev-1", true);
    await upsert("cbf2025", "beer-1", "dev-2", true);
    await upsert("cbf2025", "beer-1", "dev-3", false);
    const response = await send(
      "GET",
      "/v1/festivals/cbf2025/recommendationSummaries/beer-1",
    );
    const data = await response.json();
    expect(data.name).toBe("festivals/cbf2025/recommendationSummaries/beer-1");
    expect(data.responseCount).toBe(3);
    expect(data.recommendCount).toBe(2);
    expect(data.recommendRate).toBe(0.67);
  });

  it("returns an empty summary for a drink with no answers", async () => {
    const response = await send(
      "GET",
      "/v1/festivals/cbf2025/recommendationSummaries/never",
    );
    expect(await response.json()).toMatchObject({
      responseCount: 0,
      recommendCount: 0,
      recommendRate: 0,
    });
  });

  it("lists summaries", async () => {
    await upsert("cbf2025", "beer-1", "dev-1", true);
    await upsert("cbf2025", "beer-2", "dev-1", false);
    const response = await send(
      "GET",
      "/v1/festivals/cbf2025/recommendationSummaries",
    );
    const data = await response.json();
    expect(data.totalSize).toBe(2);
    expect(data.recommendationSummaries.map((s) => s.name)).toEqual([
      "festivals/cbf2025/recommendationSummaries/beer-1",
      "festivals/cbf2025/recommendationSummaries/beer-2",
    ]);
  });
});

describe("recommendations — bucket isolation", () => {
  it("keeps test and prod traffic separate", async () => {
    await upsert("cbf2025", "beer-1", "dev-1", true, { origin: PROD_ORIGIN });
    await upsert("cbf2025", "beer-1", "dev-1", false, { origin: TEST_ORIGIN });

    const prod = await send(
      "GET",
      "/v1/festivals/cbf2025/recommendationSummaries/beer-1",
      { origin: PROD_ORIGIN },
    );
    const test = await send(
      "GET",
      "/v1/festivals/cbf2025/recommendationSummaries/beer-1",
      { origin: TEST_ORIGIN },
    );
    expect((await prod.json()).recommendRate).toBe(1);
    expect((await test.json()).recommendRate).toBe(0);
  });
});
