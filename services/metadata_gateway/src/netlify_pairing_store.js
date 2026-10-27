export function pairingStoreForContext(context, { getStore, getDeployStore }) {
  if (context.deploy.context === 'production' && context.deploy.published) {
    return getStore({ name: 'tvium-pairing-production', consistency: 'strong' });
  }
  return getDeployStore({ name: 'tvium-pairing-preview', consistency: 'strong' });
}
