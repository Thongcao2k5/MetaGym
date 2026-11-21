import assert from 'node:assert/strict';
import test from 'node:test';
import { compareMeal, vietnamDate } from '../src/routes/member-nutrition.routes.js';

const plan = { items: [
  { day: 1, meal: 'BREAKFAST', foodId: 'rice', foodName: 'Rice', grams: 100 },
  { day: 2, meal: 'BREAKFAST', foodId: 'rice', foodName: 'Rice', grams: 200 },
] };
const entry = { mealType: 'BREAKFAST', foodId: 'rice', unit: 'g', quantity: 120 };

test('business date uses Vietnam midnight independently of client offset', () => {
  assert.equal(vietnamDate('2026-11-19T17:00:00Z'), '2026-11-20');
  assert.equal(vietnamDate('2026-11-19T16:59:59Z'), '2026-11-19');
  assert.equal(vietnamDate('2026-11-20T01:00:00+08:00'), '2026-11-20');
});
test('no Coach and free text never imply compliance', () => {
  assert.equal(compareMeal(null, [entry], 1, 'BREAKFAST').status, 'INSUFFICIENT');
  assert.equal(compareMeal(plan, [{ ...entry, foodId: null }], 1, 'BREAKFAST').status, 'INSUFFICIENT');
  assert.equal(compareMeal(plan, [{ ...entry, unit: 'portion' }], 1, 'BREAKFAST').status, 'INSUFFICIENT');
  assert.equal(compareMeal(plan, [], 1, 'BREAKFAST').status, 'INSUFFICIENT');
});
test('comparison isolates weekday and meal, combines portions and preserves snapshot', () => {
  const before = structuredClone(plan);
  const result = compareMeal(plan, [entry, entry, { ...entry, mealType: 'DINNER' }], 1, 'BREAKFAST');
  assert.equal(result.differences[0].deltaGrams, 140);
  assert.equal(compareMeal(plan, [entry], 2, 'BREAKFAST').differences[0].deltaGrams, -80);
  assert.deepEqual(plan, before);
  const revised = structuredClone(plan);
  revised.items[0].grams = 500;
  assert.equal(compareMeal(plan, [entry], 1, 'BREAKFAST').differences[0].suggestedGrams, 100);
  assert.equal(compareMeal(revised, [entry], 1, 'BREAKFAST').differences[0].suggestedGrams, 500);
});
test('snacks do not count as a menu violation', () => {
  assert.equal(compareMeal(plan, [entry], 1, 'SNACK').status, 'UNREGULATED');
});
