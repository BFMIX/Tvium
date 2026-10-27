import test from 'node:test';
import assert from 'node:assert/strict';
import { handleNetlifyPairing } from '../src/netlify_pairing.js';
import { pairingStoreForContext } from '../src/netlify_pairing_store.js';

function memoryStore() {
  const values = new Map();
  return {
    values,
    async setJSON(key, value, { onlyIfNew } = {}) {
      if (onlyIfNew && values.has(key)) return { modified: false };
      values.set(key, value);
      return { modified: true };
    },
    async get(key) { return values.get(key) ?? null; },
    async delete(key) { values.delete(key); },
  };
}

const secret = Buffer.alloc(32, 9);
const origin = 'https://bfmix.github.io';
const base = 'https://pairing.example.test';
const opaque = { iv: 'AAAAAAAAAAAAAAAA', ciphertext: 'AQIDBAUGBwgJCgsMDQ4PEA' };

test('published pairing survives deploys while previews stay isolated', () => {
  const calls = [];
  const dependencies = {
    getStore(options) { calls.push(['site', options]); },
    getDeployStore(options) { calls.push(['deploy', options]); },
  };
  pairingStoreForContext({ deploy: { context: 'production', published: true } }, dependencies);
  pairingStoreForContext({ deploy: { context: 'production', published: false } }, dependencies);
  pairingStoreForContext({ deploy: { context: 'deploy-preview' } }, dependencies);
  assert.deepEqual(calls.map(([scope]) => scope), ['site', 'deploy', 'deploy']);
  assert.equal(calls[0][1].name, 'tvium-pairing-production');
});

test('Netlify sessions survive separate function invocations and keep payload opaque', async () => {
  const store = memoryStore();
  const handle = request => handleNetlifyPairing(request, {
    store, secret, allowedOrigin: origin, now: () => 1_800_000_000_000,
  });
  const created = await handle(new Request(`${base}/v1/pairing`, {
    method: 'POST', headers: { Origin: origin },
  }));
  assert.equal(created.status, 201);
  const session = await created.json();
  assert.equal(store.values.size, 0);
  const path = `${base}/v1/pairing/${session.id}/submission`;
  const submitted = await handle(new Request(path, {
    method: 'POST',
    headers: {
      Origin: base,
      Authorization: `Bearer ${session.submitToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(opaque),
  }));
  assert.equal(submitted.status, 202);
  assert.deepEqual(store.values.get(`p/${session.id}`), opaque);
  const duplicate = await handle(new Request(path, {
    method: 'POST',
    headers: {
      Origin: base,
      Authorization: `Bearer ${session.submitToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(opaque),
  }));
  assert.equal(duplicate.status, 409);
  const viewed = await handle(new Request(path, {
    headers: { Origin: origin, Authorization: `Bearer ${session.viewerToken}` },
  }));
  assert.equal(viewed.status, 200);
  assert.deepEqual(await viewed.json(), opaque);
  const closed = await handle(new Request(`${base}/v1/pairing/${session.id}`, {
    method: 'DELETE',
    headers: { Origin: origin, Authorization: `Bearer ${session.viewerToken}` },
  }));
  assert.equal(closed.status, 204);
  assert.equal(store.values.size, 0);
});

test('Netlify pairing rejects foreign origin, wrong token and expired ID', async () => {
  const store = memoryStore();
  let clock = 1_800_000_000_000;
  const handle = request => handleNetlifyPairing(request, {
    store, secret, allowedOrigin: origin, now: () => clock,
  });
  assert.equal((await handle(new Request(`${base}/v1/pairing`, {
    method: 'POST', headers: { Origin: 'https://evil.example.test' },
  }))).status, 403);
  const session = await (await handle(new Request(`${base}/v1/pairing`, {
    method: 'POST', headers: { Origin: origin },
  }))).json();
  const path = `${base}/v1/pairing/${session.id}/submission`;
  assert.equal((await handle(new Request(path, {
    headers: { Origin: origin, Authorization: 'Bearer wrong' },
  }))).status, 403);
  clock += 601_000;
  assert.equal((await handle(new Request(path, {
    headers: { Origin: origin, Authorization: `Bearer ${session.viewerToken}` },
  }))).status, 404);
});
