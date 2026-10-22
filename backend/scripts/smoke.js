import 'dotenv/config';

import { loadSmokeConfig, runSmokeTest } from './smoke-test-lib.js';

try {
  const steps = await runSmokeTest(loadSmokeConfig());
  for (const step of steps) console.log(`PASS ${step}`);
  console.log(`Smoke test passed (${steps.length} checks).`);
} catch (error) {
  console.error(`Smoke test failed: ${error.message}`);
  process.exitCode = 1;
}
