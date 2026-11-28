import { Router } from 'express';

export function createHealthRouter({ database }) {
  const healthRouter = Router();

  healthRouter.get('/', async (_request, response) => {
    try {
      await database.query('SELECT 1 AS connected');

      response.status(200).json({
        data: {
          api: 'AVAILABLE',
          database: 'AVAILABLE',
        },
      });
    } catch {
      response.status(503).json({
        error: {
          code: 'DATABASE_UNAVAILABLE',
          message: 'Cơ sở dữ liệu tạm thời không khả dụng',
        },
      });
    }
  });

  return healthRouter;
}
