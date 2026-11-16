-- Development/demo only. Run with psql -v demo_seed_environment=development.
\set ON_ERROR_STOP on
\if :{?demo_seed_environment}
SELECT :'demo_seed_environment' IN ('development', 'test') AS gym_demo_allowed
\gset
\else
\set gym_demo_allowed false
\endif
\if :gym_demo_allowed
BEGIN;
LOCK TABLE membership_plans IN SHARE ROW EXCLUSIVE MODE;

INSERT INTO membership_plans (id, name, description, price, duration_days, status, created_by)
SELECT plan.id::uuid, plan.name, 'Giá mẫu dùng để thử luồng mua gói.',
       plan.price, plan.duration_days, 'ACTIVE', admin.id
FROM (VALUES
  ('20000000-0000-4000-8000-000000000002', 'Gói ngày', 60000, 1),
  ('20000000-0000-4000-8000-000000000001', 'Gói tháng', 500000, 30),
  ('20000000-0000-4000-8000-000000000003', 'Gói năm', 5000000, 365)
) AS plan(id, name, price, duration_days)
CROSS JOIN (SELECT id FROM users WHERE role = 'ADMIN' ORDER BY id LIMIT 1) AS admin
WHERE NOT EXISTS (
  SELECT 1 FROM membership_plans existing WHERE existing.duration_days = plan.duration_days
)
ON CONFLICT (id) DO NOTHING;

COMMIT;
\else
DO $$ BEGIN
  RAISE EXCEPTION 'Gym demo seed requires demo_seed_environment=development or test';
END $$;
\endif
