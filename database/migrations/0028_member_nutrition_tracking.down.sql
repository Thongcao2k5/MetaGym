BEGIN;
DROP TRIGGER trg_nutrition_revision ON nutrition_guides;
DROP FUNCTION record_nutrition_revision();
DROP TABLE member_nutrition_days;
DROP TABLE nutrition_guide_revisions;
ALTER TABLE meal_logs DROP COLUMN food_id, DROP COLUMN quantity, DROP COLUMN unit, DROP COLUMN kcal_per_100g;
COMMIT;
