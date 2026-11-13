BEGIN;

CREATE TABLE coach_entitlements (
  id uuid PRIMARY KEY,
  hold_id uuid NOT NULL UNIQUE REFERENCES coach_payment_holds(id),
  relationship_id uuid NOT NULL,
  member_id uuid NOT NULL,
  coach_id uuid NOT NULL,
  status varchar(20) NOT NULL CHECK (status IN ('ACTIVE', 'QUEUED', 'ENDED')),
  total_sessions integer NOT NULL CHECK (total_sessions > 0),
  remaining_sessions integer NOT NULL CHECK (remaining_sessions BETWEEN 0 AND total_sessions),
  duration_days integer NOT NULL CHECK (duration_days > 0),
  starts_on date,
  original_ends_on date,
  ends_on date,
  ended_at timestamptz,
  CONSTRAINT fk_coach_entitlement_relationship FOREIGN KEY (relationship_id, member_id, coach_id)
    REFERENCES coach_relationships(id, member_id, coach_id),
  CONSTRAINT ck_coach_entitlement_dates CHECK (
    (starts_on IS NULL AND original_ends_on IS NULL AND ends_on IS NULL)
    OR (starts_on IS NOT NULL AND original_ends_on IS NOT NULL AND ends_on IS NOT NULL
      AND original_ends_on = starts_on + duration_days - 1
      AND ends_on IN (original_ends_on, original_ends_on + 7))
  ),
  CHECK (status <> 'QUEUED' OR starts_on IS NULL),
  CHECK (status <> 'ACTIVE' OR (starts_on IS NOT NULL AND remaining_sessions > 0)),
  CHECK ((status = 'ENDED') = (ended_at IS NOT NULL))
);

CREATE UNIQUE INDEX uq_coach_entitlement_current ON coach_entitlements (member_id, status)
  WHERE status IN ('ACTIVE', 'QUEUED');
CREATE INDEX ix_coach_entitlements_coach ON coach_entitlements (coach_id, status);

ALTER TABLE coach_entitlements ADD CONSTRAINT uq_coach_entitlement_booking_owner
  UNIQUE (id, member_id, coach_id);

CREATE TABLE coach_bookings (
  id uuid PRIMARY KEY,
  entitlement_id uuid NOT NULL,
  member_id uuid NOT NULL,
  coach_id uuid NOT NULL,
  starts_at timestamptz NOT NULL,
  ends_at timestamptz NOT NULL,
  booking_date date GENERATED ALWAYS AS ((starts_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date) STORED,
  status varchar(20) NOT NULL DEFAULT 'BOOKED' CHECK (status IN ('BOOKED', 'COMPLETED', 'CANCELLED')),
  charged_at timestamptz,
  resolved_by uuid REFERENCES users(id),
  resolved_at timestamptz,
  reason text,
  FOREIGN KEY (entitlement_id, member_id, coach_id)
    REFERENCES coach_entitlements(id, member_id, coach_id),
  CHECK (ends_at = starts_at + interval '90 minutes'),
  CHECK ((status = 'BOOKED') = (resolved_at IS NULL)),
  CHECK (status <> 'COMPLETED' OR charged_at IS NOT NULL),
  CHECK (status <> 'BOOKED' OR charged_at IS NULL),
  CONSTRAINT ex_coach_booking_overlap EXCLUDE USING gist
    (coach_id WITH =, tstzrange(starts_at, ends_at, '[)') WITH &&)
    WHERE (status IN ('BOOKED', 'COMPLETED'))
);
CREATE UNIQUE INDEX uq_coach_booking_member_day ON coach_bookings (member_id, booking_date)
  WHERE status IN ('BOOKED', 'COMPLETED') OR charged_at IS NOT NULL;
CREATE INDEX ix_coach_bookings_entitlement ON coach_bookings (entitlement_id, status);

CREATE FUNCTION close_coach_entitlements() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.status = 'ENDED' THEN
    UPDATE coach_entitlements SET status = 'ENDED', ended_at = statement_timestamp()
      WHERE relationship_id = NEW.id AND status IN ('ACTIVE', 'QUEUED');
    UPDATE training_plans SET status = 'ARCHIVED', archived_at = statement_timestamp()
      WHERE relationship_id = NEW.id AND status = 'ACTIVE';
    UPDATE nutrition_guides SET status = 'ARCHIVED', archived_at = statement_timestamp()
      WHERE relationship_id = NEW.id AND status = 'ACTIVE';
    UPDATE coach_payment_holds SET status = 'CANCELLED'
      WHERE member_id = NEW.member_id AND coach_id = NEW.coach_id AND status = 'HELD';
  END IF;
  UPDATE coach_bookings b SET status = 'CANCELLED', resolved_at = statement_timestamp(),
    resolved_by = NEW.ended_by, reason = 'Quan hệ Coach không còn hoạt động'
    FROM coach_entitlements e WHERE e.relationship_id = NEW.id AND b.entitlement_id = e.id
      AND b.status = 'BOOKED' AND b.starts_at > statement_timestamp();
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_close_coach_entitlements
  AFTER UPDATE OF status ON coach_relationships FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status AND NEW.status IN ('PAUSED', 'ENDED'))
  EXECUTE FUNCTION close_coach_entitlements();

ALTER TABLE coach_payment_holds DROP CONSTRAINT coach_payment_holds_status_check;
ALTER TABLE coach_payment_holds ADD CONSTRAINT coach_payment_holds_status_check
  CHECK (status IN ('HELD', 'CANCELLED', 'EXPIRED', 'CONSUMED', 'FAILED'));

CREATE OR REPLACE FUNCTION coach_occupied_seats(target_coach uuid) RETURNS integer
LANGUAGE sql STABLE AS $$
  SELECT count(*)::integer FROM (
    SELECT member_id FROM coach_relationships
     WHERE coach_id = target_coach AND status IN ('ACTIVE', 'PAUSED')
    UNION
    SELECT member_id FROM coach_payment_holds
     WHERE coach_id = target_coach AND status = 'HELD' AND expires_at > statement_timestamp()
  ) occupied;
$$;

COMMIT;
