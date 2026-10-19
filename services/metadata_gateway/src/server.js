import { createGateway, createSearch } from './gateway.js';

const port = Number(process.env.PORT ?? 8787);
if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error('Invalid PORT');
const origins = (process.env.ALLOWED_ORIGINS ?? '').split(',').map(value => value.trim()).filter(Boolean);
const server = createGateway({ search: createSearch({ token: process.env.TMDB_READ_ACCESS_TOKEN ?? '' }), origins });
server.listen(port, process.env.HOST ?? '127.0.0.1', () => console.log('Tvium metadata gateway ready.'));
