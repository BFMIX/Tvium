import http from 'node:http';

const hosts = new Set(['api.themoviedb.org', 'api.tvmaze.com', 'iptv-org.github.io']);
const unsafe = /(?:[a-z][a-z0-9+.-]*:\/|\/\/|www\.|[\w.-]+\.[a-z]{2,}(?:\/|:\d)|[\w.+-]+@[\w.-]+|(?:password|passwd|username|token|api[_ -]?key)\s*[:=]|[?&][\w]+=[^\s]+|%[0-9a-f]{2}|#EXTM3U|#EXTINF)/i;
const bareAddress = /^(?:(?:[a-z0-9-]+\.)+[a-z]{2,63}|(?:\d{1,3}\.){3}\d{1,3})(?::\d{1,5})?$/i;
const normalize = value => value.normalize('NFKD').replace(/\p{M}/gu, '').toLowerCase().replace(/[^\p{L}\p{N}]+/gu, ' ').trim();
const clean = value => typeof value === 'string' ? value.replace(/<[^>]*>/g, '').slice(0, 2000) : undefined;
const yearOf = value => /^\d{4}/.test(value ?? '') ? Number(value.slice(0, 4)) : undefined;

export function validateQuery(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value) ||
      Object.keys(value).some(key => !['title', 'kind', 'year', 'language'].includes(key)) ||
      typeof value.title !== 'string' || value.title.trim().length < 2 || value.title.length > 200 ||
      /[\x00-\x1f\x7f]/.test(value.title) || unsafe.test(value.title) || bareAddress.test(value.title.trim()) ||
      !['movie', 'series', 'live'].includes(value.kind) ||
      (value.year !== undefined && (!Number.isInteger(value.year) || value.year < 1880 || value.year > 2100)) ||
      (value.language !== undefined && (typeof value.language !== 'string' || !/^[a-z]{2}(?:-[A-Z]{2})?$/.test(value.language)))) {
    throw new Error('invalid_query');
  }
  return { title: value.title.trim(), kind: value.kind, ...(value.year ? { year: value.year } : {}), language: value.language ?? 'en-US' };
}

export function createSearch({ fetchImpl = fetch, token = '', now = Date.now, ttlMs = 3600000, maxCache = 500, timeoutMs = 5000, upstreamRateLimit = 60 } = {}) {
  const cache = new Map();
  let channels;
  let channelPromise;
  let active = 0;
  let upstreamWindow = { expires: 0, count: 0 };
  async function json(url, headers = {}, maxBytes = 1024 * 1024) {
    if (upstreamWindow.expires <= now()) upstreamWindow = { expires: now() + 60000, count: 0 };
    if (++upstreamWindow.count > upstreamRateLimit) throw new Error('upstream_unavailable');
    const address = new URL(url);
    if (address.protocol !== 'https:' || !hosts.has(address.hostname) || address.username || address.password || address.port) throw new Error('upstream_unavailable');
    const response = await fetchImpl(address, { headers, redirect: 'error', signal: AbortSignal.timeout(timeoutMs) });
    if (!response.ok || Number(response.headers.get('content-length')) > maxBytes) throw new Error('upstream_unavailable');
    const reader = response.body.getReader();
    const chunks = [];
    let size = 0;
    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        size += value.byteLength;
        if (size > maxBytes) throw new Error('upstream_unavailable');
        chunks.push(value);
      }
      return JSON.parse(Buffer.concat(chunks).toString('utf8'));
    } finally { await reader.cancel(); }
  }
  async function tmdb(query) {
    const type = query.kind === 'movie' ? 'movie' : 'tv';
    const url = new URL(`https://api.themoviedb.org/3/search/${type}`);
    url.search = new URLSearchParams({ query: query.title, language: query.language, include_adult: 'false', ...(query.year ? { [type === 'movie' ? 'year' : 'first_air_date_year']: String(query.year) } : {}) });
    const data = await json(url, { Authorization: `Bearer ${token}` });
    if (!Array.isArray(data.results)) throw new Error('upstream_unavailable');
    const candidates = data.results.filter(item => Number.isInteger(item.id) && typeof (item.title ?? item.name) === 'string').slice(0, 20).map(item => ({
      id: String(item.id), provider: 'tmdb', title: clean(item.title ?? item.name), originalTitle: clean(item.original_title ?? item.original_name), kind: query.kind,
      year: yearOf(item.release_date ?? item.first_air_date), overview: clean(item.overview),
      posterUrl: /^\/[a-zA-Z0-9._-]+$/.test(item.poster_path ?? '') ? `https://image.tmdb.org/t/p/w500${item.poster_path}` : undefined,
      backdropUrl: /^\/[a-zA-Z0-9._-]+$/.test(item.backdrop_path ?? '') ? `https://image.tmdb.org/t/p/w1280${item.backdrop_path}` : undefined,
      sourceUrl: `https://www.themoviedb.org/${type}/${item.id}`, license: 'TMDB terms; attribution required; non-commercial API use',
    }));
    const title = normalize(query.title);
    if (query.year && !candidates.some(item =>
      item.year === query.year && [item.title, item.originalTitle].some(name => typeof name === 'string' && normalize(name) === title))) {
      for (const candidate of candidates.filter(item => item.year === query.year).slice(0, 3)) {
        try {
          const details = await json(`https://api.themoviedb.org/3/${type}/${candidate.id}/alternative_titles`, { Authorization: `Bearer ${token}` });
          const aliases = type === 'movie' ? details.titles : details.results;
          if (!Array.isArray(aliases)) continue;
          const matches = aliases.map(item => item?.title).filter(name =>
            typeof name === 'string' && name.length <= 200 && !unsafe.test(name) &&
            !bareAddress.test(name.trim()) && normalize(name) === title);
          if (matches.length) candidate.alternativeTitles = [...new Set(matches)].slice(0, 5);
        } catch { /* Optional verification must not discard search results. */ }
      }
    }
    return candidates;
  }
  async function tvmaze(query) {
    const url = new URL('https://api.tvmaze.com/search/shows');
    url.searchParams.set('q', query.title);
    const data = await json(url);
    if (!Array.isArray(data)) throw new Error('upstream_unavailable');
    return data.map(item => item.show).filter(item => item && Number.isInteger(item.id) && typeof item.name === 'string').slice(0, 20).map(item => ({
      id: String(item.id), provider: 'tvmaze', title: clean(item.name), kind: 'series', year: yearOf(item.premiered),
      overview: clean(item.summary), posterUrl: /^https:\/\/static\.tvmaze\.com\/uploads\/[a-zA-Z0-9/._-]+$/.test(item.image?.medium ?? '') ? item.image.medium : undefined,
      sourceUrl: `https://www.tvmaze.com/shows/${item.id}`, license: 'CC BY-SA 4.0',
    }));
  }
  async function live(query) {
    if (!channels || channels.expires <= now()) {
      channelPromise ??= json('https://iptv-org.github.io/api/channels.json', {}, 20 * 1024 * 1024).then(data => {
        if (!Array.isArray(data)) throw new Error('upstream_unavailable');
        channels = { value: data.filter(item => typeof item.id === 'string' && typeof item.name === 'string').map(item => ({ id: item.id, name: item.name, aliases: Array.isArray(item.alt_names) ? item.alt_names.filter(x => typeof x === 'string') : [] })), expires: now() + 86400000 };
      }).finally(() => { channelPromise = undefined; });
      await channelPromise;
    }
    const title = normalize(query.title);
    return channels.value.filter(item => [item.name, ...item.aliases].some(name => normalize(name) === title)).slice(0, 20).map(item => ({
      id: item.id, provider: 'iptv-org', title: item.name, kind: 'live', sourceUrl: 'https://github.com/iptv-org/database', license: 'Public domain (database); third-party marks retain their rights',
    }));
  }
  return async value => {
    const query = validateQuery(value);
    const key = JSON.stringify(query);
    const cached = cache.get(key);
    if (cached && cached.expires > now()) return structuredClone(cached.value);
    if (active >= 8) throw new Error('upstream_unavailable');
    active++;
    try {
      let candidates;
      if (query.kind === 'live') candidates = await live(query);
      else {
        if (token) {
          try { candidates = await tmdb(query); } catch { if (query.kind === 'movie') throw new Error('upstream_unavailable'); }
        }
        if (query.kind === 'series' && !candidates?.length) candidates = await tvmaze(query);
        if (!candidates) throw new Error('provider_not_configured');
      }
      const result = { candidates };
      if (cache.size >= maxCache) cache.delete(cache.keys().next().value);
      cache.set(key, { value: result, expires: now() + ttlMs });
      return structuredClone(result);
    } finally { active--; }
  };
}

export function createGateway({ search = createSearch(), origins = [], now = Date.now, rateLimit = 60, maxBodyBytes = 2048 } = {}) {
  const clients = new Map();
  const allowedOrigins = new Set((Array.isArray(origins) ? origins : []).filter(value => {
    if (typeof value !== 'string' || value === 'null' || value === '*') return false;
    try {
      const address = new URL(value);
      return ['http:', 'https:'].includes(address.protocol) && address.origin === value && !address.username && !address.password;
    } catch {
      return false;
    }
  }));
  return http.createServer({ requestTimeout: 10000, headersTimeout: 10000 }, async (req, res) => {
    res.setHeader('Content-Type', 'application/json');
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    const send = (status, body) => { res.writeHead(status); res.end(JSON.stringify(body)); };
    if (req.headers.origin) {
      if (!allowedOrigins.has(req.headers.origin)) return send(403, { error: 'origin_not_allowed' });
      res.setHeader('Access-Control-Allow-Origin', req.headers.origin);
      res.setHeader('Vary', 'Origin');
    }
    if (req.method === 'OPTIONS' && req.url === '/v1/search') {
      res.setHeader('Access-Control-Allow-Methods', 'POST');
      res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
      return send(204, undefined);
    }
    if (req.method !== 'POST' || req.url !== '/v1/search') return send(404, { error: 'not_found' });
    const address = req.socket.remoteAddress;
    for (const [key, record] of clients) if (record.expires <= now()) clients.delete(key);
    if (!clients.has(address)) {
      if (clients.size >= 4096) return send(429, { error: 'rate_limited' });
      clients.set(address, { count: 0, expires: now() + 60000 });
    }
    if (++clients.get(address).count > rateLimit) return send(429, { error: 'rate_limited' });
    if (!/^application\/json(?:;|$)/i.test(req.headers['content-type'] ?? '')) return send(415, { error: 'json_required' });
    const chunks = [];
    let bytes = 0;
    try {
      for await (const chunk of req) {
        bytes += chunk.length;
        if (bytes > maxBodyBytes) { send(413, { error: 'request_too_large' }); return; }
        chunks.push(chunk);
      }
      let query;
      try { query = validateQuery(JSON.parse(Buffer.concat(chunks).toString('utf8'))); } catch { return send(400, { error: 'invalid_query' }); }
      try { send(200, await search(query)); } catch { send(503, { error: 'metadata_unavailable' }); }
    } catch { if (!res.headersSent) send(400, { error: 'invalid_request' }); }
  });
}
