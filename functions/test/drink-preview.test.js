import { describe, it, expect } from 'vitest';
import { isCrawler, findDrink, buildOgTags } from '../_lib/drink-preview.js';

const TEST_PRODUCERS = [
  {
    id: 'adnams',
    name: 'Adnams',
    location: 'Southwold',
    products: [
      { id: 'broadside', name: 'Broadside', category: 'beer', style: 'Strong Bitter', abv: 6.3, dispense: 'cask' },
      { id: 'ghost-ship', name: 'Ghost Ship', category: 'beer', style: 'Pale Ale', abv: 5.0, dispense: 'cask' },
    ],
  },
  {
    id: 'aspall',
    name: 'Aspall',
    location: 'Suffolk',
    products: [
      { id: 'premier-cru', name: 'Premier Cru', category: 'cider', style: null, abv: 7.0, dispense: 'draught' },
    ],
  },
];

describe('isCrawler', () => {
  it('detects facebookexternalhit', () => {
    expect(isCrawler('facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)')).toBe(true);
  });

  it('detects Twitterbot (case-insensitive)', () => {
    expect(isCrawler('Twitterbot/1.0')).toBe(true);
  });

  it('detects WhatsApp', () => {
    expect(isCrawler('WhatsApp/2.19.81 A')).toBe(true);
  });

  it('detects Slackbot', () => {
    expect(isCrawler('Slackbot-LinkExpanding 1.0 (+https://api.slack.com/robots)')).toBe(true);
  });

  it('detects LinkedInBot', () => {
    expect(isCrawler('LinkedInBot/1.0 (compatible; Mozilla/5.0)')).toBe(true);
  });

  it('detects Discordbot', () => {
    expect(isCrawler('Mozilla/5.0 (compatible; Discordbot/2.0)')).toBe(true);
  });

  it('detects Googlebot', () => {
    expect(isCrawler('Mozilla/5.0 (compatible; Googlebot/2.1)')).toBe(true);
  });

  it('detects TelegramBot', () => {
    expect(isCrawler('TelegramBot (like TwitterBot)')).toBe(true);
  });

  it('returns false for Chrome on Android', () => {
    expect(isCrawler('Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/91.0 Mobile Safari/537.36')).toBe(false);
  });

  it('returns false for Safari on iPhone', () => {
    expect(isCrawler('Mozilla/5.0 (iPhone; CPU iPhone OS 15_0) AppleWebKit/605.1.15 Safari/604.1')).toBe(false);
  });

  it('returns false for empty string', () => {
    expect(isCrawler('')).toBe(false);
  });

  it('returns false for null', () => {
    expect(isCrawler(null)).toBe(false);
  });
});

describe('findDrink', () => {
  it('finds a drink by product ID', () => {
    const result = findDrink(TEST_PRODUCERS, 'broadside');
    expect(result).not.toBeNull();
    expect(result.product.name).toBe('Broadside');
    expect(result.producer.name).toBe('Adnams');
  });

  it('finds a drink in a later producer', () => {
    const result = findDrink(TEST_PRODUCERS, 'premier-cru');
    expect(result.producer.name).toBe('Aspall');
    expect(result.product.name).toBe('Premier Cru');
  });

  it('finds a second product from the same producer', () => {
    const result = findDrink(TEST_PRODUCERS, 'ghost-ship');
    expect(result.product.name).toBe('Ghost Ship');
  });

  it('returns null when drink ID not found', () => {
    expect(findDrink(TEST_PRODUCERS, 'nonexistent-id')).toBeNull();
  });

  it('returns null for empty producers list', () => {
    expect(findDrink([], 'broadside')).toBeNull();
  });

  it('handles producers with empty products array', () => {
    const producers = [{ id: 'empty', name: 'Empty', products: [] }];
    expect(findDrink(producers, 'any')).toBeNull();
  });

  it('handles producers with missing products field', () => {
    const producers = [{ id: 'noproducts', name: 'No Products' }];
    expect(findDrink(producers, 'any')).toBeNull();
  });

  it('coerces numeric product IDs to string for comparison', () => {
    const producers = [{ id: 'test', name: 'Test', products: [{ id: 42, name: 'Numeric ID', abv: 4.0 }] }];
    const result = findDrink(producers, '42');
    expect(result.product.name).toBe('Numeric ID');
  });
});

describe('buildOgTags', () => {
  const product = { name: 'Broadside', style: 'Strong Bitter', abv: 6.3 };
  const producer = { name: 'Adnams' };
  const url = 'https://cambeerfestival.app/cbf2025/drink/beer/broadside';

  it('includes og:title with drink name and brewery', () => {
    const tags = buildOgTags(product, producer, url);
    expect(tags).toContain('og:title');
    expect(tags).toContain('Broadside — Adnams');
  });

  it('includes style, ABV, and festival name in description', () => {
    const tags = buildOgTags(product, producer, url);
    expect(tags).toContain('Strong Bitter · 6.3% ABV · Cambridge Beer Festival');
  });

  it('includes og:url set to canonical URL', () => {
    const tags = buildOgTags(product, producer, url);
    expect(tags).toContain(`og:url" content="${url}"`);
  });

  it('includes og:image pointing to festival icon', () => {
    const tags = buildOgTags(product, producer, url);
    expect(tags).toContain('og:image');
    expect(tags).toContain('Icon-512.png');
  });

  it('includes twitter:card set to summary', () => {
    const tags = buildOgTags(product, producer, url);
    expect(tags).toContain('twitter:card" content="summary"');
  });

  it('omits style from description when null', () => {
    const noStyle = { name: 'Premier Cru', style: null, abv: 7.0 };
    const tags = buildOgTags(noStyle, producer, url);
    expect(tags).toContain('7% ABV · Cambridge Beer Festival');
    expect(tags).not.toContain('null');
  });

  it('handles string ABV values', () => {
    const strAbv = { name: 'Test', style: 'IPA', abv: '6.3' };
    const tags = buildOgTags(strAbv, producer, url);
    expect(tags).toContain('6.3% ABV');
  });

  it('omits ABV from description when ABV is non-numeric', () => {
    const badAbv = { name: 'Test', style: 'IPA', abv: 'TBC' };
    const tags = buildOgTags(badAbv, producer, url);
    expect(tags).not.toContain('TBC');
    expect(tags).toContain('IPA · Cambridge Beer Festival');
  });

  it('formats whole-number ABV without decimal', () => {
    const wholeAbv = { name: 'Test', style: 'IPA', abv: 5 };
    const tags = buildOgTags(wholeAbv, producer, url);
    expect(tags).toContain('5% ABV');
    expect(tags).not.toContain('5.0%');
  });

  it('formats decimal ABV to one decimal place', () => {
    const tags = buildOgTags(product, producer, url);
    expect(tags).toContain('6.3% ABV');
  });

  it('escapes HTML special characters in drink name', () => {
    const xss = { name: '<script>alert("xss")</script>', style: null, abv: 4.0 };
    const tags = buildOgTags(xss, producer, url);
    expect(tags).not.toContain('<script>');
    expect(tags).toContain('&lt;script&gt;');
  });

  it('escapes ampersands in brewery name', () => {
    const ampProducer = { name: 'Greene & Sons' };
    const tags = buildOgTags(product, ampProducer, url);
    expect(tags).toContain('Greene &amp; Sons');
    expect(tags).not.toContain('Greene & Sons');
  });
});

