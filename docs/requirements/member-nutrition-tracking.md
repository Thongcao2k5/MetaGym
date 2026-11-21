# Member nutrition tracking

This requested capability supersedes only the V2 statement that there is no eating diary. Coach menus and the training curriculum remain separate and unchanged.

## Contract

- Reuse `meal_logs`, one row per actual dish, grouped by Vietnam business date and meal. Free text and explicit quantity/unit are allowed; no calorie estimate is required.
- A selected `nutrition_foods` item must use grams. The server captures its name and kcal/100g on save. Free text, images and notes never infer food identity, calories or compliance.
- `GET /member/nutrition/day?date=YYYY-MM-DD`, `GET /member/nutrition/foods`, `POST /member/nutrition/entries`, `PATCH /member/nutrition/entries/:id` and `DELETE /member/nutrition/entries/:id` require the authenticated MEMBER. No member ID selector is accepted. Reads survive Gym expiry; writes require current ACTIVE Gym membership and today's Vietnam date. Updates/deletes additionally lock and verify the owned record's existing date. Changing the payload date cannot unlock an old record.
- Optional images reuse `MEAL_PHOTO`, verified as READY and owned by the caller. Existing owner-only media access rules remain in force.
- Legacy `/meal-logs` writes remain retired. No parallel diary storage is created.

## Menu history

Migration 0024 captures each structured menu insert/update in `nutrition_guide_revisions`. Existing ACTIVE menus receive a baseline at migration time; earlier revisions cannot be reconstructed and must not be invented.

On first read/save for a day, `member_nutrition_days` freezes the latest eligible revision, or the absence of one. For a historical day, revisions after the end of that Vietnam day are excluded; for today, future revisions are excluded. Relationship start/end bounds are applied. Subsequent Coach edits do not modify the saved daily recommendation. This snapshot is private Member data, not an additional Coach-facing menu version or publishing workflow.

Comparison uses the chosen day's ISO weekday, meal, food ID and total grams per food. Snacks are unregulated when the menu specifies only three main meals. Missing structured data produces a neutral explanation. Per the product decision, comparison reports numeric differences only, without a match threshold or compliance verdict.

## UI

Training hub adds a nutrition entry without replacing existing cards. Detail page: date picker, trusted-energy subtotal, Coach status/menu link, breakfast/lunch/dinner/snack blocks, actual dishes and per-meal add action. Form: optional catalog selection, name, quantity, unit, time, notes and optional photo. Graphite surfaces use shared theme tokens; detail pages have no bottom navigation.

The nutrition entry belongs to **Công cụ & Khám phá** on the Training tab as a full-width warm-glass tool row with a green icon and an outlined **Mở** action. The detail keeps stable graphite surfaces: compact date and daily metrics first, optional Coach menu source second, then the four meals. Each editable meal has an explicit **Ghi món** action. Recorded dishes must not be marked as compliant with Coach suggestions; show only the numeric difference when enough data exists.

## Confirmed product decisions

On November 20, 2026, the user confirmed that entries may be edited/deleted only today; after the Vietnam day ends they are read-only. No match verdict is wanted: show differences only. The form reuses the create flow for editing, preserves saved media, and deletion requires confirmation.

## Verification commands

```
cd backend
node --check src/routes/member-nutrition.routes.js
node --test test/member-nutrition.test.js test/member-nutrition.routes.test.js
node --test test/progress.postgres.test.js
cd ../mobile-app
dart format lib/features/training/data/nutrition_tracking_api.dart lib/features/training/presentation/nutrition_tracking_page.dart lib/features/training/presentation/member_training_hub_page.dart test/features/training/nutrition_tracking_page_test.dart
flutter analyze --no-pub
flutter test --no-pub test/features/training/nutrition_tracking_page_test.dart test/features/training/member_nutrition_page_test.dart
```

Route tests use a database double and do not validate PostgreSQL migrations or real concurrent menu changes. A disposable migrated PostgreSQL database is required before release. No production database migration has been executed by this task.
