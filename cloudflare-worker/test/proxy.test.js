import { vi, describe, it, expect, beforeEach, afterEach } from 'vitest';
import { env, createExecutionContext, waitOnExecutionContext } from 'cloudflare:test';
import worker from '../worker.js';

const UPSTREAM = 'https://data.cambridgebeerfestival.com';
const PROXY_FETCH_INIT = {
	method: 'GET',
	headers: {
		'User-Agent': 'Cambridge-Beer-Festival-App-Proxy/1.0',
	},
};

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
	let mockFetch;

	beforeEach(() => {
		mockFetch = vi.fn();
		vi.stubGlobal('fetch', mockFetch);
	});

	afterEach(() => {
		vi.unstubAllGlobals();
	});

	it('proxies requests to upstream and returns response', async () => {
		const upstreamBody = JSON.stringify([{ name: 'Test Brewery', products: [] }]);
		mockFetch.mockResolvedValueOnce(new Response(upstreamBody, {
			status: 200,
			headers: { 'Content-Type': 'application/json' },
		}));

		const response = await fetchWorker('/cbf2025/beer.json');
		expect(response.status).toBe(200);

		const data = await response.json();
		expect(data).toEqual([{ name: 'Test Brewery', products: [] }]);
		expect(mockFetch).toHaveBeenCalledWith(`${UPSTREAM}/cbf2025/beer.json`, PROXY_FETCH_INIT);
	});

	it('adds charset=utf-8 to JSON responses missing it', async () => {
		mockFetch.mockResolvedValueOnce(new Response('[]', {
			status: 200,
			headers: { 'Content-Type': 'application/json' },
		}));

		const response = await fetchWorker('/cbf2025/beer.json');
		expect(response.headers.get('Content-Type'))
			.toBe('application/json; charset=utf-8');
		expect(mockFetch).toHaveBeenCalledWith(`${UPSTREAM}/cbf2025/beer.json`, PROXY_FETCH_INIT);
	});

	it('preserves charset if already present in upstream response', async () => {
		mockFetch.mockResolvedValueOnce(new Response('[]', {
			status: 200,
			headers: { 'Content-Type': 'application/json; charset=utf-8' },
		}));

		const response = await fetchWorker('/cbf2025/beer.json');
		expect(response.headers.get('Content-Type'))
			.toBe('application/json; charset=utf-8');
		expect(mockFetch).toHaveBeenCalledWith(`${UPSTREAM}/cbf2025/beer.json`, PROXY_FETCH_INIT);
	});

	it('includes CORS headers on proxied responses', async () => {
		mockFetch.mockResolvedValueOnce(new Response('[]', {
			status: 200,
			headers: { 'Content-Type': 'application/json' },
		}));

		const response = await fetchWorker('/cbf2025/beer.json');
		expect(response.headers.get('Access-Control-Allow-Origin'))
			.toBe('https://cambeerfestival.app');
		expect(response.headers.get('Vary')).toBe('Origin');
		expect(mockFetch).toHaveBeenCalledWith(`${UPSTREAM}/cbf2025/beer.json`, PROXY_FETCH_INIT);
	});

	it('passes through upstream error status codes', async () => {
		mockFetch.mockResolvedValueOnce(new Response('Not Found', { status: 404 }));

		const response = await fetchWorker('/cbf2025/nonexistent.json');
		expect(response.status).toBe(404);
		expect(mockFetch).toHaveBeenCalledWith(`${UPSTREAM}/cbf2025/nonexistent.json`, PROXY_FETCH_INIT);
	});

	it('returns 502 when upstream fetch fails', async () => {
		mockFetch.mockRejectedValueOnce(new Error('Connection refused'));

		const response = await fetchWorker('/cbf2025/beer.json');
		expect(response.status).toBe(502);

		const data = await response.json();
		expect(data.error).toBe('Proxy error');
		expect(data.message).toBeDefined();
		expect(mockFetch).toHaveBeenCalledWith(`${UPSTREAM}/cbf2025/beer.json`, PROXY_FETCH_INIT);
	});

	it('returns 502 with CORS headers on proxy error', async () => {
		mockFetch.mockRejectedValueOnce(new Error('Connection refused'));

		const response = await fetchWorker('/cbf2025/beer.json');
		expect(response.status).toBe(502);
		expect(response.headers.get('Access-Control-Allow-Origin'))
			.toBe('https://cambeerfestival.app');
		expect(mockFetch).toHaveBeenCalledWith(`${UPSTREAM}/cbf2025/beer.json`, PROXY_FETCH_INIT);
	});

	it('preserves query string when proxying', async () => {
		mockFetch.mockResolvedValueOnce(new Response('[]', {
			status: 200,
			headers: { 'Content-Type': 'application/json' },
		}));

		const response = await fetchWorker('/cbf2025/beer.json?v=2');
		expect(response.status).toBe(200);
		expect(mockFetch).toHaveBeenCalledWith(
			`${UPSTREAM}/cbf2025/beer.json?v=2`,
			PROXY_FETCH_INIT,
		);
	});
});
