import { fetchPublicTarget, safeTarget, validViewer } from './playlist_relay.js';

const tokenPattern = /^\/v1\/media\/([A-Za-z0-9_-]{30,4000})\/stream(?:\.m3u8)?$/;
const lifetimeMs = 6 * 60 * 60 * 1000;
const maxManifestBytes = 2 * 1024 * 1024;

function headers(origin, type = 'text/plain; charset=utf-8') {
  const value = {
    'Cache-Control': 'no-store',
    'Content-Type': type,
    'Referrer-Policy': 'no-referrer',
    'X-Content-Type-Options': 'nosniff',
    'Access-Control-Allow-Methods': 'GET, HEAD, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Authorization, Content-Type, Range',
    'Access-Control-Expose-Headers': 'Accept-Ranges, Content-Length, Content-Range',
    Vary: 'Origin',
  };
  if (origin) value['Access-Control-Allow-Origin'] = origin;
  return value;
}

function error(status, origin, message) {
  return new Response(message, { status, headers: headers(origin) });
}

function base64url(bytes) {
  return btoa(String.fromCharCode(...bytes)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function decodeBase64url(value) {
  const raw = atob(value.replace(/-/g, '+').replace(/_/g, '/'));
  return Uint8Array.from(raw, c => c.charCodeAt(0));
}

async function mediaKey(secret) {
  const context = new TextEncoder().encode('tvium-media-relay-v1');
  const input = new Uint8Array(secret.length + context.length);
  input.set(secret);
  input.set(context, secret.length);
  const digest = await crypto.subtle.digest('SHA-256', input);
  return crypto.subtle.importKey('raw', digest, 'AES-GCM', false, ['encrypt', 'decrypt']);
}

async function seal(key, target, expires, scope = 'child') {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const payload = new TextEncoder().encode(JSON.stringify({ url: target.toString(), expires, scope }));
  const ciphertext = new Uint8Array(await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, key, payload));
  const token = new Uint8Array(iv.length + ciphertext.length);
  token.set(iv);
  token.set(ciphertext, iv.length);
  return base64url(token);
}

async function unseal(key, token, now) {
  try {
    const bytes = decodeBase64url(token);
    if (bytes.length < 30) return null;
    const plaintext = await crypto.subtle.decrypt(
      { name: 'AES-GCM', iv: bytes.slice(0, 12) }, key, bytes.slice(12));
    const payload = JSON.parse(new TextDecoder().decode(plaintext));
    if (!Number.isSafeInteger(payload.expires) || payload.expires <= now() ||
        payload.expires > now() + lifetimeMs) return null;
    if (payload.scope !== 'root' && payload.scope !== 'child') return null;
    const target = safeTarget(payload.url);
    return target == null ? null : { target, scope: payload.scope };
  } catch { return null; }
}

function relayUrl(base, token, target) {
  const hls = target.pathname.toLowerCase().endsWith('.m3u8');
  return `${base}/v1/media/${token}/stream${hls ? '.m3u8' : ''}`;
}

async function rewriteManifest(text, target, key, expires, base) {
  if (!text.startsWith('#EXTM3U')) return null;
  const rewritten = new Map();
  async function replace(value) {
    const url = safeTarget(new URL(value, target).toString());
    if (!url) throw new Error('Invalid HLS resource');
    if (!rewritten.has(url.href)) {
      rewritten.set(url.href, relayUrl(base, await seal(key, url, expires), url));
    }
    return rewritten.get(url.href);
  }
  const lines = [];
  for (const line of text.split('\n')) {
    if (line.startsWith('#')) {
      let updated = line;
      const matches = [...line.matchAll(/URI="([^"]+)"/g)];
      for (const match of matches) {
        updated = updated.replace(match[0], `URI="${await replace(match[1])}"`);
      }
      lines.push(updated);
    } else if (line.trim()) {
      lines.push(await replace(line.trim()));
    } else {
      lines.push(line);
    }
  }
  return lines.join('\n');
}

async function readManifest(body) {
  if (!body) return null;
  const reader = body.getReader();
  const decoder = new TextDecoder();
  let size = 0;
  let text = '';
  try {
    while (true) {
      const { value, done } = await reader.read();
      if (done) return text + decoder.decode();
      size += value.byteLength;
      if (size > maxManifestBytes) {
        await reader.cancel();
        return null;
      }
      text += decoder.decode(value, { stream: true });
    }
  } finally {
    reader.releaseLock();
  }
}

export async function handleMediaRelay(request, {
  secret,
  allowedOrigin = 'https://bfmix.github.io',
  now = Date.now,
  fetchImpl = fetch,
}) {
  const origin = request.headers.get('Origin');
  if (origin && origin !== allowedOrigin) return error(403, null, 'Forbidden');
  const corsOrigin = origin === allowedOrigin ? origin : null;
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: headers(corsOrigin) });
  if (!secret || secret.length < 32) return error(503, corsOrigin, 'Relay unavailable');
  const path = new URL(request.url).pathname;
  const key = await mediaKey(secret);
  if (path === '/v1/media-session') {
    if (request.method !== 'POST' || origin !== allowedOrigin) return error(405, corsOrigin, 'Method not allowed');
    if (!await validViewer(request.headers.get('Authorization'), secret, now)) {
      return error(403, corsOrigin, 'Pairing authorization expired');
    }
    if (!/^application\/json(?:;|$)/i.test(request.headers.get('Content-Type') ?? '')) {
      return error(415, corsOrigin, 'JSON required');
    }
    let target;
    try {
      const body = await request.text();
      if (body.length > 4096) return error(413, corsOrigin, 'Request too large');
      target = safeTarget(JSON.parse(body).url);
    } catch { return error(400, corsOrigin, 'Invalid request'); }
    if (!target) return error(400, corsOrigin, 'Invalid target');
    if (!/\.(?:m3u8|mp4|m4v|webm)$/i.test(target.pathname)) {
      return error(415, corsOrigin, 'Unsupported browser media format');
    }
    const token = await seal(key, target, now() + lifetimeMs, 'root');
    return new Response(JSON.stringify({ url: relayUrl(new URL(request.url).origin, token, target) }), {
      status: 201, headers: headers(corsOrigin, 'application/json; charset=utf-8'),
    });
  }

  const match = tokenPattern.exec(path);
  if (!match || !['GET', 'HEAD'].includes(request.method)) {
    return error(404, corsOrigin, 'Not found');
  }
  const token = await unseal(key, match[1], now);
  if (!token) return error(403, corsOrigin, 'Media link expired');
  const { target } = token;
  const range = request.headers.get('Range');
  if (range && !/^bytes=\d*-\d*$/.test(range)) return error(416, corsOrigin, 'Invalid range');
  try {
    const result = await fetchPublicTarget(target, {
      method: request.method,
      redirect: 'manual',
      cache: 'no-store',
      headers: range ? { Range: range } : {},
      signal: AbortSignal.timeout(35000),
    }, fetchImpl);
    if (!result) return error(502, corsOrigin, 'Media server unavailable');
    const upstream = result.response;
    if (![200, 206].includes(upstream.status)) return error(502, corsOrigin, 'Media server unavailable');
    const type = upstream.headers.get('Content-Type') ?? 'application/octet-stream';
    const hls = result.target.pathname.toLowerCase().endsWith('.m3u8') ||
      /(?:application\/(?:vnd\.apple\.mpegurl|x-mpegurl)|audio\/mpegurl)/i.test(type);
    if (hls && request.method === 'GET') {
      const body = await readManifest(upstream.body);
      if (body == null) return error(413, corsOrigin, 'Manifest too large');
      const rewritten = await rewriteManifest(body, result.target, key, now() + lifetimeMs,
        new URL(request.url).origin);
      if (rewritten == null) return error(502, corsOrigin, 'Invalid HLS manifest');
      return new Response(rewritten, {
        status: 200, headers: headers(corsOrigin, 'application/vnd.apple.mpegurl'),
      });
    }
    const responseHeaders = headers(corsOrigin, type);
    for (const name of ['Accept-Ranges', 'Content-Length', 'Content-Range']) {
      const value = upstream.headers.get(name);
      if (value) responseHeaders[name] = value;
    }
    return new Response(request.method === 'HEAD' ? null : upstream.body, {
      status: upstream.status, headers: responseHeaders,
    });
  } catch { return error(502, corsOrigin, 'Media server unavailable'); }
}
