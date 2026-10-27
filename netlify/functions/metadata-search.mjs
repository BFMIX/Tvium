import { createSearch } from '../../services/metadata_gateway/src/gateway.js';
import { createNetlifyHandler } from '../../services/metadata_gateway/src/netlify_handler.js';

const search = createSearch({ token: Netlify.env.get('TMDB_READ_ACCESS_TOKEN') ?? '' });

export default createNetlifyHandler({
  search,
  origins: ['https://bfmix.github.io', 'https://tvium.netlify.app'],
});

export const config = {
  path: '/v1/search',
  rateLimit: {
    action: 'rate_limit',
    aggregateBy: 'ip',
    windowSize: 60,
    windowLimit: 20,
  },
};
