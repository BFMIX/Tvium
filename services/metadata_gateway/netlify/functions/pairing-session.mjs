import { getDeployStore, getStore } from '@netlify/blobs';
import { handleNetlifyPairing } from '../../src/netlify_pairing.js';
import { pairingStoreForContext } from '../../src/netlify_pairing_store.js';

export default async function pairingSession(request, context) {
  try {
    const secret = Buffer.from(process.env.TVIUM_PAIRING_SECRET ?? '', 'base64url');
    return await handleNetlifyPairing(request, {
      store: pairingStoreForContext(context, { getStore, getDeployStore }),
      secret,
      allowedOrigin: 'https://bfmix.github.io',
    });
  } catch (error) {
    console.error('Pairing unavailable', error?.name, error?.code);
    return Response.json({ error: 'pairing_unavailable' }, {
      status: 503,
      headers: { 'Cache-Control': 'no-store' },
    });
  }
}

export const config = {
  path: ['/v1/pairing/:id', '/v1/pairing/:id/submission'],
  rateLimit: { windowLimit: 120, windowSize: 60, aggregateBy: 'ip' },
};
