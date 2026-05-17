import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { onRequest } from '../[festivalId]/drink/[category]/[drinkId].js';

// Minimal HTMLRewriter mock: collects appended HTML and inserts it before </head>.
class MockHTMLRewriter {
  constructor() {
    this._headHandler = null;
  }
  on(selector, handler) {
    if (selector === 'head') this._headHandler = handler;
    return this;
  }
  async transform(response) {
    const text = await response.text();
    let injected = '';
    if (this._headHandler) {
      // Second arg ({ html: true }) is intentionally ignored in this mock.
      const element = { append: (html) => { injected += html; } };
      this._headHandler.element(element);
    }
    return new Response(text.replace('</head>', injected + '</head>'), {
      status: response.status,
      headers: response.headers,
    });
  }
}

const SPA_HTML = '<!DOCTYPE html><html><head><title>CBF</title></head><body></body></html>';

const TEST_PRODUCERS = [
  {
    id: 'adnams',
    name: 'Adnams',
    location: 'Southwold',
    products: [
      { id: 'broadside', name: 'Broadside', style: 'Strong Bitter', abv: 6.3, category: 'beer' },
    ],
  },
];

function makeSpaResponse() {
  return new Response(SPA_HTML, { headers: { 'Content-Type': 'text/html' } });
}

function makeContext({ ua, festivalId = 'cbf2025', category = 'beer', drinkId = 'broadside' } = {}) {
  const url = `https://cambeerfestival.app/${festivalId}/drink/${category}/${drinkId}`;
  return {
    request: new Request(url, {
      headers: { 'User-Agent': ua ?? 'Mozilla/5.0 Chrome/120' },
    }),
    env: {
      ASSETS: { fetch: vi.fn().mockResolvedValue(makeSpaResponse()) },
    },
    params: { festivalId, category, drinkId },
  };
}

beforeEach(() => {
  global.HTMLRewriter = MockHTMLRewriter;
  global.fetch = vi.fn().mockResolvedValue({
    ok: true,
    json: () => Promise.resolve({ producers: TEST_PRODUCERS }),
  });
});

afterEach(() => {
  vi.restoreAllMocks();
  delete global.HTMLRewriter;
});

describe('onRequest — non-crawler passthrough', () => {
  it('calls ASSETS.fetch and returns immediately for a regular browser', async () => {
    const ctx = makeContext({ ua: 'Mozilla/5.0 Chrome/120' });
    await onRequest(ctx);
    expect(ctx.env.ASSETS.fetch).toHaveBeenCalledWith(ctx.request);
    expect(global.fetch).not.toHaveBeenCalled();
  });

  it('does not inject OG tags for a regular browser', async () => {
    const ctx = makeContext({ ua: 'Mozilla/5.0 Chrome/120' });
    const response = await onRequest(ctx);
    const text = await response.text();
    expect(text).not.toContain('og:title');
  });
});

describe('onRequest — crawler OG injection', () => {
  it('injects og:title with drink name and brewery for Googlebot', async () => {
    const ctx = makeContext({ ua: 'Googlebot/2.1' });
    const response = await onRequest(ctx);
    const text = await response.text();
    expect(text).toContain('og:title');
    expect(text).toContain('Broadside — Adnams');
  });

  it('injects og:url with the canonical drink URL', async () => {
    const ctx = makeContext({ ua: 'Googlebot/2.1', festivalId: 'cbf2025', category: 'beer', drinkId: 'broadside' });
    const response = await onRequest(ctx);
    const text = await response.text();
    expect(text).toContain('https://cambeerfestival.app/cbf2025/drink/beer/broadside');
  });

  it('injects OG tags for WhatsApp crawler', async () => {
    const ctx = makeContext({ ua: 'WhatsApp/2.19.81 A' });
    const response = await onRequest(ctx);
    const text = await response.text();
    expect(text).toContain('og:title');
  });

  it('fetches drink data from the correct festival and category', async () => {
    const ctx = makeContext({ ua: 'Googlebot/2.1', festivalId: 'cbf2024', category: 'cider', drinkId: 'broadside' });
    global.fetch = vi.fn().mockResolvedValue({
      ok: true,
      json: () => Promise.resolve({ producers: TEST_PRODUCERS }),
    });
    await onRequest(ctx);
    expect(global.fetch).toHaveBeenCalledWith(
      expect.stringContaining('cbf2024/cider.json'),
    );
  });

  it('preserves the rest of the SPA HTML when injecting', async () => {
    const ctx = makeContext({ ua: 'Googlebot/2.1' });
    const response = await onRequest(ctx);
    const text = await response.text();
    expect(text).toContain('<title>CBF</title>');
    expect(text).toContain('<body></body>');
  });
});

describe('onRequest — crawler fallback paths', () => {
  it('returns unmodified SPA when API responds with non-ok status', async () => {
    global.fetch = vi.fn().mockResolvedValue({ ok: false, status: 404 });
    const ctx = makeContext({ ua: 'Googlebot/2.1' });
    const response = await onRequest(ctx);
    const text = await response.text();
    expect(text).not.toContain('og:title');
    expect(text).toBe(SPA_HTML);
  });

  it('returns unmodified SPA when fetch throws a network error', async () => {
    global.fetch = vi.fn().mockRejectedValue(new Error('Network failure'));
    const ctx = makeContext({ ua: 'Googlebot/2.1' });
    const response = await onRequest(ctx);
    const text = await response.text();
    expect(text).not.toContain('og:title');
  });

  it('returns unmodified SPA when the drink ID is not found', async () => {
    const ctx = makeContext({ ua: 'Googlebot/2.1', drinkId: 'nonexistent' });
    const response = await onRequest(ctx);
    const text = await response.text();
    expect(text).not.toContain('og:title');
  });
});
