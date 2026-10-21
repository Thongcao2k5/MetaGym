\set ON_ERROR_STOP on

DO $$
DECLARE
  table_count integer;
BEGIN
  SELECT count(*)
    INTO table_count
    FROM pg_tables
   WHERE schemaname = 'public';

  IF table_count <> 34 THEN
    RAISE EXCEPTION 'Expected 34 public tables, found %', table_count;
  END IF;
END
$$;

DO $$
DECLARE
  required_tables text[] := ARRAY[
    'users', 'member_profiles', 'coach_profiles', 'password_reset_codes',
    'membership_plans', 'payments', 'member_memberships', 'coach_requests',
    'coach_relationships', 'coach_termination_requests', 'coach_transfer_history',
    'gym_profile', 'equipment', 'exercises', 'training_plans',
    'training_plan_days', 'training_plan_exercises', 'nutrition_guides',
    'training_sessions', 'media_assets', 'workout_logs',
    'workout_log_exercises', 'meal_logs', 'body_measurements',
    'progress_photos', 'progress_comments', 'conversations',
    'conversation_participants', 'messages', 'call_logs', 'ai_conversations',
    'ai_messages', 'admin_audit_logs', 'auth_login_rate_limits'
  ];
  missing_tables text[];
BEGIN
  SELECT array_agg(name ORDER BY name)
    INTO missing_tables
    FROM unnest(required_tables) AS name
   WHERE to_regclass('public.' || name) IS NULL;

  IF missing_tables IS NOT NULL THEN
    RAISE EXCEPTION 'Missing tables: %', missing_tables;
  END IF;
END
$$;

DO $$
DECLARE
  required_constraints text[] := ARRAY[
    'fk_membership_payment_owner_plan',
    'fk_relationship_source_request',
    'fk_termination_relationship_coach',
    'fk_workout_session_member',
    'fk_workout_plan_member',
    'fk_message_sender_participant',
    'fk_participant_read_cursor',
    'fk_ai_reply_conversation'
  ];
  missing_constraints text[];
BEGIN
  SELECT array_agg(name ORDER BY name)
    INTO missing_constraints
    FROM unnest(required_constraints) AS name
   WHERE NOT EXISTS (
     SELECT 1 FROM pg_constraint WHERE conname = name
   );

  IF missing_constraints IS NOT NULL THEN
    RAISE EXCEPTION 'Missing constraints: %', missing_constraints;
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
      FROM pg_indexes
     WHERE schemaname = 'public'
       AND indexname = 'uq_users_single_admin'
  ) THEN
    RAISE EXCEPTION 'Missing single-Admin unique index';
  END IF;

  IF NOT EXISTS (
    SELECT 1
      FROM pg_indexes
     WHERE schemaname = 'public'
       AND indexname = 'ex_memberships_no_overlap'
  ) THEN
    RAISE EXCEPTION 'Missing membership overlap exclusion constraint';
  END IF;
END
$$;

SELECT 'schema assertions passed' AS result;
