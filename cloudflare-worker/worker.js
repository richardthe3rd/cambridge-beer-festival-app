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

    // Handle dynamic available_beverage_types.json endpoint
    // Pattern: /{festivalId}/available_beverage_types.json
    const availableTypesMatch = url.pathname.match(/^\/([^\/]+)\/available_beverage_types\.json$/);
    if (availableTypesMatch) {
      return handleAvailableBeverageTypes(availableTypesMatch[1], request);
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

/**
 * Dynamically discovers available beverage types for a festival
 * by fetching the directory listing from the upstream API
 *
 * @param {string} festivalId - The festival ID (e.g., 'cbf2025', 'cbfw2025')
 * @param {Request} request - The original request for CORS handling
 * @returns {Response} JSON response with available beverage types
 */
async function handleAvailableBeverageTypes(festivalId, request) {
  try {
    // Fetch the directory listing for this festival
    const upstreamUrl = `${UPSTREAM_URL}/${festivalId}/`;
    const response = await fetch(upstreamUrl, {
      headers: {
        'User-Agent': 'Cambridge-Beer-Festival-App-Proxy/1.0',
      },
    });

    if (!response.ok) {
      return new Response(JSON.stringify({
        error: 'Festival not found',
        festival_id: festivalId,
      }), {
        status: 404,
        headers: {
          'Content-Type': 'application/json',
          ...getCorsHeaders(request),
        },
      });
    }

    // Parse the HTML directory listing to find .json files
    const html = await response.text();
    const beverageTypes = parseDirectoryListingForBeverageTypes(html);

    // Return the list of available beverage types
    return new Response(JSON.stringify({
      festival_id: festivalId,
      available_beverage_types: beverageTypes,
      timestamp: new Date().toISOString(),
    }), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'public, max-age=3600', // Cache for 1 hour
        ...getCorsHeaders(request),
      },
    });
  } catch (error) {
    return new Response(JSON.stringify({
      error: 'Failed to fetch beverage types',
      message: error.message,
    }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json',
        ...getCorsHeaders(request),
      },
    });
  }
}

/**
 * Parses an Apache-style directory listing HTML to extract beverage type JSON files
 *
 * @param {string} html - The HTML content of the directory listing
 * @returns {string[]} Array of beverage type names (without .json extension)
 */
function parseDirectoryListingForBeverageTypes(html) {
  const beverageTypes = [];

  // Match href attributes that point to .json files
  // Regex pattern: <a href="filename.json">
  const jsonFilePattern = /<a href="([^"]+\.json)"/gi;
  let match;

  while ((match = jsonFilePattern.exec(html)) !== null) {
    const filename = match[1];

    // Skip the available_beverage_types.json itself to avoid recursion
    if (filename === 'available_beverage_types.json') {
      continue;
    }

    // Remove .json extension to get the beverage type name
    const beverageType = filename.replace(/\.json$/, '');
    beverageTypes.push(beverageType);
  }

  // Sort alphabetically for consistency
  return beverageTypes.sort();
}

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

  // Allow listed origins (exact match)
  if (ALLOWED_ORIGINS.includes(origin)) {
    return {
      'Access-Control-Allow-Origin': origin,
      'Access-Control-Allow-Credentials': 'true',
    };
  }

  // Allow Cloudflare Pages preview URLs (*.cambeerfestival.pages.dev)
  // This includes staging (main.cambeerfestival.pages.dev) and PR previews
  // Security note: This wildcard is safe because Cloudflare controls the .pages.dev
  // namespace. Only our cambeerfestival project can create subdomains under
  // cambeerfestival.pages.dev, preventing malicious domains from matching this pattern.
  if (origin.endsWith('.cambeerfestival.pages.dev')) {
    return {
      'Access-Control-Allow-Origin': origin,
      'Access-Control-Allow-Credentials': 'true',
    };
  }

  // Reject all other origins by not including CORS headers
  return {};
}

function setCorsHeaders(headers, request) {
  const corsHeaders = getCorsHeaders(request);
  for (const [key, value] of Object.entries(corsHeaders)) {
    headers.set(key, value);
  }
}
