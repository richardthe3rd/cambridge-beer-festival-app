import { isCrawler, fetchDrinkData, findDrink, injectOgTags } from '../../../_lib/drink-preview.js';

const SITE_URL = 'https://cambeerfestival.app';

export async function onRequest(context) {
  const { request, env, params } = context;

  // Always serve the SPA for non-crawlers — no latency overhead.
  const userAgent = request.headers.get('User-Agent') ?? '';
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

  try {
    // Clone before reading so the original stays intact for the error fallback.
    const html = await spaResponse.clone().text();
    const modified = injectOgTags(html, drink.product, drink.producer, canonicalUrl);

    // Strip encoding headers: spaResponse.text() already decompresses the body,
    // so re-sending with the original Content-Encoding would corrupt the response.
    const headers = new Headers(spaResponse.headers);
    headers.delete('content-encoding');
    headers.delete('content-length');

    return new Response(modified, { status: spaResponse.status, headers });
  } catch {
    return spaResponse;
  }
}
