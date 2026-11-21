BEGIN;
ALTER TABLE meal_logs
  ADD COLUMN food_id uuid REFERENCES nutrition_foods(id),
  ADD COLUMN quantity numeric(10,2) CHECK (quantity > 0 AND quantity <= 10000),
  ADD COLUMN unit varchar(30),
  ADD COLUMN kcal_per_100g numeric(7,2);
-- Retain every saved structured menu. Existing past versions cannot be reconstructed.
CREATE TABLE nutrition_guide_revisions (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  guide_id uuid NOT NULL REFERENCES nutrition_guides(id),
  member_id uuid NOT NULL REFERENCES users(id),
  relationship_id uuid NOT NULL REFERENCES coach_relationships(id),
  title text NOT NULL,
  items jsonb NOT NULL,
  effective_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ON nutrition_guide_revisions(member_id, effective_at DESC, id DESC);
INSERT INTO nutrition_guide_revisions(guide_id, member_id, relationship_id, title, items)
 SELECT id, member_id, relationship_id, title, meal_items FROM nutrition_guides
 WHERE status = 'ACTIVE' AND meal_items IS NOT NULL;
CREATE TABLE member_nutrition_days (
 member_id uuid NOT NULL REFERENCES users(id),
 log_date date NOT NULL,
 plan_snapshot jsonb,
 PRIMARY KEY(member_id, log_date)
);
CREATE FUNCTION record_nutrition_revision() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF NEW.status = 'ACTIVE' AND NEW.meal_items IS NOT NULL THEN
   INSERT INTO nutrition_guide_revisions(guide_id,member_id,relationship_id,title,items)
   VALUES(NEW.id,NEW.member_id,NEW.relationship_id,NEW.title,NEW.meal_items);
 END IF;
 RETURN NEW;
END; $$;
CREATE TRIGGER trg_nutrition_revision AFTER INSERT OR UPDATE OF status, title, meal_items ON nutrition_guides
 FOR EACH ROW EXECUTE FUNCTION record_nutrition_revision();
COMMIT;
