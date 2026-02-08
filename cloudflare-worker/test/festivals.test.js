import { describe, it, expect } from 'vitest';
import { env, createExecutionContext, waitOnExecutionContext } from 'cloudflare:test';
import worker from '../worker.js';

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

describe('festivals.json endpoint', () => {
	it('returns 200 for /festivals.json', async () => {
		const response = await fetchWorker('/festivals.json');
		expect(response.status).toBe(200);
	});

	it('returns 200 for /festivals (alias)', async () => {
		const response = await fetchWorker('/festivals');
		expect(response.status).toBe(200);
	});

	it('returns valid JSON', async () => {
		const response = await fetchWorker('/festivals.json');
		const data = await response.json();
		expect(data).toBeDefined();
		expect(data.festivals).toBeInstanceOf(Array);
		expect(data.festivals.length).toBeGreaterThan(0);
	});

	it('contains required festival fields', async () => {
		const response = await fetchWorker('/festivals.json');
		const data = await response.json();
		const festival = data.festivals[0];

		expect(festival.id).toBeDefined();
		expect(festival.name).toBeDefined();
		expect(festival.start_date).toBeDefined();
		expect(festival.end_date).toBeDefined();
		expect(festival.data_base_url).toBeDefined();
	});

	it('contains default_festival_id', async () => {
		const response = await fetchWorker('/festivals.json');
		const data = await response.json();
		expect(data.default_festival_id).toBeDefined();
		expect(typeof data.default_festival_id).toBe('string');
	});

	it('default_festival_id references an existing festival', async () => {
		const response = await fetchWorker('/festivals.json');
		const data = await response.json();
		const ids = data.festivals.map((f) => f.id);
		expect(ids).toContain(data.default_festival_id);
	});

	it('sets Content-Type to application/json with charset', async () => {
		const response = await fetchWorker('/festivals.json');
		expect(response.headers.get('Content-Type'))
			.toBe('application/json; charset=utf-8');
	});

	it('sets Cache-Control to no-cache', async () => {
		const response = await fetchWorker('/festivals.json');
		expect(response.headers.get('Cache-Control'))
			.toBe('no-cache, must-revalidate');
	});

	it('includes CORS headers', async () => {
		const response = await fetchWorker('/festivals.json');
		expect(response.headers.get('Access-Control-Allow-Origin'))
			.toBe('https://cambeerfestival.app');
	});

	it('/festivals and /festivals.json return the same data', async () => {
		const response1 = await fetchWorker('/festivals.json');
		const response2 = await fetchWorker('/festivals');
		const data1 = await response1.json();
		const data2 = await response2.json();
		expect(data1).toEqual(data2);
	});
});
