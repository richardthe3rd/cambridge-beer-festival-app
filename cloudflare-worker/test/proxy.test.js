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

describe('health check', () => {
	it('returns 200 with status ok', async () => {
		const response = await fetchWorker('/health');
		expect(response.status).toBe(200);

		const data = await response.json();
		expect(data).toEqual({ status: 'ok' });
	});

	it('returns JSON content type', async () => {
		const response = await fetchWorker('/health');
		expect(response.headers.get('Content-Type'))
			.toBe('application/json; charset=utf-8');
	});

	it('includes CORS headers', async () => {
		const response = await fetchWorker('/health');
		expect(response.headers.get('Access-Control-Allow-Origin'))
			.toBe('https://cambeerfestival.app');
	});
});

describe('upstream proxy', () => {
	beforeEach(() => {
		fetchMock.activate();
		fetchMock.disableNetConnect();
	});

	afterEach(() => {
		fetchMock.deactivate();
	});

	it('proxies requests to upstream and returns response', async () => {
		const upstreamBody = JSON.stringify([{ name: 'Test Brewery', products: [] }]);
		fetchMock.get(UPSTREAM)
			.intercept({ path: '/cbf2025/beer.json' })
			.reply(200, upstreamBody, {
				headers: { 'Content-Type': 'application/json' },
			});

		const response = await fetchWorker('/cbf2025/beer.json');
		expect(response.status).toBe(200);

		const data = await response.json();
		expect(data).toEqual([{ name: 'Test Brewery', products: [] }]);
	});

	it('adds charset=utf-8 to JSON responses missing it', async () => {
		fetchMock.get(UPSTREAM)
			.intercept({ path: '/cbf2025/beer.json' })
			.reply(200, '[]', {
				headers: { 'Content-Type': 'application/json' },
			});

		const response = await fetchWorker('/cbf2025/beer.json');
		expect(response.headers.get('Content-Type'))
			.toBe('application/json; charset=utf-8');
	});

	it('preserves charset if already present in upstream response', async () => {
		fetchMock.get(UPSTREAM)
			.intercept({ path: '/cbf2025/beer.json' })
			.reply(200, '[]', {
				headers: { 'Content-Type': 'application/json; charset=utf-8' },
			});

		const response = await fetchWorker('/cbf2025/beer.json');
		expect(response.headers.get('Content-Type'))
			.toBe('application/json; charset=utf-8');
	});

	it('includes CORS headers on proxied responses', async () => {
		fetchMock.get(UPSTREAM)
			.intercept({ path: '/cbf2025/beer.json' })
			.reply(200, '[]', {
				headers: { 'Content-Type': 'application/json' },
			});

		const response = await fetchWorker('/cbf2025/beer.json');
		expect(response.headers.get('Access-Control-Allow-Origin'))
			.toBe('https://cambeerfestival.app');
		expect(response.headers.get('Vary')).toBe('Origin');
	});

	it('passes through upstream error status codes', async () => {
		fetchMock.get(UPSTREAM)
			.intercept({ path: '/cbf2025/nonexistent.json' })
			.reply(404, 'Not Found');

		const response = await fetchWorker('/cbf2025/nonexistent.json');
		expect(response.status).toBe(404);
	});

	it('returns 502 when upstream fetch fails', async () => {
		fetchMock.get(UPSTREAM)
			.intercept({ path: '/cbf2025/beer.json' })
			.replyWithError(new Error('Connection refused'));

		const response = await fetchWorker('/cbf2025/beer.json');
		expect(response.status).toBe(502);

		const data = await response.json();
		expect(data.error).toBe('Proxy error');
		expect(data.message).toBeDefined();
	});

	it('returns 502 with CORS headers on proxy error', async () => {
		fetchMock.get(UPSTREAM)
			.intercept({ path: '/cbf2025/beer.json' })
			.replyWithError(new Error('Connection refused'));

		const response = await fetchWorker('/cbf2025/beer.json');
		expect(response.status).toBe(502);
		expect(response.headers.get('Access-Control-Allow-Origin'))
			.toBe('https://cambeerfestival.app');
	});

	it('preserves query string when proxying', async () => {
		fetchMock.get(UPSTREAM)
			.intercept({ path: '/cbf2025/beer.json', query: { v: '2' } })
			.reply(200, '[]', {
				headers: { 'Content-Type': 'application/json' },
			});

		const response = await fetchWorker('/cbf2025/beer.json?v=2');
		expect(response.status).toBe(200);
	});
});
