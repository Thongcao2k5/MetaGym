BEGIN;

-- Keep the legacy rows and give existing V2 entries precedence on the same day.
WITH workout_days AS (
  SELECT member_id, (performed_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date AS journal_date,
    left(string_agg(NULLIF(trim(notes), ''), E'\n' ORDER BY performed_at, id), 5000) AS notes
  FROM workout_logs GROUP BY member_id, 2
), measurements AS (
  SELECT DISTINCT ON (member_id, (measured_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date)
    member_id, (measured_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date AS journal_date,
    chest_cm, waist_cm, hips_cm
  FROM body_measurements
  WHERE num_nonnulls(chest_cm, waist_cm, hips_cm) > 0
  ORDER BY member_id, 2, measured_at DESC, id DESC
), exercise_days AS (
  SELECT w.member_id, (w.performed_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date AS journal_date,
    jsonb_agg(jsonb_build_object(
      'title', e.exercise_name_snapshot,
      'result', COALESCE(NULLIF(concat_ws(' · ',
        e.sets_completed || ' hiệp', NULLIF(e.reps_summary, ''),
        e.weight_kg || ' kg', e.duration_seconds || ' giây', NULLIF(trim(e.notes), '')
      ), ''), 'Đã tập')
    ) ORDER BY w.performed_at, w.id, e.display_order) AS achievements
  FROM workout_logs w JOIN workout_log_exercises e ON e.workout_log_id = w.id
  GROUP BY w.member_id, 2
), photo_days AS (
  SELECT DISTINCT p.member_id, (p.taken_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date AS journal_date
  FROM progress_photos p JOIN media_assets a ON a.id = p.media_id AND a.owner_id = p.member_id
  WHERE a.status = 'READY' AND a.purpose = 'PROGRESS_PHOTO'
), days AS (
  SELECT member_id, journal_date FROM workout_days
  UNION SELECT member_id, journal_date FROM measurements
  UNION SELECT member_id, journal_date FROM photo_days
), added AS (
  INSERT INTO member_journal_entries (id, member_id, journal_date, notes, chest_cm, waist_cm, hips_cm, achievements)
  SELECT gen_random_uuid(), d.member_id, d.journal_date, w.notes, m.chest_cm, m.waist_cm, m.hips_cm,
    COALESCE(x.achievements, '[]'::jsonb)
  FROM days d LEFT JOIN workout_days w USING (member_id, journal_date)
  LEFT JOIN measurements m USING (member_id, journal_date)
  LEFT JOIN exercise_days x USING (member_id, journal_date)
  ON CONFLICT (member_id, journal_date) DO NOTHING
  RETURNING id, member_id, journal_date
), photos AS (
  SELECT j.id, j.member_id, p.media_id,
    row_number() OVER (PARTITION BY j.id ORDER BY p.taken_at, p.id) AS display_order
  FROM added j JOIN progress_photos p ON p.member_id = j.member_id
    AND (p.taken_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date = j.journal_date
  JOIN media_assets a ON a.id = p.media_id AND a.owner_id = j.member_id
  WHERE a.status = 'READY' AND a.purpose = 'PROGRESS_PHOTO'
    AND NOT EXISTS (SELECT 1 FROM member_journal_photos x WHERE x.media_id = p.media_id)
)
INSERT INTO member_journal_photos (journal_id, member_id, media_id, display_order)
SELECT id, member_id, media_id, display_order FROM photos WHERE display_order <= 3;

COMMIT;
