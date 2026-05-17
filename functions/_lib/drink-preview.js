const CRAWLER_UA_PATTERNS = [
  'facebookexternalhit',
  'twitterbot',
  'whatsapp',
  'slackbot',
  'linkedinbot',
  'discordbot',
  'googlebot',
  'telegrambot',
];

const DATA_BASE_URL = 'https://data.cambeerfestival.app';
const OG_IMAGE_URL = 'https://cambeerfestival.app/icons/Icon-512.png';

export function isCrawler(userAgent) {
  if (!userAgent) return false;
  const ua = userAgent.toLowerCase();
  return CRAWLER_UA_PATTERNS.some((pattern) => ua.includes(pattern));
}

export function findDrink(producers, drinkId) {
  for (const producer of producers) {
    const product = (producer.products ?? []).find((p) => String(p.id) === drinkId);
    if (product) return { product, producer };
  }
  return null;
}

function escapeHtml(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function formatAbv(abv) {
  const num = typeof abv === 'number' ? abv : parseFloat(abv);
  if (isNaN(num)) return null;
  return `${Number.isInteger(num) ? num : num.toFixed(1)}% ABV`;
}

export function buildOgTags(product, producer, canonicalUrl) {
  const title = `${product.name} — ${producer.name}`;
  const descParts = [product.style, formatAbv(product.abv), 'Cambridge Beer Festival'].filter(Boolean);
  const description = descParts.join(' · ');

  return [
    `<meta property="og:type" content="website">`,
    `<meta property="og:title" content="${escapeHtml(title)}">`,
    `<meta property="og:description" content="${escapeHtml(description)}">`,
    `<meta property="og:image" content="${escapeHtml(OG_IMAGE_URL)}">`,
    `<meta property="og:url" content="${escapeHtml(canonicalUrl)}">`,
    `<meta name="twitter:card" content="summary">`,
    `<meta name="twitter:title" content="${escapeHtml(title)}">`,
    `<meta name="twitter:description" content="${escapeHtml(description)}">`,
    `<meta name="twitter:image" content="${escapeHtml(OG_IMAGE_URL)}">`,
  ].join('\n');
}

export async function fetchDrinkData(festivalId, category) {
  const url = `${DATA_BASE_URL}/${encodeURIComponent(festivalId)}/${encodeURIComponent(category)}.json`;
  const response = await fetch(url);
  if (!response.ok) return null;
  const data = await response.json();
  return Array.isArray(data) ? data : (data.producers ?? null);
}
