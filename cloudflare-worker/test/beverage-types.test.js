import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { env, createExecutionContext, waitOnExecutionContext, fetchMock } from 'cloudflare:test';
import worker from '../worker.js';

const UPSTREAM = 'https://data.cambridgebeerfestival.com';

/**
 * Helper to make a request to the worker.
 */
async function fetchWorker(path, origin = 'https://cambeerfestival.app') {
	const request = new Request(`https://worker.example.com${path}`, {
		headers: { Origin: origin },
	});
	const ctx = createExecutionContext();
	const response = await worker.fetch(request, env, ctx);
	await waitOnExecutionContext(ctx);
	return response;
}

/**
 * Sample Apache-style directory listing HTML.
 */
function makeDirectoryHtml(files) {
	const links = files.map((f) => `<a href="${f}">${f}</a>`).join('\n');
	return `
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">
<html><head><title>Index of /cbf2025</title></head>
<body><h1>Index of /cbf2025</h1>
<pre>Name                    Last modified      Size  Description
<hr>
<a href="/">Parent Directory</a>                             -
${links}
<hr></pre></body></html>`;
}

describe('available_beverage_types endpoint', () => {
	beforeEach(() => {
		fetchMock.activate();
		fetchMock.disableNetConnect();
	});

	afterEach(() => {
		fetchMock.deactivate();
	});

	it('parses directory listing into beverage types', async () => {
		fetchMock.get(UPSTREAM)
			.intercept({ path: '/cbf2025/' })
			.reply(200, makeDirectoryHtml([
				'beer.json', 'cider.json', 'perry.json', 'mead.json',
			]));

		const response = await fetchWorker('/cbf2025/available_beverage_types.json');
		expect(response.status).toBe(200);

		const data = await response.json();
		expect(data.festival_id).toBe('cbf2025');
		expect(data.available_beverage_types).toEqual(['beer', 'cider', 'mead', 'perry']);
	});

	it('returns types sorted alphabetically', async () => {
		fetchMock.get(UPSTREAM)
			.intercept({ path: '/cbf2025/' })
			.reply(200, makeDirectoryHtml([
				'wine.json', 'beer.json', 'apple-juice.json',
			]));

		const response = await fetchWorker('/cbf2025/available_beverage_types.json');
		const data = await response.json();
		expect(data.available_beverage_types).toEqual(['apple-juice', 'beer', 'wine']);
	});

	it('filters out available_beverage_types.json from results', async () => {
		fetchMock.get(UPSTREAM)
			.intercept({ path: '/cbf2025/' })
			.reply(200, makeDirectoryHtml([
				'beer.json', 'available_beverage_types.json', 'cider.json',
			]));

		const response = await fetchWorker('/cbf2025/available_beverage_types.json');
		const data = await response.json();
		expect(data.available_beverage_types).toEqual(['beer', 'cider']);
		expect(data.available_beverage_types).not.toContain('available_beverage_types');
	});

	it('returns empty array when no JSON files found', async () => {
		fetchMock.get(UPSTREAM)
			.intercept({ path: '/cbf2025/' })
			.reply(200, makeDirectoryHtml([]));

		const response = await fetchWorker('/cbf2025/available_beverage_types.json');
		const data = await response.json();
		expect(data.available_beverage_types).toEqual([]);
	});

	it('returns 404 when festival not found upstream', async () => {
		fetchMock.get(UPSTREAM)
			.intercept({ path: '/nonexistent/' })
			.reply(404, 'Not Found');

		const response = await fetchWorker('/nonexistent/available_beverage_types.json');
		expect(response.status).toBe(404);

		const data = await response.json();
		expect(data.error).toBe('Festival not found');
		expect(data.festival_id).toBe('nonexistent');
	});

	it('returns 500 when upstream fetch fails', async () => {
		fetchMock.get(UPSTREAM)
			.intercept({ path: '/cbf2025/' })
			.replyWithError(new Error('Connection refused'));

		const response = await fetchWorker('/cbf2025/available_beverage_types.json');
		expect(response.status).toBe(500);

		const data = await response.json();
		expect(data.error).toBe('Failed to fetch beverage types');
	});

	it('includes CORS headers on success', async () => {
		fetchMock.get(UPSTREAM)
			.intercept({ path: '/cbf2025/' })
			.reply(200, makeDirectoryHtml(['beer.json']));

		const response = await fetchWorker('/cbf2025/available_beverage_types.json');
		expect(response.headers.get('Access-Control-Allow-Origin'))
			.toBe('https://cambeerfestival.app');
	});

	it('includes CORS headers on 404', async () => {
		fetchMock.get(UPSTREAM)
			.intercept({ path: '/nonexistent/' })
			.reply(404, 'Not Found');

		const response = await fetchWorker('/nonexistent/available_beverage_types.json');
		expect(response.headers.get('Access-Control-Allow-Origin'))
			.toBe('https://cambeerfestival.app');
	});

	it('sets Cache-Control to 1 hour on success', async () => {
		fetchMock.get(UPSTREAM)
			.intercept({ path: '/cbf2025/' })
			.reply(200, makeDirectoryHtml(['beer.json']));

		const response = await fetchWorker('/cbf2025/available_beverage_types.json');
		expect(response.headers.get('Cache-Control')).toBe('public, max-age=3600');
	});

	it('includes timestamp in response', async () => {
		fetchMock.get(UPSTREAM)
			.intercept({ path: '/cbf2025/' })
			.reply(200, makeDirectoryHtml(['beer.json']));

		const response = await fetchWorker('/cbf2025/available_beverage_types.json');
		const data = await response.json();
		expect(data.timestamp).toBeDefined();
		// Verify it's a valid ISO date
		expect(new Date(data.timestamp).toISOString()).toBe(data.timestamp);
	});

	it('handles hyphenated beverage type names', async () => {
		fetchMock.get(UPSTREAM)
			.intercept({ path: '/cbf2025/' })
			.reply(200, makeDirectoryHtml([
				'international-beer.json', 'low-no.json', 'apple-juice.json',
			]));

		const response = await fetchWorker('/cbf2025/available_beverage_types.json');
		const data = await response.json();
		expect(data.available_beverage_types).toEqual([
			'apple-juice', 'international-beer', 'low-no',
		]);
	});
});
