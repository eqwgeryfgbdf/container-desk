// Cloudflare supplies this country from the incoming connection, not client input.
export function languageForCountry(country) {
  if (typeof country !== 'string' || !/^[A-Z]{2}$/.test(country) || country === 'XX') return null;
  if (['TW', 'HK', 'MO'].includes(country)) return 'zh-Hant';
  if (country === 'CN') return 'zh-Hans';
  return 'en';
}
export default {
  async fetch(request, env) {
    if (new URL(request.url).pathname !== '/api/locale') return env.ASSETS.fetch(request);
    const headers = {
      'Cache-Control': 'private, no-store',
      'X-Content-Type-Options': 'nosniff',
      'Content-Security-Policy': "default-src 'none'; frame-ancestors 'none'",
      'Referrer-Policy': 'no-referrer',
    };
    if (!['GET', 'HEAD'].includes(request.method)) {
      return new Response(null, { status: 405, headers: { ...headers, Allow: 'GET, HEAD' } });
    }
    const language = languageForCountry(request.cf?.country);
    // Never expose or store an IP address, city, or precise location.
    const response = Response.json({ language, source: language ? 'region' : 'browser' }, { headers });
    return request.method === 'HEAD' ? new Response(null, response) : response;
  },
};
