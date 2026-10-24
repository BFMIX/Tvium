import test from 'node:test';
import assert from 'node:assert/strict';
import { createGateway } from '../src/gateway.js';
import { createPairingRelay } from '../src/pairing_relay.js';

async function withGateway(run, options = {}) {
  const server = createGateway({ search: async () => ({ candidates: [] }), origins: ['https://tvium.example.test'], ...options });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  try { await run(`http://127.0.0.1:${server.address().port}`); }
  finally { await new Promise(resolve => server.close(resolve)); }
}

const headers = { Origin: 'https://tvium.example.test', 'Content-Type': 'application/json' };
const opaque = { iv: 'AAAAAAAAAAAAAAAA', ciphertext: 'AQIDBAUGBwgJCgsMDQ4PEA' };

test('pairing relay bounds its per-client rate-limit table', async () => {
  const handle = createPairingRelay({ maxClients: 0 });
  let status;
  await handle(
    { url: '/v1/pairing', method: 'POST', socket: { remoteAddress: '203.0.113.1' } },
    code => { status = code; },
  );
  assert.equal(status, 429);
});

test('phone pairing relays only an opaque, single-use encrypted proposal', async () => {
  await withGateway(async base => {
    const created = await fetch(`${base}/v1/pairing`, { method: 'POST', headers });
    assert.equal(created.status, 201);
    const session = await created.json();
    assert.match(session.id, /^[A-Za-z0-9_-]{16,}$/);
    assert.match(session.viewerToken, /^[A-Za-z0-9_-]{32,}$/);
    assert.match(session.submitToken, /^[A-Za-z0-9_-]{32,}$/);

    const path = `${base}/v1/pairing/${session.id}/submission`;
    assert.equal((await fetch(path, { headers: { ...headers, Authorization: 'Bearer wrong' } })).status, 403);
    assert.equal((await fetch(path, { headers: { ...headers, Authorization: `Bearer ${session.viewerToken}` } })).status, 202);
    assert.equal((await fetch(path, { method: 'POST', headers: { ...headers, Authorization: 'Bearer wrong' }, body: JSON.stringify(opaque) })).status, 403);
    assert.equal((await fetch(path, { method: 'POST', headers: { ...headers, Authorization: `Bearer ${session.submitToken}` }, body: JSON.stringify(opaque) })).status, 202);
    assert.equal((await fetch(path, { method: 'POST', headers: { ...headers, Authorization: `Bearer ${session.submitToken}` }, body: JSON.stringify(opaque) })).status, 409);
    const received = await fetch(path, { headers: { ...headers, Authorization: `Bearer ${session.viewerToken}` } });
    assert.equal(received.status, 200);
    assert.deepEqual(await received.json(), opaque);
    assert.equal((await fetch(`${base}/v1/pairing/${session.id}`, { method: 'DELETE', headers: { ...headers, Authorization: `Bearer ${session.viewerToken}` } })).status, 204);
    assert.equal((await fetch(path, { headers: { ...headers, Authorization: `Bearer ${session.viewerToken}` } })).status, 404);
  });
});

test('pairing expires and rejects untrusted browser origins', async () => {
  let now = 1000;
  await withGateway(async base => {
    assert.equal((await fetch(`${base}/v1/pairing`, { method: 'POST', headers: { ...headers, Origin: 'https://other.example.test' } })).status, 403);
    const created = await fetch(`${base}/v1/pairing`, { method: 'POST', headers });
    const session = await created.json();
    now += 601000;
    assert.equal((await fetch(`${base}/v1/pairing/${session.id}/submission`, { headers: { ...headers, Authorization: `Bearer ${session.viewerToken}` } })).status, 404);
  }, { now: () => now });
});

test('phone page serves a local-only encrypted pairing form', async () => {
  await withGateway(async base => {
    const page = await fetch(`${base}/pair`);
    assert.equal(page.status, 200);
    assert.match(page.headers.get('content-security-policy'), /connect-src 'self'/);
    assert.match(await page.text(), /pairing-phone\.js/);
    const script = await fetch(`${base}/pairing-phone.js`);
    assert.equal(script.status, 200);
    const source = await script.text();
    assert.match(source, /AES-GCM/);
    assert.match(source, /crypto\.subtle\.encrypt/);
    assert.doesNotMatch(source, /localStorage|sessionStorage/);
  });
});
