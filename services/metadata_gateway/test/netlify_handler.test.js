import test from 'node:test';
import assert from 'node:assert/strict';
import { createNetlifyHandler } from '../src/netlify_handler.js';

const endpoint = 'https://tvium.example.test/v1/search';
const query = { title: 'Example Movie', kind: 'movie', year: 2020 };

test('serverless gateway accepts a bounded public title without credentials', async () => {
  const calls = [];
  const handler = createNetlifyHandler({
    origins: ['https://app.example.test'],
    search: async value => {
      calls.push(value);
      return { candidates: [] };
    },
  });
  const result = await handler(new Request(endpoint, {
    method: 'POST',
    headers: { 'content-type': 'application/json', origin: 'https://app.example.test' },
    body: JSON.stringify(query),
  }));
  assert.equal(result.status, 200);
  assert.deepEqual(await result.json(), { candidates: [] });
  assert.equal(result.headers.get('access-control-allow-origin'), 'https://app.example.test');
  assert.equal(result.headers.get('cache-control'), 'no-store');
  assert.deepEqual(calls, [{ ...query, language: 'en-US' }]);
});

test('serverless gateway rejects untrusted origins and source-like input', async () => {
  let calls = 0;
  const handler = createNetlifyHandler({
    origins: ['https://app.example.test'],
    search: async () => { calls++; return { candidates: [] }; },
  });
  const request = (origin, body) => new Request(endpoint, {
    method: 'POST',
    headers: { 'content-type': 'application/json', ...(origin ? { origin } : {}) },
    body: JSON.stringify(body),
  });
  assert.equal((await handler(request('https://untrusted.example.test', query))).status, 403);
  assert.equal((await handler(request(null, { ...query, title: 'https://provider.example.test/get.php' }))).status, 400);
  assert.equal(calls, 0);
});

test('serverless gateway bounds payloads and sanitizes upstream failure', async () => {
  const handler = createNetlifyHandler({
    search: async () => { throw new Error('private upstream detail'); },
  });
  const oversized = await handler(new Request(endpoint, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ ...query, padding: 'x'.repeat(3000) }),
  }));
  assert.equal(oversized.status, 413);
  const failed = await handler(new Request(endpoint, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(query),
  }));
  assert.equal(failed.status, 503);
  assert.deepEqual(await failed.json(), { error: 'metadata_unavailable' });
});
