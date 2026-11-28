import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import express from 'express';
import swaggerUi from 'swagger-ui-express';
import YAML from 'yaml';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function loadOpenApiSpec() {
  const candidates = [
    path.resolve(__dirname, '../../../docs/openapi.yaml'),
    path.resolve(__dirname, '../../docs/openapi.yaml'),
    path.resolve(__dirname, '../../../../docs/requirements/openapi.yaml'),
    path.resolve(__dirname, '../../../docs/requirements/openapi.yaml'),
    path.resolve(process.cwd(), 'docs/openapi.yaml'),
  ];

  for (const filePath of candidates) {
    if (fs.existsSync(filePath)) {
      const raw = fs.readFileSync(filePath, 'utf8');
      return YAML.parse(raw);
    }
  }

  throw new Error('OpenAPI specification file (openapi.yaml) not found');
}

/**
 * Serves interactive Swagger UI at `/api-docs` and raw OpenAPI JSON at `/api-docs/openapi.json`.
 */
export function createDocsRouter() {
  const router = express.Router();
  const spec = loadOpenApiSpec();

  router.use((_request, response, next) => {
    response.removeHeader('Content-Security-Policy');
    next();
  });

  router.get('/openapi.json', (_request, response) => {
    response.json(spec);
  });

  router.use(
    '/',
    swaggerUi.serve,
    swaggerUi.setup(spec, {
      customSiteTitle: 'Meta Gym API — Swagger UI',
      swaggerOptions: {
        persistAuthorization: true,
      },
    }),
  );

  return router;
}
