BEGIN;

CREATE TABLE member_journal_entries (
  id uuid PRIMARY KEY,
  member_id uuid NOT NULL REFERENCES users(id),
  journal_date date NOT NULL DEFAULT (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date,
  notes text,
  chest_cm numeric(6,2) CHECK (chest_cm > 0),
  waist_cm numeric(6,2) CHECK (waist_cm > 0),
  hips_cm numeric(6,2) CHECK (hips_cm > 0),
  achievements jsonb NOT NULL DEFAULT '[]'::jsonb
    CHECK (jsonb_typeof(achievements) = 'array'),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_member_journal_day UNIQUE (member_id, journal_date),
  CONSTRAINT uq_member_journal_owner UNIQUE (id, member_id)
);

CREATE INDEX ix_member_journal_latest
  ON member_journal_entries (member_id, journal_date DESC, id DESC);

CREATE TABLE member_journal_photos (
  journal_id uuid NOT NULL,
  member_id uuid NOT NULL,
  media_id uuid NOT NULL UNIQUE,
  display_order smallint NOT NULL CHECK (display_order BETWEEN 1 AND 3),
  PRIMARY KEY (journal_id, display_order),
  CONSTRAINT fk_journal_photo_entry_owner
    FOREIGN KEY (journal_id, member_id)
    REFERENCES member_journal_entries(id, member_id) ON DELETE CASCADE,
  CONSTRAINT fk_journal_photo_media_owner
    FOREIGN KEY (media_id, member_id)
    REFERENCES media_assets(id, owner_id)
);

CREATE TRIGGER trg_member_journal_updated_at
  BEFORE UPDATE ON member_journal_entries
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMIT;
