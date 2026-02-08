import { describe, it, expect } from 'vitest';
import { env, createExecutionContext, waitOnExecutionContext } from 'cloudflare:test';
import worker from '../worker.js';

/**
 * Helper to make a request to the worker with a given origin.
 */
async function fetchWithOrigin(path, origin, method = 'GET') {
	const headers = {};
	if (origin) {
		headers['Origin'] = origin;
	}
	const request = new Request(`https://worker.example.com${path}`, {
		method,
		headers,
	});
	const ctx = createExecutionContext();
	const response = await worker.fetch(request, env, ctx);
	await waitOnExecutionContext(ctx);
	return response;
}

describe('CORS origin matching', () => {
	it('allows production origin (cambeerfestival.app)', async () => {
		const response = await fetchWithOrigin('/health', 'https://cambeerfestival.app');
		expect(response.headers.get('Access-Control-Allow-Origin'))
			.toBe('https://cambeerfestival.app');
		expect(response.headers.get('Access-Control-Allow-Credentials')).toBe('true');
		expect(response.headers.get('Vary')).toBe('Origin');
	});

	it('allows staging origin', async () => {
		const response = await fetchWithOrigin('/health', 'https://staging.cambeerfestival.app');
		expect(response.headers.get('Access-Control-Allow-Origin'))
			.toBe('https://staging.cambeerfestival.app');
	});

	it('allows GitHub Pages origin', async () => {
		const response = await fetchWithOrigin('/health', 'https://richardthe3rd.github.io');
		expect(response.headers.get('Access-Control-Allow-Origin'))
			.toBe('https://richardthe3rd.github.io');
	});

	it('allows tunnel origin', async () => {
		const response = await fetchWithOrigin('/health', 'https://tunnel.cambeerfestival.app');
		expect(response.headers.get('Access-Control-Allow-Origin'))
			.toBe('https://tunnel.cambeerfestival.app');
	});

	it('allows localhost:8080', async () => {
		const response = await fetchWithOrigin('/health', 'http://localhost:8080');
		expect(response.headers.get('Access-Control-Allow-Origin'))
			.toBe('http://localhost:8080');
	});

	it('allows localhost:3000', async () => {
		const response = await fetchWithOrigin('/health', 'http://localhost:3000');
		expect(response.headers.get('Access-Control-Allow-Origin'))
			.toBe('http://localhost:3000');
	});

	it('allows 127.0.0.1:8080', async () => {
		const response = await fetchWithOrigin('/health', 'http://127.0.0.1:8080');
		expect(response.headers.get('Access-Control-Allow-Origin'))
			.toBe('http://127.0.0.1:8080');
	});

	it('allows Cloudflare Pages preview URLs (*.cambeerfestival.pages.dev)', async () => {
		const response = await fetchWithOrigin('/health', 'https://abc123.cambeerfestival.pages.dev');
		expect(response.headers.get('Access-Control-Allow-Origin'))
			.toBe('https://abc123.cambeerfestival.pages.dev');
		expect(response.headers.get('Access-Control-Allow-Credentials')).toBe('true');
		expect(response.headers.get('Vary')).toBe('Origin');
	});

	it('allows staging Pages preview URLs (*.staging-cambeerfestival.pages.dev)', async () => {
		const response = await fetchWithOrigin('/health', 'https://feature-branch.staging-cambeerfestival.pages.dev');
		expect(response.headers.get('Access-Control-Allow-Origin'))
			.toBe('https://feature-branch.staging-cambeerfestival.pages.dev');
	});

	it('allows Cloudflare Tunnel URLs (*.trycloudflare.com)', async () => {
		const response = await fetchWithOrigin('/health', 'https://my-tunnel.trycloudflare.com');
		expect(response.headers.get('Access-Control-Allow-Origin'))
			.toBe('https://my-tunnel.trycloudflare.com');
	});

	it('rejects unknown origins', async () => {
		const response = await fetchWithOrigin('/health', 'https://evil.example.com');
		expect(response.headers.get('Access-Control-Allow-Origin')).toBeNull();
		expect(response.headers.get('Access-Control-Allow-Credentials')).toBeNull();
		expect(response.headers.get('Vary')).toBeNull();
	});

	it('handles request with no Origin header', async () => {
		const response = await fetchWithOrigin('/health', null);
		expect(response.headers.get('Access-Control-Allow-Origin')).toBeNull();
		expect(response.status).toBe(200);
	});
});

describe('CORS preflight (OPTIONS)', () => {
	it('returns 204 with no body', async () => {
		const response = await fetchWithOrigin('/', 'https://cambeerfestival.app', 'OPTIONS');
		expect(response.status).toBe(204);
		const body = await response.text();
		expect(body).toBe('');
	});

	it('includes correct methods and headers', async () => {
		const response = await fetchWithOrigin('/', 'https://cambeerfestival.app', 'OPTIONS');
		expect(response.headers.get('Access-Control-Allow-Methods')).toBe('GET, OPTIONS');
		expect(response.headers.get('Access-Control-Allow-Headers')).toBe('Content-Type');
	});

	it('returns 300s max-age for production origin', async () => {
		const response = await fetchWithOrigin('/', 'https://cambeerfestival.app', 'OPTIONS');
		expect(response.headers.get('Access-Control-Max-Age')).toBe('300');
	});

	it('returns 10s max-age for staging origin', async () => {
		const response = await fetchWithOrigin('/', 'https://staging.cambeerfestival.app', 'OPTIONS');
		expect(response.headers.get('Access-Control-Max-Age')).toBe('10');
	});

	it('returns 10s max-age for Pages preview URLs', async () => {
		const response = await fetchWithOrigin('/', 'https://abc123.cambeerfestival.pages.dev', 'OPTIONS');
		expect(response.headers.get('Access-Control-Max-Age')).toBe('10');
	});

	it('returns 10s max-age for staging Pages preview URLs', async () => {
		const response = await fetchWithOrigin('/', 'https://feature.staging-cambeerfestival.pages.dev', 'OPTIONS');
		expect(response.headers.get('Access-Control-Max-Age')).toBe('10');
	});

	it('returns 10s max-age for localhost', async () => {
		const response = await fetchWithOrigin('/', 'http://localhost:8080', 'OPTIONS');
		expect(response.headers.get('Access-Control-Max-Age')).toBe('10');
	});

	it('returns 10s max-age for 127.0.0.1', async () => {
		const response = await fetchWithOrigin('/', 'http://127.0.0.1:8080', 'OPTIONS');
		expect(response.headers.get('Access-Control-Max-Age')).toBe('10');
	});

	it('returns 10s max-age for Cloudflare Tunnel', async () => {
		const response = await fetchWithOrigin('/', 'https://my-tunnel.trycloudflare.com', 'OPTIONS');
		expect(response.headers.get('Access-Control-Max-Age')).toBe('10');
	});

	it('includes CORS origin header in preflight response', async () => {
		const response = await fetchWithOrigin('/', 'https://cambeerfestival.app', 'OPTIONS');
		expect(response.headers.get('Access-Control-Allow-Origin'))
			.toBe('https://cambeerfestival.app');
	});

	it('does not include CORS origin for rejected origins in preflight', async () => {
		const response = await fetchWithOrigin('/', 'https://evil.example.com', 'OPTIONS');
		expect(response.headers.get('Access-Control-Allow-Origin')).toBeNull();
	});
});
