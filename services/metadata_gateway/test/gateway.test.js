import test from 'node:test';
import assert from 'node:assert/strict';
import { createGateway, createSearch, validateQuery } from '../src/gateway.js';

const response = value => new Response(JSON.stringify(value), { headers: { 'Content-Type': 'application/json' } });
const movie = { title: 'Example Movie', kind: 'movie', year: 2020 };

test('rejects extra fields, URLs, credentials, malformed types and oversized titles', () => {
  for (const value of [null, [], { ...movie, password: 'private' }, { ...movie, title: 'https://example.test/playlist' }, { ...movie, title: 'user@example.test' }, { ...movie, title: 'username=private' }, { ...movie, title: 'x'.repeat(201) }, { ...movie, language: '../x' }, { ...movie, year: '2020' }]) {
    assert.throws(() => validateQuery(value), /invalid_query/);
  }
});

test('rejects bare provider hosts and IP addresses', () => {
  for (const title of ['provider.example.com', 'provider.example.com:8080', '192.0.2.10', '192.0.2.10:8080']) {
    assert.throws(() => validateQuery({ ...movie, title }), /invalid_query/);
  }
});

test('ordinary title punctuation is preserved and upstream budget is global', async () => {
  assert.equal(validateQuery({ ...movie, title: 'Star Wars: A New Hope & More' }).title, 'Star Wars: A New Hope & More');
  let calls = 0;
  const search = createSearch({ token: 'test', upstreamRateLimit: 1, fetchImpl: async () => { calls++; return response({ results: [] }); } });
  await search(movie);
  await assert.rejects(search({ ...movie, title: 'Different film' }), /upstream_unavailable/);
  assert.equal(calls, 1);
});

test('TMDB uses fixed upstream and bearer header; results are bounded and cached', async () => {
  let calls = 0;
  let time = 100;
  const search = createSearch({ token: 'test-only-token', now: () => time, ttlMs: 100, fetchImpl: async (url, options) => {
    calls++;
    assert.equal(url.origin, 'https://api.themoviedb.org');
    assert.equal(url.pathname, '/3/search/movie');
    assert.equal(url.searchParams.get('year'), '2020');
    assert.equal(options.headers.Authorization, 'Bearer test-only-token');
    assert.equal(options.redirect, 'error');
    assert.ok(options.signal);
    return response({ results: [{ id: 1, title: 'Example Movie', poster_path: '/poster.jpg', release_date: '2020-01-01', overview: 'Story' }] });
  } });
  const first = await search(movie);
  assert.equal(first.candidates[0].provider, 'tmdb');
  assert.equal(first.candidates[0].year, 2020);
  first.candidates[0].title = 'mutated';
  assert.equal((await search(movie)).candidates[0].title, 'Example Movie');
  assert.equal(calls, 1);
  time = 201;
  await search(movie);
  assert.equal(calls, 2);
});

test('TMDB preserves localized and original titles plus backdrop artwork', async () => {
  const search = createSearch({ token: 'test-only-token', fetchImpl: async url => {
    assert.equal(url.searchParams.get('language'), 'fr-FR');
    return response({ results: [{ id: 7, title: 'Titre français', original_title: 'Original Title', release_date: '2020-01-01', poster_path: '/poster.jpg', backdrop_path: '/backdrop.jpg' }] });
  } });
  const result = await search({ title: 'Titre français', kind: 'movie', year: 2020, language: 'fr-FR' });
  assert.equal(result.candidates[0].originalTitle, 'Original Title');
  assert.equal(result.candidates[0].backdropUrl, 'https://image.tmdb.org/t/p/w1280/backdrop.jpg');
});

test('TMDB verifies regional movie titles through bounded alternative-title lookups', async () => {
  const paths = [];
  const search = createSearch({ token: 'test', fetchImpl: async url => {
    paths.push(url.pathname);
    if (url.pathname === '/3/search/movie') return response({ results: [
      { id: 7, title: 'Original Name', release_date: '2020-01-01' },
      { id: 8, title: 'Another Name', release_date: '2020-01-01' },
      { id: 9, title: 'Wrong Year', release_date: '2019-01-01' },
    ] });
    if (url.pathname === '/3/movie/7/alternative_titles') return response({ titles: [{ title: 'Nom régional' }, { title: 'Nom régional' }, { title: 'https://private.example.test' }] });
    throw new Error('unavailable');
  } });
  const result = await search({ title: 'Nom régional', kind: 'movie', year: 2020 });
  assert.deepEqual(result.candidates[0].alternativeTitles, ['Nom régional']);
  assert.equal(result.candidates[1].alternativeTitles, undefined);
  assert.deepEqual(paths, ['/3/search/movie', '/3/movie/7/alternative_titles', '/3/movie/8/alternative_titles']);
});

test('TMDB verifies TV alternative titles while direct matches need one request', async () => {
  const paths = [];
  const search = createSearch({ token: 'test', fetchImpl: async url => {
    paths.push(url.pathname);
    if (url.pathname === '/3/search/tv') return response({ results: [{ id: 3, name: 'Original Series', first_air_date: '2020-01-01' }] });
    return response({ results: [{ title: 'Série régionale' }] });
  } });
  const result = await search({ title: 'Série régionale', kind: 'series', year: 2020 });
  assert.deepEqual(result.candidates[0].alternativeTitles, ['Série régionale']);
  assert.deepEqual(paths, ['/3/search/tv', '/3/tv/3/alternative_titles']);
});

test('series falls back to TVmaze and strips HTML; unsafe image links omitted', async () => {
  const search = createSearch({ token: 'test-token', fetchImpl: async url => {
    if (url.hostname === 'api.themoviedb.org') throw new Error('private upstream details');
    assert.equal(url.pathname, '/search/shows');
    return response([{ show: { id: 5, name: 'Example Series', summary: '<p>Story</p>', image: { medium: 'http://localhost/private' } } }]);
  } });
  const result = await search({ title: 'Example Series', kind: 'series' });
  assert.equal(result.candidates[0].overview, 'Story');
  assert.equal(result.candidates[0].posterUrl, undefined);
  assert.equal(result.candidates[0].license, 'CC BY-SA 4.0');
});

test('live matching downloads only public channel reference and matches aliases locally', async () => {
  let calls = 0;
  const search = createSearch({ fetchImpl: async url => {
    calls++;
    assert.equal(url.href, 'https://iptv-org.github.io/api/channels.json');
    return response([{ id: 'Example.fr', name: 'Example TV', alt_names: ['Exemple Télé'], website: 'https://ignored.test' }]);
  } });
  const result = await search({ title: 'Exemple Tele', kind: 'live' });
  assert.equal(result.candidates[0].id, 'Example.fr');
  assert.equal((await search({ title: 'Other channel', kind: 'live' })).candidates.length, 0);
  assert.equal(calls, 1);
});

test('upstream HTTP failures and oversized responses fail closed', async () => {
  for (const upstream of [new Response('error', { status: 429 }), new Response('[]', { headers: { 'content-length': '999999999' } }), new Response('x'.repeat(1024 * 1024 + 1))]) {
    const search = createSearch({ token: 'test', fetchImpl: async () => upstream });
    await assert.rejects(search(movie), /upstream_unavailable/);
  }
});

test('HTTP validation, generic errors, CORS and rate limiting', async t => {
  let calls = 0;
  const server = createGateway({ origins: ['https://app.example.test'], rateLimit: 5, search: async () => { calls++; throw new Error('SECRET'); } });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise(resolve => { server.closeAllConnections(); server.close(resolve); }));
  const url = `http://127.0.0.1:${server.address().port}/v1/search`;
  const post = (body, headers = {}) => fetch(url, { method: 'POST', headers: { 'content-type': 'application/json', ...headers }, body: JSON.stringify(body) });
  assert.equal((await post(movie, { origin: 'https://untrusted.test' })).status, 403);
  assert.equal((await post({ ...movie, username: 'private' })).status, 400);
  const failed = await post(movie, { origin: 'https://app.example.test' });
  assert.equal(failed.status, 503);
  assert.equal(failed.headers.get('access-control-allow-origin'), 'https://app.example.test');
  assert.equal(await failed.text(), '{"error":"metadata_unavailable"}');
  assert.equal(calls, 1);
  assert.equal((await post({ ...movie, title: 'x'.repeat(3000) })).status, 413);
  await post(movie);
  await post(movie);
  assert.equal((await post(movie)).status, 429);
});

test('CORS configuration ignores wildcard, opaque and malformed origins', async t => {
  const server = createGateway({
    origins: ['*', 'null', 'https://app.example.test/path', 'https://app.example.test'],
    search: async () => ({ candidates: [] }),
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise(resolve => { server.closeAllConnections(); server.close(resolve); }));
  const url = `http://127.0.0.1:${server.address().port}/v1/search`;
  const post = origin => fetch(url, {
    method: 'POST',
    headers: { 'content-type': 'application/json', origin },
    body: JSON.stringify(movie),
  });

  assert.equal((await post('*')).status, 403);
  assert.equal((await post('null')).status, 403);
  assert.equal((await post('https://app.example.test/path')).status, 403);
  assert.equal((await post('https://app.example.test')).status, 200);
});
