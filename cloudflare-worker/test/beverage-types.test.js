import { vi, describe, it, expect, beforeEach, afterEach } from 'vitest';
import { env, createExecutionContext, waitOnExecutionContext } from 'cloudflare:test';
import worker from '../worker.js';

const UPSTREAM = 'https://data.cambridgebeerfestival.com';
const DIRECTORY_FETCH_INIT = {
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
	let mockFetch;

	beforeEach(() => {
		mockFetch = vi.fn();
		vi.stubGlobal('fetch', mockFetch);
	});

	afterEach(() => {
		vi.unstubAllGlobals();
	});

	it('parses directory listing into beverage types', async () => {
		mockFetch.mockResolvedValueOnce(new Response(
			makeDirectoryHtml(['beer.json', 'cider.json', 'perry.json', 'mead.json']),
			{ status: 200 },
		));

		const response = await fetchWorker('/cbf2025/available_beverage_types.json');
		expect(response.status).toBe(200);

		const data = await response.json();
		expect(data.festival_id).toBe('cbf2025');
		expect(data.available_beverage_types).toEqual(['beer', 'cider', 'mead', 'perry']);
		expect(mockFetch).toHaveBeenCalledWith(`${UPSTREAM}/cbf2025/`, DIRECTORY_FETCH_INIT);
	});

	it('returns types sorted alphabetically', async () => {
		mockFetch.mockResolvedValueOnce(new Response(
			makeDirectoryHtml(['wine.json', 'beer.json', 'apple-juice.json']),
			{ status: 200 },
		));

		const response = await fetchWorker('/cbf2025/available_beverage_types.json');
		const data = await response.json();
		expect(data.available_beverage_types).toEqual(['apple-juice', 'beer', 'wine']);
		expect(mockFetch).toHaveBeenCalledWith(`${UPSTREAM}/cbf2025/`, DIRECTORY_FETCH_INIT);
	});

	it('filters out available_beverage_types.json from results', async () => {
		mockFetch.mockResolvedValueOnce(new Response(
			makeDirectoryHtml(['beer.json', 'available_beverage_types.json', 'cider.json']),
			{ status: 200 },
		));

		const response = await fetchWorker('/cbf2025/available_beverage_types.json');
		const data = await response.json();
		expect(data.available_beverage_types).toEqual(['beer', 'cider']);
		expect(data.available_beverage_types).not.toContain('available_beverage_types');
		expect(mockFetch).toHaveBeenCalledWith(`${UPSTREAM}/cbf2025/`, DIRECTORY_FETCH_INIT);
	});

	it('returns empty array when no JSON files found', async () => {
		mockFetch.mockResolvedValueOnce(new Response(
			makeDirectoryHtml([]),
			{ status: 200 },
		));

		const response = await fetchWorker('/cbf2025/available_beverage_types.json');
		const data = await response.json();
		expect(data.available_beverage_types).toEqual([]);
		expect(mockFetch).toHaveBeenCalledWith(`${UPSTREAM}/cbf2025/`, DIRECTORY_FETCH_INIT);
	});

	it('returns 404 when festival not found upstream', async () => {
		mockFetch.mockResolvedValueOnce(new Response('Not Found', { status: 404 }));

		const response = await fetchWorker('/nonexistent/available_beverage_types.json');
		expect(response.status).toBe(404);

		const data = await response.json();
		expect(data.error).toBe('Festival not found');
		expect(data.festival_id).toBe('nonexistent');
		expect(mockFetch).toHaveBeenCalledWith(`${UPSTREAM}/nonexistent/`, DIRECTORY_FETCH_INIT);
	});

	it('returns 500 when upstream fetch fails', async () => {
		mockFetch.mockRejectedValueOnce(new Error('Connection refused'));

		const response = await fetchWorker('/cbf2025/available_beverage_types.json');
		expect(response.status).toBe(500);

		const data = await response.json();
		expect(data.error).toBe('Failed to fetch beverage types');
		expect(mockFetch).toHaveBeenCalledWith(`${UPSTREAM}/cbf2025/`, DIRECTORY_FETCH_INIT);
	});

	it('includes CORS headers on 500 error', async () => {
		mockFetch.mockRejectedValueOnce(new Error('Connection refused'));

		const response = await fetchWorker('/cbf2025/available_beverage_types.json');
		expect(response.headers.get('Access-Control-Allow-Origin'))
			.toBe('https://cambeerfestival.app');
		expect(mockFetch).toHaveBeenCalledWith(`${UPSTREAM}/cbf2025/`, DIRECTORY_FETCH_INIT);
	});

	it('includes CORS headers on success', async () => {
		mockFetch.mockResolvedValueOnce(new Response(
			makeDirectoryHtml(['beer.json']),
			{ status: 200 },
		));

		const response = await fetchWorker('/cbf2025/available_beverage_types.json');
		expect(response.headers.get('Access-Control-Allow-Origin'))
			.toBe('https://cambeerfestival.app');
		expect(mockFetch).toHaveBeenCalledWith(`${UPSTREAM}/cbf2025/`, DIRECTORY_FETCH_INIT);
	});

	it('includes CORS headers on 404', async () => {
		mockFetch.mockResolvedValueOnce(new Response('Not Found', { status: 404 }));

		const response = await fetchWorker('/nonexistent/available_beverage_types.json');
		expect(response.headers.get('Access-Control-Allow-Origin'))
			.toBe('https://cambeerfestival.app');
		expect(mockFetch).toHaveBeenCalledWith(`${UPSTREAM}/nonexistent/`, DIRECTORY_FETCH_INIT);
	});

	it('sets Cache-Control to 1 hour on success', async () => {
		mockFetch.mockResolvedValueOnce(new Response(
			makeDirectoryHtml(['beer.json']),
			{ status: 200 },
		));

		const response = await fetchWorker('/cbf2025/available_beverage_types.json');
		expect(response.headers.get('Cache-Control')).toBe('public, max-age=3600');
		expect(mockFetch).toHaveBeenCalledWith(`${UPSTREAM}/cbf2025/`, DIRECTORY_FETCH_INIT);
	});

	it('includes timestamp in response', async () => {
		mockFetch.mockResolvedValueOnce(new Response(
			makeDirectoryHtml(['beer.json']),
			{ status: 200 },
		));

		const response = await fetchWorker('/cbf2025/available_beverage_types.json');
		const data = await response.json();
		expect(data.timestamp).toBeDefined();
		expect(new Date(data.timestamp).toISOString()).toBe(data.timestamp);
		expect(mockFetch).toHaveBeenCalledWith(`${UPSTREAM}/cbf2025/`, DIRECTORY_FETCH_INIT);
	});

	it('handles hyphenated beverage type names', async () => {
		mockFetch.mockResolvedValueOnce(new Response(
			makeDirectoryHtml(['international-beer.json', 'low-no.json', 'apple-juice.json']),
			{ status: 200 },
		));

		const response = await fetchWorker('/cbf2025/available_beverage_types.json');
		const data = await response.json();
		expect(data.available_beverage_types).toEqual([
			'apple-juice', 'international-beer', 'low-no',
		]);
		expect(mockFetch).toHaveBeenCalledWith(`${UPSTREAM}/cbf2025/`, DIRECTORY_FETCH_INIT);
	});
});
