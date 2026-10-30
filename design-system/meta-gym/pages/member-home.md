# Member Home — Page Rules

This page inherits `../MASTER.md`. These rules resolve the home-screen composition shown in the current Meta Gym concept.

## Visual hierarchy

1. Greeting and current member identity.
2. Quick-action dock: Lịch tập, Giáo trình, Dinh dưỡng, Coach.
3. Today's workout as the primary content card.
4. Membership/Coach summary.
5. Nutrition guidance and weekly progress.
6. Bottom navigation with AI as the single elevated action.

On days with an upcoming workout, move **Hôm nay** above membership status so the next action appears without scrolling.

## Material allocation

### Global Baseline (80/20 Rule)
- Canvas: obsidian plus one dimmed, static gym image.
- Quick-action dock: Level 2 performance glass.
- Bottom navigation: Level 2 performance glass.
- Workout, membership, nutrition, and progress: Level 1 solid surfaces.
- AI detail panel or modal: Level 3 overlay glass.
- Do not blur individual cards in the scrolling list.

### Page Override: Showcase Mode (Graduation / Thesis Presentation)
To achieve a "Premium Smoked Optical Glass" aesthetic without compromising data-heavy screens or Admin portals, Member Home introduces an isolated **Showcase Mode**:
- **Material Ratio**: **60% Solid / 40% Optical Glass**.
- **Visual Effect Dial**: **7/10** (Optical glass with multi-layered specular edge reflection, top/left bevel highlights, 20–22px blur, and dual ambient lighting).
- **Motion Dial**: **4/10** (Strictly static lights and blur; only opacity and translation transitions).
- **Three Optical Glass Regions (Level C)**:
  1. *Quick-action dock (“Optical Launcher”)*:
     - Radius 26px, 18px blur, top-edge highlight (`rgba(255,255,255,0.18)`), border `rgba(212,228,255,0.18)`.
     - Overall height: **112–118px** (actual 116px).
     - 0 dividers between actions.
     - Min touch target: **64×64px** per action (actual 72.25×64px).
     - Selected tile: `rgba(255,90,54,0.12)`, border `rgba(255,90,54,0.32)`, radius 18px, inner top highlight 10%.
     - Unselected items: transparent, no container, reflection-blue `#B9D0E8` icons (24px, 1.85px stroke), label 11.5px (weight 600).
     - Indicator: active 20×5px orange capsule + inactive 5×5px gray dot.
     - "Xem tất cả" replaced by a 40×40px reflection-blue glass grid button (`aria-label="Xem tất cả tiện ích"`).
     - Zero blur animation; carousel uses pure 200ms transform easing.
  2. *Card “Hôm nay” (Featured Glass Hero)*: Radius 26px, 20px blur, background translucency calibrated 12% clearer (`rgba(255,255,255,0.09)` to `0.03`), text contrast maintained > 4.5:1 (actual white title 14.2:1).
  3. *Bottom navigation*: Radius 28px, 22px blur, top-edge highlight, AI focal glow reduced by 50% (`0 0 10px rgba(255,90,54,0.20), 0 4px 14px rgba(0,0,0,0.30)`) ensuring shadow is softer than primary hero CTA.
- **Scroll Content Clearance**:
  - `#scroll` content padding-bottom calibrated to **116px** (70px navigation height + 24px safe area + 16px buffer + headroom) to guarantee the last Explore card has a clearance gap > 16px (actual 91px gap) and is never obscured.
- **Terminology & Typography Refinement**:
  - Replace all English status chips with Vietnamese: **"Hiệu lực"** (replaces "Active").
  - Zero text-shadow, zero RGB subpixel fringe, hardware-accurate crisp font rendering (`-webkit-font-smoothing: antialiased`, `text-rendering: optimizeLegibility`).
- **Solid Performance Surfaces (Level B - 60%)**:
  - Gói tập & Coach, Dinh dưỡng, Tiến độ tuần, Khám phá Meta Gym use deep tonal solid graphite (`linear-gradient(145deg, rgba(24,31,39,0.97), rgba(15,20,26,0.97))`, border `rgba(212,228,255,0.10)`).
- **Ambient Lighting**: Two static, large, soft radial gradients behind the canvas:
  - Cool blue ambient light at top-right: `rgba(169, 199, 232, 0.16)`
  - Warm orange ambient light at bottom-left: `rgba(255, 90, 54, 0.10)`
  - Scrim calibration: **72% – 78%** to allow optical transmission through glass while keeping foreground text perfectly readable.
- **Performance Mode Fallback**:
  - If a low-end device drops frames, provide a toggle to fall back to the 80/20 baseline: Hero Card "Hôm nay" reverts to solid `#11161C` without backdrop blur, and blur on the dock/nav simplifies to flat `rgba(18,23,30,0.92)`.


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

- Two blurred regions visible at once: quick-action dock and bottom navigation.
- All scrolling cards remain non-blurred.
- Precache the single background image.
- Avoid parallax and continuously animated glow.
- Use opacity/transform only for card entrance and state changes.

## Acceptance checks

- The next workout is discoverable within three seconds.
- Navigation and quick actions retain 48dp minimum hit areas.
- Secondary text remains readable over the real composed background.
- Bottom content is not hidden by the glass navigation bar.
- Home remains clear if the background image fails to load.
