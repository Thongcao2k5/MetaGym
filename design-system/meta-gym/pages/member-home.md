# Member Home — Current page brief

This page inherits [DESIGN.md](../../../DESIGN.md). The current Flutter implementation in `mobile-app/lib/features/member/presentation/member_dashboard_view.dart` is the visual and behavioral reference for an already approved screen. A future refinement should preserve its warm smoked glass and existing information order unless the user requests a change.

## Current reading order

1. Greeting and four quick actions: Lịch tập, Giáo trình, Dinh dưỡng, Coach.
2. Gói tập and Coach summary. Coach details appear only for the relevant relationship state.
3. Coach-provided plan and supporting content when active; self-training journal when the member has a package without a Coach.
4. Gym exploration and the expandable full feature directory.
5. The five-item Member bottom navigation.

Do not restore removed controls, extra avatar buttons, or a `Bắt đầu` action that has no matching behavior. A card that opens another page is navigation, not a persistent selected state.

## Material

The Home screen is the exception that uses the real gym photograph and warm smoked optical surfaces. Current card reference: ordinary card fill `0xC42B2622`, featured fill `0xB82D2824`, warm edge `0xA3A79D92`, and blur only where the current component benefits from it. Read the current component before altering these values. Other screens inherit the default graphite surfaces from `DESIGN.md`.

Keep the photo recognizable behind the glass, text readable in every membership state, and a solid fallback for reduced effects or slower devices. Never animate blur or create nested blurred cards.

## Review states

Inspect at least: no package, package without Coach, active package with Coach, package expired and relationship paused, loading, error, and empty plan. Verify last content is clear of the bottom navigation and all four quick actions have readable labels and 48dp targets.
