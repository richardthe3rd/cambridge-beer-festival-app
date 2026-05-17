import { isCrawler, fetchDrinkData, findDrink, injectOgTags } from '../../../_lib/drink-preview.js';

const SITE_URL = 'https://cambeerfestival.app';

export async function onRequest(context) {
  const { request, env, params } = context;

  // Always serve the SPA for non-crawlers — no latency overhead.
  const userAgent = request.headers.get('User-Agent') ?? '';
  if (!isCrawler(userAgent)) {
    return env.ASSETS.fetch(request);
  }

  const festivalId = params.festivalId;
  const category = decodeURIComponent(params.category);
  const drinkId = decodeURIComponent(params.drinkId);
  const canonicalUrl = `${SITE_URL}/${festivalId}/drink/${encodeURIComponent(category)}/${encodeURIComponent(drinkId)}`;

  // Fetch SPA and drink data in parallel — both are needed for crawlers.
  const [spaResponse, producers] = await Promise.all([
    env.ASSETS.fetch(request),
    fetchDrinkData(festivalId, category).catch(() => null),
  ]);

  if (!producers) return spaResponse;

  const drink = findDrink(producers, drinkId);
  if (!drink) return spaResponse;

  try {
    const html = await spaResponse.text();
    const modified = injectOgTags(html, drink.product, drink.producer, canonicalUrl);
    return new Response(modified, {
      status: spaResponse.status,
      headers: spaResponse.headers,
    });
  } catch {
    return spaResponse;
  }
}
