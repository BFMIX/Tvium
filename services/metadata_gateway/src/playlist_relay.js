const idPattern = /^([a-z0-9]{6,10})-([A-Za-z0-9_-]{22})$/;
const tokenPattern = /^[A-Za-z0-9_-]{43}$/;

function reply(status, origin, body) {
  return new Response(body, {
    status,
    headers: {
      'Access-Control-Allow-Origin': origin,
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Authorization, Content-Type',
      'Cache-Control': 'no-store',
      'Content-Type': 'text/plain; charset=utf-8',
      'Referrer-Policy': 'no-referrer',
      'X-Content-Type-Options': 'nosniff',
      Vary: 'Origin',
    },
  });
}

function safeTarget(value) {
  if (typeof value !== 'string' || value.length > 2048) return null;
  let url;
  try { url = new URL(value); } catch { return null; }
  if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password ||
      url.hash || !url.hostname || url.hostname.length > 253) return null;
  const host = url.hostname.toLowerCase().replace(/\.$/, '');
  if (host === 'localhost' || host.endsWith('.localhost') ||
      host.endsWith('.local') || host.endsWith('.internal') ||
      host.startsWith('[') || /^\d+$/.test(host)) return null;
  const parts = host.split('.');
  if (parts.length < 2) return null;
  if (/^\d+\.\d+\.\d+\.\d+$/.test(host)) {
    const octets = parts.map(Number);
    const [a, b] = octets;
    if (octets.some(n => n < 0 || n > 255) || a === 0 || a === 10 ||
        a === 127 || a >= 224 || a === 169 && b === 254 ||
        a === 172 && b >= 16 && b <= 31 || a === 192 && b === 168 ||
        a === 100 && b >= 64 && b <= 127 || a === 198 && (b === 18 || b === 19)) return null;
  }
  return url;
}

async function validViewer(header, secret, now) {
  const match = /^Bearer ([^.]+)\.([A-Za-z0-9_-]{43})$/.exec(header ?? '');
  if (!match || !idPattern.test(match[1]) || !tokenPattern.test(match[2]) ||
      !secret || secret.length < 32) return false;
  const created = Number.parseInt(match[1].split('-')[0], 36);
  const age = Math.floor(now() / 1000) - created;
  if (age < -30 || age >= 600) return false;
  const key = await crypto.subtle.importKey('raw', secret, { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const digest = new Uint8Array(await crypto.subtle.sign('HMAC', key,
    new TextEncoder().encode(`viewer:${match[1]}`)));
  const expected = btoa(String.fromCharCode(...digest)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  let difference = 0;
  for (let i = 0; i < expected.length; i++) difference |= expected.charCodeAt(i) ^ match[2].charCodeAt(i);
  return difference === 0;
}

export async function handlePlaylistRelay(request, {
  secret, allowedOrigin = 'https://bfmix.github.io', now = Date.now,
  fetchImpl = fetch,
}) {
  const origin = request.headers.get('Origin');
  if (origin !== allowedOrigin) return new Response('Forbidden', { status: 403 });
  if (request.method === 'OPTIONS') return reply(204, origin, null);
  if (request.method !== 'POST') return reply(405, origin, 'Method not allowed');
  if (!await validViewer(request.headers.get('Authorization'), secret, now)) {
    return reply(403, origin, 'Pairing authorization expired');
  }
  if (!/^application\/json(?:;|$)/i.test(request.headers.get('Content-Type') ?? '')) {
    return reply(415, origin, 'JSON required');
  }
  let target;
  try {
    const body = await request.text();
    if (body.length > 4096) return reply(413, origin, 'Request too large');
    target = safeTarget(JSON.parse(body).url);
  } catch { return reply(400, origin, 'Invalid request'); }
  if (!target) return reply(400, origin, 'Invalid target');
  try {
    const upstream = await fetchImpl(target, {
      method: 'GET', redirect: 'manual', cache: 'no-store',
      signal: AbortSignal.timeout(35000),
    });
    if (upstream.status < 200 || upstream.status >= 300) {
      return reply(502, origin, `Playlist server returned ${upstream.status}`);
    }
    const response = reply(200, origin, upstream.body);
    return response;
  } catch {
    return reply(502, origin, 'Playlist server unavailable');
  }
}
