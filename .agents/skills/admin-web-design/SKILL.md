---
name: admin-web-design
description: >-
  Guides upgrading, refactoring, and auditing the MetaGym Admin Web (`admin-web/`) using Vite + Bootstrap 5 + Chart.js (Phương án A).
  Use when designing, styling, modularizing, or reviewing any Admin Web page, component, table, chart, or theme in `admin-web/`.
---

# MetaGym Admin Web Design Skill (Bootstrap 5 + Vite)

Use this skill whenever upgrading or building UI in `admin-web/`. It enforces MetaGym's design system (`DESIGN.md` & `design-system/meta-gym/MASTER.md`) on top of **Bootstrap 5 + Vite**.

## 1. Mandatory Pre-Flight Rules
1. Follow `.agents/rules/meta-gym-design.md`: read `DESIGN.md` and `design-system/meta-gym/MASTER.md` before editing UI.
2. **Surface Split Rule (`MASTER.md`):** Unlike Flutter Member/Coach (full glass), **Bootstrap Admin uses primarily solid surfaces for dense data** while sharing typography (`Be Vietnam Pro`), Coral Orange primary actions (`#ff5a36`), semantic states, and spacing.
3. **Always use `bootstrap-theme.css`:** Import `design-system/meta-gym/adapters/bootstrap-theme.css` (or sync its CSS variables `--meta-*` and `--bs-*`) instead of inventing green/custom colors (e.g., remove legacy `#245942` / `#198754` in `admin-web/src/style.css`).
4. **Support `[data-bs-theme="dark"]` and `[data-bs-theme="light"]`:** Use CSS variables (`var(--meta-surface)`, `var(--meta-surface-raised)`, `var(--meta-border)`, `var(--meta-text-primary)`, `var(--meta-text-secondary)`) so switching themes works cleanly without glaring `#FFFFFF` on dark backgrounds.

## 2. Recommended Open-Source Stack (Phương án A — Free & Lightweight)
Keep `admin-web/` fast on Cloudflare Pages / Vite without rewriting to a heavy SPA framework:
- **Core UI:** `bootstrap` (`^5.3.8`, already installed) + tokens from `design-system/meta-gym/adapters/bootstrap-theme.css`.
- **Dashboard Patterns (Reference / Optional):** `tabler` (`tabler/tabler`, MIT, Bootstrap 5-based) for clean sidebar, KPI stat cards, badges, and empty-state patterns.
- **Icons:** `bootstrap-icons` (`twbs/icons`, MIT) or `lucide` (`lucide-icons/lucide`, ISC) — use a single consistent vector icon family (`1.75–2px` stroke).
- **Data Tables:** `@tanstack/table-core` (`TanStack/table`, MIT) or `simple-datatables` (`fiduswriter/simple-datatables`) for search, sort, filter, and pagination on Member/Coach/Payment tables.
- **Charts:** `chart.js` (`^4.5.1`, already installed) styled with MetaGym tokens.
- **Build Image Optimization:** `vite-plugin-image-optimizer` (`FatehAK/vite-plugin-image-optimizer`, MIT) in `admin-web/vite.config.js`.

## 3. Architecture & Refactoring Rules for `admin-web/`
Currently `admin-web/src/main.js` holds the bulk of UI rendering. When upgrading:
1. **Modularize:** Move page views into `admin-web/src/pages/` and reusable UI pieces into `admin-web/src/components/` (e.g., `Sidebar`, `Topbar`, `StatCard`, `DataTable`, `ConfirmModal`, `NoticeBanner`).
2. **Keep Print Support:** Preserve `@media print` rules in `admin-web/src/style.css` (especially `#checkin-print` for printing the Gym static QR code).
3. **Do Not Leak Secrets:** Never put backend secrets or hardcoded admin credentials in `admin-web/`. API calls must read `import.meta.env.VITE_API_BASE_URL || '/api/v1'`.

## 4. Component & UX Standards
- **Buttons & Touch Targets:** Keep `min-block-size: 44px` on interactive buttons (`.btn`) and nav links. Only **one** orange primary CTA (`.btn-primary`) per decision area.
- **Tabular Numbers:** Apply `.font-data` / `font-variant-numeric: tabular-nums` on all KPI numbers, prices, dates, and table columns.
- **Data States:** Every page/table must handle **loading** (spinner/skeleton), **empty** (clear message + action), **error** (actionable notice), and **confirmation** before destructive actions (delete, lock user, revoke).
- **Chart.js Dark/Light Styling:**
  - Grid lines: subtle low-opacity (`rgba(255, 255, 255, 0.08)` in dark mode).
  - Primary dataset color: `#ff5a36` (`--meta-primary`); secondary: `#70aee8` (`--meta-secondary`); success/nutrition: `#23c997` (`--meta-accent`).
- **Images:** Add `loading="lazy"` and `decoding="async"` on list/catalog images.

## 5. Verification Checklist After Editing `admin-web/`
1. Run `cd admin-web && npm run build` (must succeed with zero Vite errors).
2. Run `cd admin-web && npm test` (all unit/integration tests pass).
3. Visually verify responsive layout at Desktop (`1280px+`), Tablet (`768px`), Mobile (`375px`), and Print preview (`#checkin-print`).
