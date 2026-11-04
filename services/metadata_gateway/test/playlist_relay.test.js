import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import test from 'node:test';

import { handlePlaylistRelay } from '../src/playlist_relay.js';

const secret = new Uint8Array(32).fill(7);
const now = 1_800_000_000_000;
const id = `${Math.floor(now / 1000).toString(36)}-AAAAAAAAAAAAAAAAAAAAAA`;
const viewerToken = createHmac('sha256', secret)
  .update(`viewer:${id}`).digest('base64url');
const endpoint = 'https://tvium.netlify.app/v1/playlist-fetch';
const origin = 'https://bfmix.github.io';

function request(url, token = `${id}.${viewerToken}`) {
  return new Request(endpoint, {
    method: 'POST',
    headers: {
      Origin: origin,
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ url }),
  });
}

test('streams authorized playlist without storing the provider address', async () => {
  let fetched;
  const response = await handlePlaylistRelay(
    request('http://iptv.example.test/get.php?password=secret'),
    {
      secret,
      now: () => now,
      fetchImpl: async (target, options) => {
        fetched = [target.toString(), options.redirect];
        return new Response('#EXTM3U\n', { status: 200 });
      },
    },
  );
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('Cache-Control'), 'no-store');
  assert.equal(await response.text(), '#EXTM3U\n');
  assert.deepEqual(fetched, [
    'http://iptv.example.test/get.php?password=secret', 'manual',
  ]);
});

test('rejects private hosts, invalid token and other origins', async () => {
  let calls = 0;
  const options = { secret, now: () => now, fetchImpl: async () => { calls++; } };
  for (const url of ['http://127.0.0.1/list', 'http://192.168.1.3/list',
    'http://localhost/list', 'http://[::1]/list']) {
    const response = await handlePlaylistRelay(request(url), options);
    assert.equal(response.status, 400);
  }
  assert.equal((await handlePlaylistRelay(request('https://iptv.example.test/list',
    `${id}.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA`), options)).status, 403);
  assert.equal((await handlePlaylistRelay(new Request(endpoint, {
    method: 'POST', headers: { Origin: 'https://evil.example.test' },
  }), options)).status, 403);
  assert.equal(calls, 0);
});

test('follows public redirects but rejects redirects into private networks', async () => {
  let calls = 0;
  const response = await handlePlaylistRelay(
    request('https://iptv.example.test/start.m3u8'),
    { secret, now: () => now, fetchImpl: async () => {
      calls++;
      if (calls === 1) return new Response(null, {
        status: 302, headers: { Location: '/catalog.m3u8' },
      });
      return new Response('#EXTM3U\n');
    } },
  );
  assert.equal(response.status, 200);
  assert.equal(calls, 2);
  const privateRedirect = await handlePlaylistRelay(
    request('https://iptv.example.test/start.m3u8'),
    { secret, now: () => now, fetchImpl: async () => new Response(null, {
      status: 302, headers: { Location: 'http://127.0.0.1/admin' },
    }) },
  );
  assert.equal(privateRedirect.status, 502);
});
