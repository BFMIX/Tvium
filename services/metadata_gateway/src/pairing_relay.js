import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';

const token = bytes => randomBytes(bytes).toString('base64url');
const digest = value => createHash('sha256').update(value).digest();
const validId = '[A-Za-z0-9_-]{16,64}';
const submissionPath = new RegExp(`^/v1/pairing/(${validId})/submission$`);
const sessionPath = new RegExp(`^/v1/pairing/(${validId})$`);

function authorized(header, expected) {
  if (typeof header !== 'string' || !header.startsWith('Bearer ')) return false;
  const candidate = header.slice(7);
  if (!/^[A-Za-z0-9_-]{32,128}$/.test(candidate)) return false;
  return timingSafeEqual(digest(candidate), expected);
}

async function readOpaqueBody(request) {
  if (!/^application\/json(?:;|$)/i.test(request.headers['content-type'] ?? '')) return null;
  let bytes = 0;
  const chunks = [];
  for await (const chunk of request) {
    bytes += chunk.length;
    if (bytes > 4096) return null;
    chunks.push(chunk);
  }
  try {
    const value = JSON.parse(Buffer.concat(chunks).toString('utf8'));
    if (!value || typeof value !== 'object' || Array.isArray(value) ||
        Object.keys(value).sort().join(',') !== 'ciphertext,iv' ||
        typeof value.iv !== 'string' || !/^[A-Za-z0-9_-]{16}$/.test(value.iv) ||
        typeof value.ciphertext !== 'string' || !/^[A-Za-z0-9_-]{22,4000}$/.test(value.ciphertext)) return null;
    return value;
  } catch { return null; }
}

export function createPairingRelay({ now = Date.now, lifetimeMs = 600000, maxSessions = 1024, maxClients = 4096 } = {}) {
  const sessions = new Map();
  const clients = new Map();
  return async function handle(request, send) {
    const path = request.url?.split('?')[0] ?? '';
    if (path !== '/v1/pairing' && !submissionPath.test(path) && !sessionPath.test(path)) return false;

    for (const [id, session] of sessions) if (session.expires <= now()) sessions.delete(id);
    for (const [address, record] of clients) if (record.expires <= now()) clients.delete(address);

    if (path === '/v1/pairing') {
      if (request.method !== 'POST') { send(405, { error: 'method_not_allowed' }); return true; }
      const address = request.socket.remoteAddress ?? 'unknown';
      if (!clients.has(address) && clients.size >= maxClients) { send(429, { error: 'rate_limited' }); return true; }
      const record = clients.get(address) ?? { count: 0, expires: now() + 60000 };
      clients.set(address, record);
      if (++record.count > 10 || sessions.size >= maxSessions) { send(429, { error: 'rate_limited' }); return true; }
      const id = token(16);
      const viewerToken = token(32);
      const submitToken = token(32);
      sessions.set(id, { viewerDigest: digest(viewerToken), submitDigest: digest(submitToken), expires: now() + lifetimeMs, payload: null });
      send(201, { id, viewerToken, submitToken, expiresInSeconds: Math.floor(lifetimeMs / 1000) });
      return true;
    }

    const match = submissionPath.exec(path) ?? sessionPath.exec(path);
    const session = sessions.get(match[1]);
    if (!session) { send(404, { error: 'not_found' }); return true; }
    const isSubmission = path.endsWith('/submission');
    if (isSubmission && request.method === 'POST') {
      if (!authorized(request.headers.authorization, session.submitDigest)) { send(403, { error: 'forbidden' }); return true; }
      if (session.payload) { send(409, { error: 'already_received' }); return true; }
      const payload = await readOpaqueBody(request);
      if (!payload) { send(400, { error: 'invalid_payload' }); return true; }
      session.payload = payload;
      send(202, { status: 'received' });
      return true;
    }
    if (!authorized(request.headers.authorization, session.viewerDigest)) { send(403, { error: 'forbidden' }); return true; }
    if (isSubmission && request.method === 'GET') {
      if (!session.payload) send(202, { status: 'pending' });
      else send(200, session.payload);
      return true;
    }
    if (!isSubmission && request.method === 'DELETE') {
      sessions.delete(match[1]);
      send(204);
      return true;
    }
    send(405, { error: 'method_not_allowed' });
    return true;
  };
}
