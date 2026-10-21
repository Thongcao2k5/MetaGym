BEGIN;

CREATE EXTENSION IF NOT EXISTS citext;
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TABLE users (
  id uuid PRIMARY KEY,
  email citext NOT NULL UNIQUE,
  password_hash varchar(255) NOT NULL,
  role varchar(20) NOT NULL CHECK (role IN ('MEMBER', 'COACH', 'ADMIN')),
  full_name varchar(120) NOT NULL,
  phone varchar(20),
  avatar_media_id uuid,
  status varchar(20) NOT NULL DEFAULT 'ACTIVE'
    CHECK (status IN ('ACTIVE', 'DISABLED')),
  session_version integer NOT NULL DEFAULT 0 CHECK (session_version >= 0),
  disabled_at timestamptz,
  disabled_reason text,
  last_login_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_users_status_details CHECK (
    (status = 'ACTIVE' AND disabled_at IS NULL AND disabled_reason IS NULL)
    OR
    (status = 'DISABLED' AND disabled_at IS NOT NULL AND disabled_reason IS NOT NULL)
  )
);

CREATE UNIQUE INDEX uq_users_single_admin
  ON users (role)
  WHERE role = 'ADMIN';
CREATE INDEX ix_users_role_status ON users (role, status);
CREATE INDEX ix_users_full_name_lower ON users (lower(full_name));

CREATE TABLE member_profiles (
  user_id uuid PRIMARY KEY REFERENCES users(id),
  date_of_birth date,
  gender varchar(30)
    CHECK (gender IN ('MALE', 'FEMALE', 'OTHER', 'PREFER_NOT_TO_SAY')),
  height_cm numeric(5,2) CHECK (height_cm > 0 AND height_cm <= 300),
  fitness_goal text,
  experience_level varchar(20)
    CHECK (experience_level IN ('BEGINNER', 'INTERMEDIATE', 'ADVANCED')),
  activity_level varchar(20)
    CHECK (activity_level IN ('LOW', 'MODERATE', 'HIGH')),
  health_notes text,
  injury_notes text,
  dietary_preferences text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE coach_profiles (
  user_id uuid PRIMARY KEY REFERENCES users(id),
  biography text,
  specialties text[] NOT NULL DEFAULT '{}',
  qualifications text,
  experience_years smallint NOT NULL DEFAULT 0 CHECK (experience_years >= 0),
  availability_note text,
  member_limit smallint NOT NULL CHECK (member_limit > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE password_reset_codes (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users(id),
  code_hash varchar(255) NOT NULL,
  attempt_count smallint NOT NULL DEFAULT 0 CHECK (attempt_count BETWEEN 0 AND 5),
  expires_at timestamptz NOT NULL,
  used_at timestamptz,
  invalidated_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_password_reset_expiry CHECK (expires_at > created_at),
  CONSTRAINT ck_password_reset_terminal CHECK (
    num_nonnulls(used_at, invalidated_at) <= 1
  )
);

CREATE INDEX ix_password_reset_user_created
  ON password_reset_codes (user_id, created_at DESC);

CREATE TABLE membership_plans (
  id uuid PRIMARY KEY,
  name varchar(100) NOT NULL,
  description text,
  price bigint NOT NULL CHECK (price >= 0),
  duration_days integer NOT NULL CHECK (duration_days > 0),
  status varchar(20) NOT NULL CHECK (status IN ('ACTIVE', 'INACTIVE')),
  created_by uuid NOT NULL REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE payments (
  id uuid PRIMARY KEY,
  member_id uuid NOT NULL REFERENCES users(id),
  plan_id uuid NOT NULL REFERENCES membership_plans(id),
  plan_name_snapshot varchar(100) NOT NULL,
  duration_days_snapshot integer NOT NULL CHECK (duration_days_snapshot > 0),
  amount bigint NOT NULL CHECK (amount >= 0),
  method varchar(20) NOT NULL CHECK (method IN ('MOCK_QR', 'FRONT_DESK')),
  status varchar(20) NOT NULL DEFAULT 'PENDING'
    CHECK (status IN ('PENDING', 'SUCCESS', 'FAILED', 'CANCELLED')),
  transaction_code varchar(50) NOT NULL UNIQUE,
  idempotency_key varchar(100) NOT NULL,
  request_hash varchar(64) NOT NULL CHECK (request_hash ~ '^[0-9a-f]{64}$'),
  created_by uuid NOT NULL REFERENCES users(id),
  decided_by uuid REFERENCES users(id),
  confirmed_at timestamptz,
  decided_at timestamptz,
  failure_reason text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_payments_created_by_idempotency UNIQUE (created_by, idempotency_key),
  CONSTRAINT uq_payments_owner_plan UNIQUE (id, member_id, plan_id),
  CONSTRAINT ck_payments_state_details CHECK (
    (status = 'PENDING'
      AND confirmed_at IS NULL AND decided_at IS NULL
      AND decided_by IS NULL AND failure_reason IS NULL)
    OR
    (status = 'SUCCESS'
      AND confirmed_at IS NOT NULL AND decided_at IS NOT NULL
      AND failure_reason IS NULL
      AND ((method = 'MOCK_QR' AND decided_by IS NULL)
        OR (method = 'FRONT_DESK' AND decided_by IS NOT NULL)))
    OR
    (status IN ('FAILED', 'CANCELLED')
      AND confirmed_at IS NULL AND decided_at IS NOT NULL
      AND failure_reason IS NOT NULL)
  )
);

CREATE INDEX ix_payments_member_created ON payments (member_id, created_at DESC);
CREATE INDEX ix_payments_status_created ON payments (status, created_at DESC);

CREATE TABLE member_memberships (
  id uuid PRIMARY KEY,
  member_id uuid NOT NULL REFERENCES users(id),
  plan_id uuid NOT NULL REFERENCES membership_plans(id),
  source_payment_id uuid NOT NULL UNIQUE,
  start_date date NOT NULL,
  end_date date NOT NULL,
  status varchar(20) NOT NULL
    CHECK (status IN ('SCHEDULED', 'ACTIVE', 'EXPIRED', 'CANCELLED')),
  activated_at timestamptz,
  expired_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT fk_membership_payment_owner_plan
    FOREIGN KEY (source_payment_id, member_id, plan_id)
    REFERENCES payments(id, member_id, plan_id),
  CONSTRAINT ck_membership_dates CHECK (end_date >= start_date),
  CONSTRAINT ck_membership_state_details CHECK (
    (status = 'SCHEDULED' AND activated_at IS NULL AND expired_at IS NULL)
    OR
    (status = 'ACTIVE' AND activated_at IS NOT NULL AND expired_at IS NULL)
    OR
    (status = 'EXPIRED' AND activated_at IS NOT NULL AND expired_at IS NOT NULL)
    OR
    (status = 'CANCELLED' AND expired_at IS NULL)
  ),
  CONSTRAINT ex_memberships_no_overlap EXCLUDE USING gist (
    member_id WITH =,
    daterange(start_date, end_date, '[]') WITH &&
  ) WHERE (status <> 'CANCELLED')
);

CREATE UNIQUE INDEX uq_memberships_active_member
  ON member_memberships (member_id)
  WHERE status = 'ACTIVE';
CREATE INDEX ix_memberships_member_status_start
  ON member_memberships (member_id, status, start_date);

CREATE TRIGGER trg_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_member_profiles_updated_at
  BEFORE UPDATE ON member_profiles
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_coach_profiles_updated_at
  BEFORE UPDATE ON coach_profiles
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_membership_plans_updated_at
  BEFORE UPDATE ON membership_plans
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_payments_updated_at
  BEFORE UPDATE ON payments
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_member_memberships_updated_at
  BEFORE UPDATE ON member_memberships
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMIT;
