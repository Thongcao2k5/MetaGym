# Meta Gym — Master Design Direction

`DESIGN.md` at the repository root is the normative source of truth. This file is the concise retrieval layer for page and implementation work.

## Style

**Futuristic Performance Glass** = premium spatial-computing glass × high-performance training.

- Modern, luxurious, powerful, and trustworthy.
- Dark-first on Flutter Member/Coach surfaces.
- Never cyberpunk, gaming, rainbow-neon, or glass on every card.
- Visual dials: variance 5/10, motion 4/10, density 6/10, effects 4/10.

## Non-negotiable formula

- 80% stable dark surfaces; no more than 20% true backdrop glass.
- Canvas (Scaffold): `#0F1115` (Deep Graphite).
- Solid card: `#181B22` with 1px border `#262A34`, no blur.
- Performance glass: `rgba(24, 27, 34, 0.78)`, 12px blur, 24px radius.
- Overlay glass: `rgba(15, 17, 21, 0.90)`, 18px blur, only dialogs/sheets/AI overlay.
- Never nest blurred glass.
- Never animate blur. Animate opacity and transform.

## Identity tokens

- Primary accent (Coral Orange): `#FF5E36` (CTA chính, active, progress chính, điểm nhấn; chữ/icon trên nút bắt buộc `#FFFFFF`).
- Cool reflection: `#A9C7E8`.
- Primary text: `#F7F9FC`.
- Secondary/Subtext: `#8E95A5` (chữ phụ / trạng thái tương lai chưa diễn ra).
- Semantic green: `#2ECC71` (hoàn thành / đang hiệu lực / dinh dưỡng).
- Semantic yellow: `#F39C12` (cảnh báo / avatar phụ).
- Coach Avatar "LN": nền `#F5B041`, chữ `#181B22` đậm xuyên suốt toàn bộ các thẻ.
- Font: **Be Vietnam Pro**, locally bundled.
- Orange occupies roughly 5–10% of a typical viewport and is reserved for action, selection, and key progress.

## Shape and spacing

- 4px base, 8px default rhythm.
- Phone gutter 16px; tablet 24px.
- Controls 10–14px radius; cards 20px; glass docks/sheets 24px.
- Card padding 16/20/24px by emphasis.
- Avoid cards inside cards; use spacing, divider, or tonal grouping first.

## Components

- Standard content cards are solid; glass is for navigation, compact docks, and overlays.
- One orange primary action per decision area.
- Maximum five bottom-navigation destinations.
- Use a single vector icon family with 1.75–2px strokes.
- Touch targets: 48x48dp Android or 44x44pt iOS.
- Every action defines pressed, loading, disabled, success, and error behavior where applicable.

## Motion and performance

- Press: 80–150ms.
- Local state: 180–240ms.
- Navigation/sheet: 240–320ms.
- Respect reduced motion.
- Clip blur bounds, keep it out of scrolling cards, and isolate repaints only where profiling proves useful.
- Background images are compressed, correctly sized, precached for demo, and covered by a strong scrim.

## Surface split

- Flutter Member/Coach: full dark-first identity and controlled glass.
- Bootstrap Admin: shared typography, orange actions, semantic states, and spacing; primarily solid surfaces for dense data.

## Delivery gate

- Text contrast 4.5:1; meaningful non-text contrast 3:1.
- Verify loading, empty, error, offline, disabled, and success states.
- Verify safe areas, keyboard, screen-reader order, and Dynamic Type/text scaling.
- Test 375px phone width, large phone/tablet, and mobile landscape.
- Confirm the screen remains usable with blur and background photography disabled.

For exact tokens, component rules, anti-patterns, and the capstone demo checklist, read [`../../DESIGN.md`](../../DESIGN.md).
