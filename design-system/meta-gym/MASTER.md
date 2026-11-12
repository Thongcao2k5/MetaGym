# Meta Gym — Design direction at a glance

Read the repository root [DESIGN.md](../../DESIGN.md) for the full rule. This page is a short retrieval guide.

**Futuristic Performance Glass** means modern, luxurious, strong, and easy to use. Member and Coach are dark-first. Warm smoked glass belongs on Home, navigation, and a selected featured card. Dense lists, forms, calendars, charts, and Admin screens use stable graphite surfaces.

## Fixed identity

- Canvas `#0F1115`; card `#181B22`; card border `#262A34` at 1px.
- Primary coral orange `#FF5E36`; text and icons on orange are always `#FFFFFF`.
- Primary text `#FFFFFF`; secondary text `#8E95A5`.
- Success `#2ECC71`; warning `#F39C12`.
- Coach LN avatar: background `#F5B041`, bold text `#181B22`.
- Typeface: locally bundled Be Vietnam Pro.

## Composition

- 16px phone gutter, 8px spacing rhythm, 20px standard card radius.
- One dominant action per decision area. Avoid bold text across an entire card.
- Do not fill space with extra cards or repeat navigation already available in the bottom bar.
- Glass needs a real background, readable text, clipped blur, and a solid fallback.
- Review real rendered screens and all business states before acceptance.

The app's Flutter token implementation is `mobile-app/lib/core/theme/app_theme.dart`. Historical adapter samples are not the current app theme.
