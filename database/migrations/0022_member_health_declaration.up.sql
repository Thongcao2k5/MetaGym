ALTER TABLE member_profiles
  ADD COLUMN weight_kg numeric(6,2) CHECK (weight_kg > 0 AND weight_kg <= 999.99),
  ADD COLUMN body_fat_percent numeric(5,2) CHECK (body_fat_percent > 0 AND body_fat_percent <= 100),
  ADD COLUMN health_declaration_completed_at timestamptz;
