import { renderRelationshipsPage } from './relationships.js';

export async function renderTerminationsPage({ root, params, shell }) {
  const nextParams = new URLSearchParams(params);
  nextParams.set('tab', 'terminations');
  return renderRelationshipsPage({ root, params: nextParams, shell });
}
