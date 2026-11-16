# Member Home — Page Rules

This page inherits `../MASTER.md`. These rules resolve the home-screen composition shown in the current Meta Gym concept.

## Visual hierarchy

1. Greeting (`META GYM` / `Chào, <Tên>`) and circular glass search action.
2. Quick-action dock: 4 equal squircle tiles (`Lịch tập`, `Giáo trình`, `Dinh dưỡng`, `Coach`).
3. Membership & Coach summary (`Gói tập & Coach` Warm Glass card, or `Gói tập của bạn` when the member has no active Coach).
4. Today's workout (`Hôm nay` featured Liquid Glass card, or `Tự tập hôm nay` self-workout card when the member has no Coach).
5. 2-column balanced Bento pair (`Dinh dưỡng` and `Tiến độ tập luyện` / `Tiến độ tuần`, equal height `128px`).
6. `Khám phá Meta Gym`, collapsible full feature workbench directory, and 5-item bottom navigation with AI as the single elevated action.

## Material allocation & Warm Glass + Bento Layout

- **Canvas & Ambient Depth**: Deep Graphite canvas (`#0F1115`) over the single dimmed static gym background image with subtle vertical obsidian scrim (`0x9E0F1115` → `0x900F1115` → `0xAA0F1115`), cool top-right ambient tint (`rgba(169, 199, 232, 0.16)`), and warm bottom-left ambient glow (`rgba(255, 94, 54, 0.10)`).
- **Quick-action Dock**: 4 symmetric Warm Glass squircle tiles (`radius: 18px`, warm smoked gradient `0xC637302A` → `0xBB2C2621`, border `0xB7ADA396`), zero dividers between actions, `>= 48dp` touch targets.
- **Membership & Coach Card (`Gói tập & Coach`)**: Warm Glass card (`radius: 24px`, `BackdropFilter` blur `sigma: 10`, warm smoked gradient `0xCD342D28` → `0xC829241F`, border `0xB7B3A99D`, top specular highlight `0x75FFF5E9`), inner metric panels (`radius: 17px`, min-height `82px`, translucent `#80211E1C` fill with `#9A8C8176` border), Coach avatar monogram, and Vietnamese status pill (`"Hiệu lực"`).
- **Featured Card (`Hôm nay`) & Bento Cards (`Dinh dưỡng` + `Tiến độ`)**: Liquid Glass surfaces (`sigma: 12` when featured, subtle top specular highlight `0x70FFF6EA`). The 2-column Bento row splits `Dinh dưỡng` (left) and weekly workout progress (right) equally in a `128px`-tall row.
- **Bottom Navigation & Scroll Clearance**: Floating navigation with 5 destinations and elevated AI center button; scrollable list includes `bottomPadding + 32` clearance so the bottom Explore/workbench items are never obscured.
- **Terminology & Typography Refinement**:
  - Replace English status chips with Vietnamese (`"Hiệu lực"` instead of `"Active"`).
  - Crisp font rendering (`Be Vietnam Pro`), zero text-shadow blur or RGB subpixel fringe, `tabularFigures` for remaining days and workout metrics.
- **Color Palette Standards**:
  - Scaffold / Canvas: `#0F1115` (Deep Graphite).
  - Card Surface (solid fallback & non-blurred containers): `#181B22` with 1px border `#262A34`.
  - Primary Accent: `#FF5E36` (Coral Orange) for primary CTA, active navigation, active tiles, and key progress; with strictly white `#FFFFFF` text and icons on primary buttons.
  - Semantic Colors: Green `#2ECC71` (Hoàn thành / Đang hiệu lực / Dinh dưỡng), Yellow `#F39C12` (Cảnh báo / Avatar phụ), Gray `#8E95A5` (Chữ phụ / Trạng thái tương lai chưa diễn ra).
  - Coach Avatar `"LN"` (Lê Hoàng Nam): background `#F5B041`, text `#181B22` bold, synchronized across cards.
- **Performance Mode Fallback (`useSolidGlassFallback` / Reduced Motion / Tests)**:
  - Disable `BackdropFilter` blur and fall back to solid graphite/warm-dark surfaces (`#181B22` / `#302923` dock tiles, `rgba(24,27,34,0.92)` chrome) while maintaining borders and contrast.


## Simplification rules

- Remove borders around inner content when the parent card already provides a boundary.
- Use two-column layouts only for short numeric summaries.
- Keep one image-led featured card per viewport; remaining cards use icons and typography.
- Avoid truncating the coach name unless the entire row remains tappable and exposes the full name on the destination screen.
- Use section spacing rather than adding a new container around every subsection.

## Orange distribution

- Active quick action or primary CTA.
- Current/selected workout day.
- Active bottom-navigation destination.
- AI central action.

Do not apply a strong glow to all four simultaneously. The strongest glow belongs to the action currently expected from the user.

## Performance target for demo

- Keep Warm/Liquid Glass `BackdropFilter` (`sigma: 10–12`) bounded with `RepaintBoundary` on hero/summary cards and navigation, with solid fallback (`useSolidGlassFallback` / reduced motion) for low-end devices.
- Precache the single background image (`assets/images/gym_banner.png`).
- Avoid parallax and continuously animated glow.
- Use opacity/transform only for card entrance and state changes.

## Acceptance checks

- The next workout is discoverable within three seconds.
- Navigation and quick actions retain 48dp minimum hit areas.
- Secondary text remains readable over the real composed background.
- Bottom content is not hidden by the glass navigation bar.
- Home remains clear if the background image fails to load.
