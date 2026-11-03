import { handlePlaylistRelay } from '../../src/playlist_relay.js';

export default async function playlistRelay(request) {
  const value = Netlify.env.get('TVIUM_PAIRING_SECRET') ?? '';
  const decoded = value.replace(/-/g, '+').replace(/_/g, '/');
  const secret = Uint8Array.from(atob(decoded), c => c.charCodeAt(0));
  return handlePlaylistRelay(request, { secret });
}

export const config = { path: '/v1/playlist-fetch' };
