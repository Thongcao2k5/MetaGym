\set ON_ERROR_STOP on

DO $$
DECLARE
  table_count integer;
BEGIN
  SELECT count(*)
    INTO table_count
    FROM pg_tables
   WHERE schemaname = 'public';

  IF table_count <> 75 THEN
    RAISE EXCEPTION 'Expected 75 public tables, found %', table_count;
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
    'ai_messages', 'admin_audit_logs', 'auth_login_rate_limits',
    'auth_password_reset_rate_limits', 'member_journal_entries',
    'member_journal_photos', 'coach_package_plans', 'coach_weekly_slots',
    'coach_payment_holds', 'coach_entitlements', 'coach_bookings', 'coach_slot_blocks',
    'coach_notifications', 'nutrition_foods', 'training_plan_day_meals',
    'gym_checkin_code', 'gym_visits', 'member_self_training_days',
    'coach_outcome_cases', 'nutrition_guide_revisions',
    'member_nutrition_days', 'coach_lock_incidents',
    'simulated_refunds', 'payment_adjustments',
    'roles', 'storage_providers', 'folders', 'images', 'image_variants',
    'albums', 'album_images', 'tags', 'image_tags', 'share_links',
    'api_keys', 'api_logs', 'image_views', 'system_settings',
    'staff_profiles', 'vouchers', 'voucher_redemptions',
    'user_device_tokens', 'user_notification_preferences',
    'admin_notification_broadcasts'
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
    'fk_ai_reply_conversation', 'uq_member_journal_day',
    'fk_journal_photo_entry_owner', 'fk_journal_photo_media_owner',
    'ck_direct_conversation_pair', 'ck_coach_profiles_member_limit_fixed',
    'ck_coach_package_code_format', 'ck_coach_entitlement_origin',
    'ex_coach_weekly_slot_overlap', 'uq_coach_hold_request',
    'fk_coach_entitlement_relationship', 'ex_coach_booking_overlap',
    'ck_coach_outcome_different_pair',
    'uq_member_membership_owner', 'fk_payment_renewed_membership',
    'ck_payments_vnpay_confirmation', 'ck_payments_momo_confirmation',
    'ck_payments_zalopay_confirmation', 'uq_simulated_refund_idempotency',
    'ck_simulated_refund_formula', 'uq_payment_adjustment_idempotency'
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

  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes WHERE schemaname = 'public'
      AND indexname = 'uq_direct_conversation_pair'
  ) THEN
    RAISE EXCEPTION 'Missing direct conversation pair index';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes WHERE schemaname = 'public'
      AND indexname = 'ix_payments_renewed_membership'
  ) THEN
    RAISE EXCEPTION 'Missing payment renewed membership index';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes WHERE schemaname = 'public'
      AND indexname = 'uq_payments_vnpay_pending_member'
  ) THEN
    RAISE EXCEPTION 'Missing VNPay pending payment unique index';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes WHERE schemaname = 'public'
      AND indexname = 'uq_payments_momo_pending_member'
  ) THEN
    RAISE EXCEPTION 'Missing MoMo pending payment unique index';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes WHERE schemaname = 'public'
      AND indexname = 'uq_payments_zalopay_pending_member'
  ) THEN
    RAISE EXCEPTION 'Missing ZaloPay pending payment unique index';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes WHERE schemaname = 'public'
      AND indexname = 'uq_coach_entitlement_origin_hold'
  ) THEN
    RAISE EXCEPTION 'Missing coach entitlement origin hold unique index';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes WHERE schemaname = 'public'
      AND indexname = 'uq_coach_lock_incident_open'
  ) THEN
    RAISE EXCEPTION 'Missing coach lock incident open unique index';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes WHERE schemaname = 'public'
      AND indexname = 'uq_termination_open_relationship'
  ) THEN
    RAISE EXCEPTION 'Missing early termination open relationship unique index';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
     WHERE tgname = 'trg_nutrition_revision'
       AND NOT tgisinternal
  ) THEN
    RAISE EXCEPTION 'Missing nutrition revision trigger';
  END IF;
END
$$;

DO $$
DECLARE
  required_reporting_indexes text[] := ARRAY[
    'ix_audit_created_desc',
    'ix_audit_action_created',
    'ix_payments_confirmed_success',
    'ix_coach_holds_consumed_settled',
    'ix_coach_incidents_status_created',
    'ix_simulated_refunds_created_at',
    'ix_payment_adjustments_created_at',
    'ix_termination_disputed_created',
    'ix_nutrition_foods_name_lower',
    'ix_member_self_training_days_member_date_time'
  ];
  missing_indexes text[];
BEGIN
  SELECT array_agg(name ORDER BY name)
    INTO missing_indexes
    FROM unnest(required_reporting_indexes) AS name
   WHERE NOT EXISTS (
     SELECT 1
       FROM pg_indexes
      WHERE schemaname = 'public'
        AND indexname = name
   );

  IF missing_indexes IS NOT NULL THEN
    RAISE EXCEPTION 'Missing 0033 reporting/audit indexes: %', missing_indexes;
  END IF;
END
$$;

SELECT 'schema assertions passed' AS result;
