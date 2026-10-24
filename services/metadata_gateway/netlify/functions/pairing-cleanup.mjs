import { getDeployStore, getStore } from '@netlify/blobs';
import { pairingStoreForContext } from '../../src/netlify_pairing_store.js';

export default async function pairingCleanup(_request, context) {
  const store = pairingStoreForContext(context, { getStore, getDeployStore });
  const cutoff = Math.floor(Date.now() / 1000) - 600;
  for await (const page of store.list({ prefix: 'p/', paginate: true })) {
    for (const { key } of page.blobs) {
      const stamp = key.split('/')[1]?.split('-')[0] ?? '';
      const created = Number.parseInt(stamp, 36);
      if (Number.isFinite(created) && created < cutoff) await store.delete(key);
    }
  }
}

export const config = { schedule: '0 * * * *' };
