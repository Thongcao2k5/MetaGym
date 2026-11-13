BEGIN;
CREATE TABLE nutrition_foods (
  id uuid PRIMARY KEY,
  name varchar(150) NOT NULL CHECK (btrim(name) <> ''),
  kcal_per_100g numeric(7,2) NOT NULL CHECK (kcal_per_100g BETWEEN 0 AND 1000),
  active boolean NOT NULL DEFAULT true
);
ALTER TABLE nutrition_guides ADD COLUMN meal_items jsonb
  CHECK (meal_items IS NULL OR jsonb_typeof(meal_items) = 'array');

CREATE FUNCTION freeze_nutrition_calories() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.meal_items IS NOT NULL THEN
    SELECT COALESCE(jsonb_agg(item || jsonb_build_object('kcalPer100g', food.kcal_per_100g)
      ORDER BY ordinal), '[]'::jsonb) INTO NEW.meal_items
    FROM jsonb_array_elements(NEW.meal_items) WITH ORDINALITY AS items(item, ordinal)
    JOIN nutrition_foods food ON food.id = (item->>'foodId')::uuid;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_freeze_nutrition_calories BEFORE UPDATE OF status ON nutrition_guides
  FOR EACH ROW WHEN (OLD.status = 'ACTIVE' AND NEW.status = 'ARCHIVED')
  EXECUTE FUNCTION freeze_nutrition_calories();
COMMIT;
