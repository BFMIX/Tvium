import { createHmac, randomBytes, timingSafeEqual } from 'node:crypto';

const lifetimeSeconds = 600;
const idPattern = /^([a-z0-9]{6,10})-([A-Za-z0-9_-]{22})$/;
const tokenPattern = /^[A-Za-z0-9_-]{43}$/;
const sessionPath = /^\/v1\/pairing\/([^/]+)$/;
const submissionPath = /^\/v1\/pairing\/([^/]+)\/submission$/;

function response(status, body, origin) {
  const headers = {
    'Cache-Control': 'no-store',
    'Content-Type': 'application/json',
    'Referrer-Policy': 'no-referrer',
    'X-Content-Type-Options': 'nosniff',
    Vary: 'Origin',
  };
  if (origin) {
    headers['Access-Control-Allow-Origin'] = origin;
    headers['Access-Control-Allow-Methods'] = 'GET, POST, DELETE';
    headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization';
  }
  return new Response(body === undefined ? null : JSON.stringify(body), { status, headers });
}

function token(secret, purpose, id) {
  return createHmac('sha256', secret).update(`${purpose}:${id}`).digest('base64url');
}

function authorized(header, expected) {
  if (typeof header !== 'string' || !header.startsWith('Bearer ')) return false;
  const candidate = header.slice(7);
  if (!tokenPattern.test(candidate)) return false;
  return timingSafeEqual(Buffer.from(candidate), Buffer.from(expected));
}

function validSession(id, now) {
  const match = idPattern.exec(id);
  if (!match) return false;
  const created = Number.parseInt(match[1], 36);
  const age = Math.floor(now() / 1000) - created;
  return age >= -30 && age < lifetimeSeconds;
}

function validPayload(payload) {
  return payload && typeof payload === 'object' && !Array.isArray(payload) &&
    Object.keys(payload).sort().join(',') === 'ciphertext,iv' &&
    typeof payload.iv === 'string' && /^[A-Za-z0-9_-]{16}$/.test(payload.iv) &&
    typeof payload.ciphertext === 'string' &&
    /^[A-Za-z0-9_-]{22,4000}$/.test(payload.ciphertext);
}

export async function handleNetlifyPairing(request, { store, secret, allowedOrigin, now = Date.now }) {
  if (!Buffer.isBuffer(secret) || secret.length < 32) {
    throw new Error('Pairing secret must contain at least 32 bytes');
  }
  const url = new URL(request.url);
  const browserOrigin = request.headers.get('Origin');
  const origin = browserOrigin === allowedOrigin || browserOrigin === url.origin
    ? browserOrigin : null;
  if (browserOrigin && !origin) return response(403, { error: 'origin_not_allowed' });
  if (request.method === 'OPTIONS') return response(204, undefined, origin);

  if (url.pathname === '/v1/pairing') {
    if (request.method !== 'POST') return response(405, { error: 'method_not_allowed' }, origin);
    const id = `${Math.floor(now() / 1000).toString(36)}-${randomBytes(16).toString('base64url')}`;
    return response(201, {
      id,
      viewerToken: token(secret, 'viewer', id),
      submitToken: token(secret, 'submit', id),
      expiresInSeconds: lifetimeSeconds,
    }, origin);
  }
  const submissionMatch = submissionPath.exec(url.pathname);
  const sessionMatch = sessionPath.exec(url.pathname);
  const id = (submissionMatch ?? sessionMatch)?.[1];
  if (!id || !validSession(id, now)) return response(404, { error: 'not_found' }, origin);

  if (submissionMatch && request.method === 'POST') {
    if (!authorized(request.headers.get('Authorization'), token(secret, 'submit', id))) {
      return response(403, { error: 'forbidden' }, origin);
    }
    if (!/^application\/json(?:;|$)/i.test(request.headers.get('Content-Type') ?? '')) {
      return response(415, { error: 'json_required' }, origin);
    }
    let payload;
    try {
      const body = await request.text();
      if (body.length > 4096) return response(413, { error: 'payload_too_large' }, origin);
      payload = JSON.parse(body);
    } catch {
      return response(400, { error: 'invalid_payload' }, origin);
    }
    if (!validPayload(payload)) return response(400, { error: 'invalid_payload' }, origin);
    const { modified } = await store.setJSON(`p/${id}`, payload, { onlyIfNew: true });
    return modified
      ? response(202, { status: 'received' }, origin)
      : response(409, { error: 'already_received' }, origin);
  }
  if (!authorized(request.headers.get('Authorization'), token(secret, 'viewer', id))) {
    return response(403, { error: 'forbidden' }, origin);
  }
  if (submissionMatch && request.method === 'GET') {
    const payload = await store.get(`p/${id}`, { type: 'json', consistency: 'strong' });
    return payload
      ? response(200, payload, origin)
      : response(202, { status: 'pending' }, origin);
  }
  if (sessionMatch && request.method === 'DELETE') {
    await store.delete(`p/${id}`);
    return response(204, undefined, origin);
  }
  return response(405, { error: 'method_not_allowed' }, origin);
}
