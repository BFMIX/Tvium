import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import test from 'node:test';

import { handleMediaRelay } from '../src/media_relay.js';

const secret = new Uint8Array(32).fill(9);
const now = 1_800_000_000_000;
const id = `${Math.floor(now / 1000).toString(36)}-AAAAAAAAAAAAAAAAAAAAAA`;
const viewer = createHmac('sha256', secret).update(`viewer:${id}`).digest('base64url');
const origin = 'https://bfmix.github.io';
const base = 'https://tvium.netlify.app';

async function session(url, options = {}) {
  const response = await handleMediaRelay(new Request(`${base}/v1/media-session`, {
    method: 'POST',
    headers: {
      Origin: origin,
      Authorization: `Bearer ${id}.${viewer}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ url }),
  }), { secret, now: () => now, ...options });
  return response;
}

test('HLS media URLs hide provider credentials and rewrite every child resource', async () => {
  const source = 'http://iptv.example.test/live/u/p/master.m3u8?password=secret';
  const start = await session(source);
  assert.equal(start.status, 201);
  const url = (await start.json()).url;
  assert.ok(url.startsWith(`${base}/v1/media/`));
  assert.ok(url.endsWith('/stream.m3u8'));
  assert.ok(!url.includes('iptv.example.test'));
  assert.ok(!url.includes('secret'));
  const fetched = [];
  const options = { secret, now: () => now, fetchImpl: async (target, init) => {
    fetched.push([target.href, init.redirect]);
    return new Response('#EXTM3U\n#EXT-X-KEY:METHOD=AES-128,URI="key.bin"\n' +
      '#EXT-X-STREAM-INF:BANDWIDTH=900000\nvariant/index.m3u8\n', {
      headers: { 'Content-Type': 'application/vnd.apple.mpegurl' },
    });
  } };
  const manifest = await handleMediaRelay(new Request(url, {
    headers: { Origin: origin },
  }), options);
  assert.equal(manifest.status, 200);
  const body = await manifest.text();
  assert.ok(body.startsWith('#EXTM3U'));
  assert.ok(body.includes(`${base}/v1/media/`));
  assert.ok(body.includes('/stream.m3u8'));
  assert.ok(!body.includes('key.bin'));
  assert.ok(!body.includes('variant/index.m3u8'));
  assert.deepEqual(fetched, [[source, 'manual']]);
});

test('passes Range to VOD and rejects tampering, private targets and foreign origins', async () => {
  const start = await session('https://video.example.test/movie.mp4');
  const url = (await start.json()).url;
  const calls = [];
  const options = { secret, now: () => now, fetchImpl: async (target, init) => {
    calls.push([target.href, init.headers.Range]);
    return new Response('bytes', { status: 206, headers: {
      'Content-Type': 'video/mp4', 'Content-Range': 'bytes 0-4/100',
    } });
  } };
  const response = await handleMediaRelay(new Request(url, {
    headers: { Origin: origin, Range: 'bytes=0-4' },
  }), options);
  assert.equal(response.status, 206);
  assert.equal(response.headers.get('Content-Range'), 'bytes 0-4/100');
  assert.deepEqual(calls, [['https://video.example.test/movie.mp4', 'bytes=0-4']]);
  assert.equal((await session('http://192.168.1.2/movie.mp4')).status, 400);
  assert.equal((await session('https://video.example.test/live.ts')).status, 415);
  assert.equal((await handleMediaRelay(new Request(url.replace(/([A-Za-z0-9_-])(?=\/stream)/, 'x')),
    options)).status, 403);
  assert.equal((await handleMediaRelay(new Request(url, {
    headers: { Origin: 'https://evil.example.test' },
  }), options)).status, 403);
  assert.equal(calls.length, 1);
});
