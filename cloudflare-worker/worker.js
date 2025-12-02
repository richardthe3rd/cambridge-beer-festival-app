/**
 * Cloudflare Worker - CORS Proxy for Cambridge Beer Festival Data API
 * 
 * This worker proxies requests to data.cambridgebeerfestival.com and adds
 * the necessary CORS headers to allow the web app to access the data.
 * 
 * It also serves the festivals.json file which contains festival metadata
 * and enables dynamic loading of festival drinks.
 */

// Import festivals data directly - copied from data/festivals.json during build
import festivalsData from './festivals.json';

const UPSTREAM_URL = 'https://data.cambridgebeerfestival.com';

// Cache control for festivals.json
// Use no-cache to ensure browsers revalidate on each request while still caching
// This ensures updates are visible immediately while allowing conditional requests
const FESTIVALS_CACHE_CONTROL = 'no-cache, must-revalidate';

// Allowed origins for CORS
const ALLOWED_ORIGINS = [
  'https://richardthe3rd.github.io',
  'https://cambeerfestival.app',
  'http://localhost:8080',
  'http://localhost:3000',
  'http://127.0.0.1:8080',
];

export default {
  async fetch(request, env, ctx) {
    // Handle CORS preflight requests
    if (request.method === 'OPTIONS') {
      return handleCorsPreflight(request);
    }

    const url = new URL(request.url);
    
    // Health check endpoint
    if (url.pathname === '/health') {
      return new Response(JSON.stringify({ status: 'ok' }), {
        headers: { 
          'Content-Type': 'application/json',
          ...getCorsHeaders(request),
        },
      });
    }

    // Serve festivals.json directly from embedded data
    if (url.pathname === '/festivals.json' || url.pathname === '/festivals') {
      return new Response(JSON.stringify(festivalsData), {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': FESTIVALS_CACHE_CONTROL,
          ...getCorsHeaders(request),
        },
      });
    }

    // Proxy the request to the upstream API
    const upstreamUrl = UPSTREAM_URL + url.pathname + url.search;
    
    try {
      const response = await fetch(upstreamUrl, {
        method: request.method,
        headers: {
          'User-Agent': 'Cambridge-Beer-Festival-App-Proxy/1.0',
        },
      });

      // Clone the response and add CORS headers
      const newHeaders = new Headers(response.headers);
      setCorsHeaders(newHeaders, request);

      return new Response(response.body, {
        status: response.status,
        statusText: response.statusText,
        headers: newHeaders,
      });
    } catch (error) {
      return new Response(JSON.stringify({ error: 'Proxy error', message: error.message }), {
        status: 502,
        headers: {
          'Content-Type': 'application/json',
          ...getCorsHeaders(request),
        },
      });
    }
  },
};

function handleCorsPreflight(request) {
  return new Response(null, {
    status: 204,
    headers: {
      ...getCorsHeaders(request),
      'Access-Control-Allow-Methods': 'GET, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
      'Access-Control-Max-Age': '86400',
    },
  });
}

function getCorsHeaders(request) {
  const origin = request.headers.get('Origin') || '';
  
  // Only allow listed origins - reject others by not including CORS headers
  if (!ALLOWED_ORIGINS.includes(origin)) {
    return {};
  }
  
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Credentials': 'true',
  };
}

function setCorsHeaders(headers, request) {
  const corsHeaders = getCorsHeaders(request);
  for (const [key, value] of Object.entries(corsHeaders)) {
    headers.set(key, value);
  }
}
