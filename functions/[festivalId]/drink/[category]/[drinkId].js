import {
  isCrawler,
  fetchDrinkData,
  findDrink,
  buildOgTags,
} from "../../../_lib/drink-preview.js";

const SITE_URL = "https://cambeerfestival.app";

export async function onRequest(context) {
  const { request, env, params } = context;

  // Always serve the SPA for non-crawlers — no latency overhead.
  const userAgent = request.headers.get("User-Agent") ?? "";
  if (!isCrawler(userAgent)) {
    return env.ASSETS.fetch(request);
  }

  // Cloudflare Pages decodes route params before passing them to handlers.
  const festivalId = params.festivalId;
  const category = params.category;
  const drinkId = params.drinkId;
  const canonicalUrl = `${SITE_URL}/${festivalId}/drink/${encodeURIComponent(category)}/${encodeURIComponent(drinkId)}`;

  // Fetch SPA and drink data in parallel — both are needed for crawlers.
  const [spaResponse, producers] = await Promise.all([
    env.ASSETS.fetch(request),
    fetchDrinkData(festivalId, category).catch(() => null),
  ]);

  if (!producers) return spaResponse;

  const drink = findDrink(producers, drinkId);
  if (!drink) return spaResponse;

  // HTMLRewriter streams the response and appends OG tags inside <head>
  // without buffering the body — no encoding header concerns, no string hacks.
  return new HTMLRewriter()
    .on("head", {
      element(element) {
        element.append(
          buildOgTags(drink.product, drink.producer, canonicalUrl),
          { html: true },
        );
      },
    })
    .transform(spaResponse);
}
