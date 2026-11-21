---
name: ui-ux-pro-max
description: >-
  Comprehensive UI/UX Pro Max design system, review, and audit skill for mobile (Flutter) and web interfaces.
  Use this skill when designing, reviewing, auditing, or refactoring UI components for visual hierarchy,
  dark/light surface contrast calibration, typography, touch targets (44x44px), overflow prevention, and micro-interactions.
---

# UI/UX Pro Max — Design Intelligence & Audit System

Use this skill to audit, review, and elevate user interfaces to production-grade quality.
For Meta Gym, follow the approved `DESIGN.md` and `design-system/meta-gym/MASTER.md` when their palette or surface rules differ from the examples below.

## 1. Surface & Color Calibration (Dark Mode & High-Contrast Systems)

1. **Avoid Pure White (`#FFFFFF`) on Deep Dark (`#11151C`)**:
   - Pure white cards on near-black backgrounds create a harsh `>15:1` luminance jump (glare/haloing).
   - Use **Elevated Slate / Obsidian Surfaces** (`#222B38` -> `#1B232E`) with a `1px` specular border (`rgba(255, 255, 255, 0.11)`) so cards separate clearly from `#11151C` without eye strain.
2. **Prevent Sinking Interactive Elements**:
   - Interactive tiles (such as Quick Access buttons) must never share the same luminance as the background.
   - Elevate tiles (`#283344` -> `#1F2836`), add a tinted border (`rgba(255, 140, 105, 0.28)`), and use high-contrast icon badges (`#FFEAE4` soft peach with `#E64420` icon) so action targets pop immediately.
3. **Text Contrast Hierarchy (WCAG AA/AAA)**:
   - Primary Title: `#F3F6FA` (`>= 13:1` on dark slate).
   - Secondary / Metadata: `#94A3B8` (`>= 5.5:1` on dark slate).
   - Brand Accent Text: `#FF7E58` / `#FF6B4A` (lighter coral for dark surfaces instead of dark red-orange).

## 2. Layout, Compactness & Anti-Wrapping Rules

1. **Zero Awkward Text Wrapping**:
   - Card headers, status pills (`Hiệu lực`), and action links (`Xem gói tập >`, `Chi tiết >`) must stay on a single line (`maxLines: 1`, `overflow: TextOverflow.ellipsis`).
   - Avoid nesting bulky padded sub-boxes inside narrow 2-column grids on 360px–393px mobile screens; prefer a clean horizontal row divided by a `1px` vertical line (`_cardDivider`).
2. **Flutter Flex & Scroll Safety**:
   - Every `Text` inside a `Row` with dynamic or multi-word content must either be wrapped in `Expanded`/`Flexible` or be short and fixed with `maxLines: 1`.
   - Fixed-height `PageView` containers must have sufficient height (`>= 88px` for icon + label tiles) to prevent `RenderFlex overflowed by X pixels` when device text scaling is active.

## 3. Touch Targets & Ergonomics (WCAG 2.5.5 / iOS HIG / Material 3)

1. **Minimum 44×44 px Interactive Target**:
   - Header icon buttons, avatar buttons, day check-in items, and bottom navigation items must provide at least `44×44 px` hit area (`ConstrainedBox(constraints: BoxConstraints(minWidth: 44, minHeight: 44))` or `TapTargetSize.padded`).
2. **Floating Bottom Navigation Clearance**:
   - Ensure scrollable content has adequate bottom padding so the final card/accordion is never obscured by the floating dock.
3. **Reduced Motion Support**:
   - Respect `MediaQuery.of(context).disableAnimations` for sliding indicators and transitions.

## 4. UI/UX Pro Max Review Checklist

When auditing a screen, evaluate each category and report findings with severity (`CRITICAL`, `WARNING`, `PASS`):
- [ ] **Surface & Contrast**: No glaring white-on-black; no sinking buttons.
- [ ] **Typography & Wrapping**: No 2-line broken badges, headers, or unit labels.
- [ ] **RenderFlex Overflow Safety**: Safe heights on `PageView`, `Row`, and `Column` widgets.
- [ ] **Touch Targets**: All interactive controls meet `>= 44×44 px` hit area.
- [ ] **Feature Completeness**: All current domain flows (e.g., Workouts, Progress, Coach, AI) are reachable within 1 tap.
