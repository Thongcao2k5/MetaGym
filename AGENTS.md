# Meta Gym — Instructions for coding agents

Before any UI/UX design, critique, preview, or implementation in this repository:

1. Read [the UI design specification](docs/requirements/ui-design-spec.md) and [DESIGN.md](DESIGN.md) before making any design decision. This applies even to a small UI refinement.
2. Read the current screen, shared theme, relevant product flow in `docs/requirements/confirmed-workflows.md`, and any page brief in `design-system/meta-gym/pages/`. Treat old page briefs as references when they differ from the current screen or a newer user decision.
3. Use the installed Impeccable skill when it fits the task. Its generic aesthetic advice cannot override the user's approved Meta Gym style or interaction requirements.
4. For Flutter, use `mobile-app/lib/core/theme/app_theme.dart` and shared components. Do not copy the historical sample adapter from `design-system/meta-gym/adapters/` into the app.
5. Preserve the warm smoked glass approved on Member Home. Use it for home, navigation, and selected featured cards. Use stable graphite surfaces for forms, long lists, calendars, charts, and dense Coach/Admin work.
6. Render and inspect each changed screen at phone size and with its real states. Check clipping, safe areas, text scaling, contrast, touch targets, loading/empty/error states, and smooth scrolling on the demo device when available.
7. If the user requests a preview before implementation, keep the preview separate from application code until they approve it.

When a new user decision conflicts with a design document, update the document and affected implementation together. Never use an older hex value, screenshot, or page brief merely because it is already in the repository.
