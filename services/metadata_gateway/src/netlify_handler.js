import { validateQuery } from './gateway.js';

export function createNetlifyHandler({ search, origins = [], maxBodyBytes = 2048 }) {
  const allowedOrigins = new Set(origins);
  return async request => {
    const headers = new Headers({
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
    });
    const send = (status, value) => new Response(status === 204 ? null : JSON.stringify(value), { status, headers });
    const origin = request.headers.get('origin');
    if (origin) {
      if (!allowedOrigins.has(origin)) return send(403, { error: 'origin_not_allowed' });
      headers.set('Access-Control-Allow-Origin', origin);
      headers.set('Vary', 'Origin');
    }
    if (request.method === 'OPTIONS') {
      headers.set('Access-Control-Allow-Methods', 'POST');
      headers.set('Access-Control-Allow-Headers', 'Content-Type');
      return send(204);
    }
    if (request.method !== 'POST') return send(404, { error: 'not_found' });
    if (!/^application\/json(?:;|$)/i.test(request.headers.get('content-type') ?? '')) {
      return send(415, { error: 'json_required' });
    }
    const reader = request.body?.getReader();
    if (!reader) return send(400, { error: 'invalid_request' });
    const chunks = [];
    let size = 0;
    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        size += value.byteLength;
        if (size > maxBodyBytes) {
          await reader.cancel();
          return send(413, { error: 'request_too_large' });
        }
        chunks.push(value);
      }
      const bytes = new Uint8Array(size);
      let offset = 0;
      for (const chunk of chunks) {
        bytes.set(chunk, offset);
        offset += chunk.byteLength;
      }
      let query;
      try {
        query = validateQuery(JSON.parse(new TextDecoder().decode(bytes)));
      } catch {
        return send(400, { error: 'invalid_query' });
      }
      try {
        return send(200, await search(query));
      } catch {
        return send(503, { error: 'metadata_unavailable' });
      }
    } catch {
      return send(400, { error: 'invalid_request' });
    }
  };
}
