import { handleMediaRelay } from '../../src/media_relay.js';

export default async function mediaRelay(request) {
  const value = Netlify.env.get('TVIUM_PAIRING_SECRET') ?? '';
  const decoded = value.replace(/-/g, '+').replace(/_/g, '/');
  const secret = Uint8Array.from(atob(decoded), c => c.charCodeAt(0));
  return handleMediaRelay(request, { secret });
}

export const config = {
  path: ['/v1/media-session', '/v1/media/*'],
  rateLimit: { windowLimit: 120, windowSize: 60, aggregateBy: ['ip', 'domain'] },
};
