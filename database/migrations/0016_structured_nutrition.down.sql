BEGIN;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM nutrition_guides WHERE meal_items IS NOT NULL) THEN
    RAISE EXCEPTION 'Export structured meal plans before rollback';
  END IF;
END;
$$;
DROP TRIGGER trg_freeze_nutrition_calories ON nutrition_guides;
DROP FUNCTION freeze_nutrition_calories();
ALTER TABLE nutrition_guides DROP COLUMN meal_items;
DROP TABLE nutrition_foods;
COMMIT;
