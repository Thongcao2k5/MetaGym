import { Router } from 'express';

export function retireLegacyWrites() {
  const router = Router();
  const gone = (_request, response) => response.status(410).json({
    error: { code: 'LEGACY_WORKFLOW_RETIRED', message: 'Hãy dùng luồng Meta Gym V2.', details: {} },
  });
  router.post('/coach-requests', gone);
  router.patch('/coach/requests/:requestId', gone);
  router.post('/coach/members/:memberId/training-plans', gone);
  router.patch('/coach/training-plans/:planId', gone);
  router.post('/coach/training-plans/:planId/publications', gone);
  router.post('/coach/members/:memberId/nutrition-guides', gone);
  router.patch('/coach/nutrition-guides/:guideId', gone);
  router.post('/coach/training-sessions', gone);
  router.patch('/coach/training-sessions/:sessionId', gone);
  for (const path of ['workout-logs', 'meal-logs', 'body-measurements', 'progress-photos']) {
    router.post('/' + path, gone);
    router.patch('/' + path + '/:id', gone);
    router.delete('/' + path + '/:id', gone);
  }
  return router;
}
