---
version: beta
name: Meta Gym
description: Futuristic Performance Glass design system for the Flutter Member and Coach app and the Bootstrap Admin application.
colors:
  primary: "#FF5E36"
  on-primary: "#FFFFFF"
  primary-hover: "#E84E27"
  on-primary-hover: "#FFFFFF"
  reflection: "#A9C7E8"
  background-dark: "#0F1115"
  surface-dark: "#181B22"
  surface-raised-dark: "#1F232C"
  glass-dark: "rgba(24, 27, 34, 0.78)"
  glass-strong-dark: "rgba(15, 17, 21, 0.90)"
  glass-border-dark: "rgba(212, 228, 255, 0.18)"
  glass-highlight-dark: "rgba(235, 246, 255, 0.32)"
  text-primary-dark: "#F7F9FC"
  text-secondary-dark: "#8E95A5"
  text-tertiary-dark: "#8E95A5"
  background-light: "#F5F7FA"
  surface-light: "#FFFFFF"
  surface-raised-light: "#EDF1F5"
  text-primary-light: "#11151A"
  text-secondary-light: "#4D5968"
  border-light: "#CBD4DF"
  border-dark: "#262A34"
  success: "#2ECC71"
  on-success: "#06261D"
  warning: "#F39C12"
  on-warning: "#2A1900"
  coach-avatar: "#F5B041"
  on-coach-avatar: "#181B22"
  error: "#F15B64"
  on-error: "#2C080B"
  info: "#70AEE8"
  on-info: "#071A2C"
  focus: "#8DBCF0"
  scrim: "rgba(4, 6, 9, 0.72)"
typography:
  display-lg:
    fontFamily: Be Vietnam Pro
    fontSize: 40px
    fontWeight: 800
    lineHeight: 1.1
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Be Vietnam Pro
    fontSize: 30px
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: -0.015em
  headline-md:
    fontFamily: Be Vietnam Pro
    fontSize: 24px
    fontWeight: 700
    lineHeight: 1.25
  title-lg:
    fontFamily: Be Vietnam Pro
    fontSize: 20px
    fontWeight: 700
    lineHeight: 1.3
  title-md:
    fontFamily: Be Vietnam Pro
    fontSize: 17px
    fontWeight: 600
    lineHeight: 1.4
  body-lg:
    fontFamily: Be Vietnam Pro
    fontSize: 16px
    fontWeight: 400
    lineHeight: 1.5
  body-md:
    fontFamily: Be Vietnam Pro
    fontSize: 14px
    fontWeight: 400
    lineHeight: 1.5
  label-lg:
    fontFamily: Be Vietnam Pro
    fontSize: 14px
    fontWeight: 600
    lineHeight: 1.35
  label-md:
    fontFamily: Be Vietnam Pro
    fontSize: 12px
    fontWeight: 600
    lineHeight: 1.35
    letterSpacing: 0.01em
  data-lg:
    fontFamily: Be Vietnam Pro
    fontSize: 28px
    fontWeight: 700
    lineHeight: 1.15
    fontFeature: "tnum"
rounded:
  xs: 6px
  sm: 10px
  md: 14px
  lg: 20px
  xl: 24px
  full: 999px
spacing:
  0: 0
  1: 4px
  2: 8px
  3: 12px
  4: 16px
  5: 20px
  6: 24px
  8: 32px
  10: 40px
  12: 48px
  16: 64px
components:
  app-canvas-dark:
    backgroundColor: "{colors.background-dark}"
    textColor: "{colors.text-primary-dark}"
  solid-surface-dark:
    backgroundColor: "{colors.surface-dark}"
    textColor: "{colors.text-primary-dark}"
    rounded: "{rounded.lg}"
  performance-glass-dark:
    backgroundColor: "{colors.glass-dark}"
    textColor: "{colors.text-primary-dark}"
    rounded: "{rounded.xl}"
  overlay-glass-dark:
    backgroundColor: "{colors.glass-strong-dark}"
    textColor: "{colors.text-primary-dark}"
    rounded: "{rounded.xl}"
  glass-border-swatch:
    backgroundColor: "{colors.glass-border-dark}"
  glass-highlight-swatch:
    backgroundColor: "{colors.glass-highlight-dark}"
  reflection-highlight:
    backgroundColor: "{colors.reflection}"
  raised-surface-dark:
    backgroundColor: "{colors.surface-raised-dark}"
    textColor: "{colors.text-primary-dark}"
    rounded: "{rounded.lg}"
  secondary-copy-dark:
    backgroundColor: "{colors.surface-dark}"
    textColor: "{colors.text-secondary-dark}"
    typography: "{typography.body-md}"
  tertiary-copy-dark:
    backgroundColor: "{colors.surface-dark}"
    textColor: "{colors.text-tertiary-dark}"
    typography: "{typography.label-md}"
  app-canvas-light:
    backgroundColor: "{colors.background-light}"
    textColor: "{colors.text-primary-light}"
  solid-surface-light:
    backgroundColor: "{colors.surface-light}"
    textColor: "{colors.text-primary-light}"
    rounded: "{rounded.lg}"
  raised-surface-light:
    backgroundColor: "{colors.surface-raised-light}"
    textColor: "{colors.text-primary-light}"
    rounded: "{rounded.lg}"
  secondary-copy-light:
    backgroundColor: "{colors.surface-light}"
    textColor: "{colors.text-secondary-light}"
    typography: "{typography.body-md}"
  divider-light:
    backgroundColor: "{colors.border-light}"
    height: 1px
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    typography: "{typography.label-lg}"
    rounded: "{rounded.md}"
    padding: 12px
    height: 48px
  button-primary-hover:
    backgroundColor: "{colors.primary-hover}"
    textColor: "{colors.on-primary-hover}"
  card-dark:
    backgroundColor: "{colors.surface-dark}"
    textColor: "{colors.text-primary-dark}"
    rounded: "{rounded.lg}"
    padding: 16px
  status-success:
    backgroundColor: "{colors.success}"
    textColor: "{colors.on-success}"
    typography: "{typography.label-md}"
    rounded: "{rounded.full}"
    padding: 8px
  status-warning:
    backgroundColor: "{colors.warning}"
    textColor: "{colors.on-warning}"
    typography: "{typography.label-md}"
    rounded: "{rounded.full}"
    padding: 8px
  info-banner:
    backgroundColor: "{colors.info}"
    textColor: "{colors.on-info}"
    typography: "{typography.body-md}"
    rounded: "{rounded.md}"
    padding: 12px
  focus-indicator:
    backgroundColor: "{colors.focus}"
    size: 3px
  modal-scrim:
    backgroundColor: "{colors.scrim}"
---

# Meta Gym Design System

## 1. Brand direction

Meta Gym uses **Futuristic Performance Glass**: the visual precision of premium spatial-computing products combined with the energy and discipline of high-performance training.

The experience must feel:

- **Modern:** clear structure, current technology, purposeful motion.
- **Luxurious:** controlled light, refined materials, generous spacing.
- **Powerful:** decisive typography, high contrast, confident orange accents.
- **Trustworthy:** workout and health information stays readable and actionable.

The product must not look like a gaming HUD, a cyberpunk dashboard, or a glassmorphism showcase. Effects support hierarchy; they are never the content.

### Product dials

- Variance: **5/10** — balanced composition, occasional asymmetric emphasis.
- Motion: **4/10** — short, functional transitions.
- Density: **6/10** — efficient fitness dashboard with comfortable touch targets.
- Visual effects: **4/10** — noticeable at first glance, restrained during daily use.

## 2. The 80/20 material rule

At least **80% of the visible interface uses stable, dark surfaces**. No more than **20% uses true backdrop glass**.

### Level 0 — Canvas

- Deep Graphite scaffold `#0F1115`.
- Background photography is optional and must be dimmed with a 72–84% dark scrim.
- Photography never runs behind dense text without a solid or strong-glass layer.

### Level 1 — Solid performance surface

- Default for workout cards, nutrition content, forms, tables, and long text.
- Use Card Surface `#181B22` with a subtle 1px border `#262A34`; no backdrop blur.
- Separation comes from tonal contrast and a clean one-pixel border, not a heavy shadow.
- This level should represent most of the screen.

### Level 2 — Performance glass

- Reserved for quick-action docks, compact summaries, floating filters, and bottom navigation.
- Target fill: `rgba(24, 27, 34, 0.78)` with **12px blur**.
- Use a cool one-pixel border at 18% opacity and one restrained top-edge highlight.
- Maximum: one dominant glass group per viewport region. Do not nest another blurred glass object inside it.

### Level 3 — Overlay glass

- Reserved for dialogs, bottom sheets, AI Coach panels, and high-priority floating controls.
- Target fill: `rgba(15, 17, 21, 0.90)` with **18px blur**.
- Always pair with the scrim token and verify text contrast over the real background.
- Never use as a standard content card.

### Glass performance rules

- Never animate blur radius, large shadows, or background filters.
- Animate only opacity and transform for routine transitions.
- Keep blur bounds clipped to the component; avoid full-screen blur while scrolling.
- Isolate animated or blurred regions with `RepaintBoundary` in Flutter when profiling shows repaint spill.
- Replace blur with a precomposed translucent gradient on low-performance devices or during the capstone demo if frame time is unstable.
- Use compressed WebP/AVIF background images sized near their rendered dimensions.

## 3. Color system

### Brand colors

- **Primary Accent (Coral Orange) `#FF5E36`:** primary CTA, active navigation, selected workout state, and key progress. Chữ và Icon trên nền nút Primary bắt buộc dùng màu trắng `#FFFFFF`.
- **Cool Reflection `#A9C7E8`:** glass edges, focus support, and restrained technological highlights.
- **Deep Graphite `#0F1115`:** primary mobile scaffold / background.
- **Card Surface `#181B22`:** default content card surface, bordered with 1px `#262A34`.

Orange is not ambient decoration. In a typical viewport, it should occupy roughly **5–10%** of pixels. Use orange glow only around a selected or primary control; never around every card.

### Semantic colors

- **Success / Active / Nutrition `#2ECC71`:** hoàn thành, đang hiệu lực, tiến độ dinh dưỡng.
- **Warning / Secondary Avatar `#F39C12`:** cảnh báo, trạng thái chờ, avatar phụ.
- **Subtext / Future State `#8E95A5`:** chữ phụ, trạng thái tương lai chưa diễn ra.
- **Coach Avatar "LN" (Lê Hoàng Nam):** nền `#F5B041`, chữ `#181B22` đậm xuyên suốt toàn bộ các thẻ.
- Error `#F15B64`
- Information `#70AEE8`

Every status includes text, an icon, or shape in addition to color. Do not use orange for warnings because it is already the brand action color.

### Contrast

- Normal text: minimum **4.5:1**.
- Large text and meaningful non-text controls: minimum **3:1**.
- Secondary text on glass must be tested against the composed background, not only against the glass fill token.
- When contrast varies due to photography, strengthen the surface opacity before adding text shadow.

## 4. Typography

Use **Be Vietnam Pro** as the single product family. It supports Vietnamese clearly, feels geometric and modern, and reduces font-loading complexity.

- Display and performance values: 700–800 weight.
- Screen and section titles: 600–700 weight.
- Body: 400 weight.
- Labels and controls: 600 weight.
- Use tabular figures for time, weight, repetitions, prices, attendance, and charts.
- Sentence case is the default. Uppercase is limited to short brand marks and micro-labels.
- Mobile body copy starts at 16px when it carries instructions; 14px is acceptable for compact metadata.
- Support system text scaling without truncating primary actions.

## 5. Layout and spacing

- Use a 4px base unit and an 8px default rhythm.
- Phone horizontal gutter: 16px; large phone/tablet: 24px.
- Internal card padding: 16px compact, 20px standard, 24px featured.
- Space between related items: 8–12px.
- Space between sections: 20–24px.
- Avoid cards inside cards. Use spacing, dividers, or tonal groups before adding another container.
- A screen should have one obvious visual entry point and one dominant action per decision area.
- Fixed navigation must reserve safe-area and scroll insets.

## 6. Shape, border, and depth

- Compact controls: 10px radius.
- Buttons and inputs: 14px radius.
- Standard cards: 20px radius.
- Glass docks, sheets, and featured panels: 24px radius.
- Full radius is limited to chips, avatars, progress dots, and circular controls.
- Borders are normally 1px. Use 2px only for keyboard focus or a selected state that needs additional clarity.
- Prefer cool edge light and tonal separation to large drop shadows.
- One component may have either a strong glow or a strong shadow, never both.

## 7. Iconography and imagery

- Use one vector icon family with consistent 1.75–2px strokes.
- Use outline icons for navigation and routine actions; reserve filled icons for selected states.
- Default icon sizes: 16, 20, 24, and 28px.
- Every icon button has a 44pt iOS or 48dp Android hit area and an accessible name.
- Do not use emoji as structural icons.
- Photography should show premium, realistic training environments with controlled warm highlights.
- Avoid generic bodybuilding clichés, exaggerated neon, fake holograms, and sci-fi HUD decorations.

## 8. Components

### Buttons

- One orange primary button per decision area.
- Secondary buttons use graphite or restrained glass without orange fill.
- Press feedback begins within 80–150ms and must not shift layout bounds.
- Disabled controls retain readable labels, expose disabled semantics, and do not respond to taps.

### Cards

- Standard information cards are solid Level 1 surfaces.
- Use imagery in no more than one featured card per viewport.
- A whole card is tappable only when it performs one clear action; otherwise use explicit controls.
- Repeated cards in one list share the same radius, padding, and hierarchy.

### Chips and status

- Chips are compact labels, not miniature buttons unless they visibly support interaction.
- Success green is for completed or healthy progress, not general decoration.
- Selected filters may use an orange outline or low-opacity fill; avoid full orange fills across a large chip row.

### Bottom navigation

- Maximum five destinations.
- Use Level 2 glass for the navigation container.
- Selected destination combines icon treatment and label emphasis; color alone is insufficient.
- The central AI action may be elevated, but its glow must remain inside a bounded area and must not obscure adjacent labels.

### Forms and feedback

- Persistent labels, nearby helper/error text, and validation on blur.
- Async actions expose loading, success, and recovery states and prevent duplicate submission.
- Every data surface includes loading, empty, error, offline, disabled, and success behavior where applicable.

## 9. Motion

- Press feedback: 80–150ms.
- Local state change: 180–240ms.
- Page transition, sheet, or dialog: 240–320ms.
- Enter easing: decelerating; exit is slightly faster than enter.
- Animate opacity and transform. Avoid animating layout dimensions, blur, or large shadows.
- Motion is interruptible and respects reduced-motion preferences.
- Do not stagger dense workout logs, tables, or chart marks merely for decoration.

## 10. Mobile and Admin relationship

The Flutter Member/Coach experience is **dark-first** and carries the full Futuristic Performance Glass identity. The Bootstrap Admin application shares typography, orange brand actions, semantic states, and spacing, but uses mostly solid surfaces. Admin data density and readability take priority over glass effects.

Material 3 is the Flutter foundation. Bootstrap 5.3 is the Admin foundation. Do not mix a second component system into either surface.

## 11. Explicit anti-patterns

- No cyberpunk, gaming HUD, rainbow neon, or decorative scan lines.
- No glass on every card.
- No blur behind long text or dense form content.
- No more than one glowing primary focal point in a viewport.
- No random radii, icon families, or ad-hoc hex colors.
- No low-contrast gray text on transparent gray surfaces.
- No nested card borders when spacing or a divider can establish hierarchy.
- No motion that delays interaction or makes the demo fragile.

## 12. Screen review checklist

Before accepting a screen, confirm:

- [ ] The first focal point is obvious within three seconds.
- [ ] At least 80% of the visible surface is stable and non-blurred.
- [ ] Orange is reserved for actions, selection, or meaningful progress.
- [ ] No glass layer contains another blurred glass layer.
- [ ] Normal text reaches 4.5:1 contrast on the composed background.
- [ ] Touch targets meet 44pt iOS or 48dp Android minimums.
- [ ] Spacing follows the 4/8px system and sections have visible breathing room.
- [ ] Loading, empty, error, offline, disabled, and success states are covered.
- [ ] Press feedback is immediate and motion respects reduced motion.
- [ ] The screen remains usable when background photography or blur is disabled.
- [ ] Content is not hidden behind the status bar, keyboard, bottom navigation, or gesture area.
- [ ] The screen is tested on a 375px-wide phone and in landscape.

## 13. Capstone demo mode

For a reliable live demonstration:

- Precache the hero/background image before entering the home screen.
- Keep one static background image per main screen.
- Use Level 2 glass only for the quick-action dock and bottom navigation.
- Use solid Level 1 cards for scrolling content.
- Disable nonessential particle, parallax, and continuous glow animations.
- Profile on the actual demo device, not only an emulator.
- If frame stability drops, remove blur from scrolling regions before reducing typography or spacing quality.
