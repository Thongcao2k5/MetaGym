# Member nutrition tracking

Inherits `../MASTER.md` and `../../../DESIGN.md`. This brief applies to the
nutrition diary reached from the Member Training hub. It supplements the existing
Coach menu; it does not replace it.

## Composition and materials

- Reuse the Member gym-photo background, ambient lighting and dark scrim.
- Use the existing circular back action and a clear Vietnamese page title.
- Keep the date selector, daily metrics, Coach summary and four meal sections in
  a consistent reading order.
- Keep the date and two daily metrics in one compact hero. Put **Thêm món** in
  each meal header so the create action is distinct from managing
  a saved dish. A saved dish uses one overflow menu for **Sửa món** and **Xóa món**
  instead of two permanent icon buttons.
  Show the Coach menu name without a repeated instruction beneath it.
- Center both metric columns around their own label and value. In a recorded
  dish, keep the name, energy and numeric difference together; align the
  overflow menu beside that content instead of creating a mostly empty row.
- Use the existing warm smoked surfaces, restrained warm borders and top-edge
  reflection to connect the screen to Member Home/Profile. Routine meal content
  stays non-blurred; do not nest backdrop filters or blur every scrolling card.
- Preserve the graphite fallback and readable form surfaces. Coral denotes
  actions; green denotes nutrition quantities; secondary copy stays subordinate.
- Preserve shared spacing/radius tokens and avoid adding a new palette.

## Training entry

- Place the nutrition row directly after the personal training schedule in the
  Training hub's `Kế hoạch tập luyện` section.
- Tapping the row or its trailing **Mở** action reaches the same diary.
- Keep history readable after Gym expiry; writing is controlled by the API.

## Behavior and acceptance

- Retain the existing create/edit/delete, catalog, photo and Coach-comparison API
  behavior, including Vietnam-day write restrictions and numeric differences only.
- Save and recovery feedback remain reachable above the keyboard; a failed save
  preserves input and can be retried.
- Test loading, empty, error, expired membership, narrow phone/text scaling and
  navigation from Training.
- Visual acceptance requires the final app on the running emulator with a real
  backend and persisted test data, plus device screenshots of the Training entry,
  diary and entry form. Fixture-only widget images do not establish completion.
- Report separately which runtime checks, screenshots and automated tests were
  actually completed. Never infer visual alignment from theme-token usage alone.
