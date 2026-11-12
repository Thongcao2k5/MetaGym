# Meta Gym Theme Adapters

These are historical starter adapters. They predate the current Flutter app and may contain older colors. Do not copy them into the application. The current visual rule is the repository root `DESIGN.md`; the live Flutter tokens are in `mobile-app/lib/core/theme/app_theme.dart`.

## Flutter

The app already has a Flutter theme. For new screens, import that existing theme rather than this sample adapter. The following example describes the original starter setup only:

```dart
MaterialApp.router(
  theme: MetaGymTheme.light,
  darkTheme: MetaGymTheme.dark,
  themeMode: ThemeMode.system,
  routerConfig: router,
);
```

Bundle Be Vietnam Pro as a local variable-font asset and keep the exact family name `Be Vietnam Pro` in `pubspec.yaml`. Local assets avoid runtime font downloads and give predictable offline behavior.

Use `go_router` when the real Flutter app is scaffolded. Member and Coach may have different route trees, but both should use declarative routing, predictable back behavior, and no more than five top-level mobile destinations.

## Bootstrap Admin

Load Bootstrap 5.3 first, then load `bootstrap-theme.css` so the Meta Gym variables and component overrides win in the cascade:

```js
import 'bootstrap/dist/css/bootstrap.min.css';
import './styles/bootstrap-theme.css';
```

Set `data-bs-theme="light"` or `data-bs-theme="dark"` on the document root. Use system preference as the initial value and persist an explicit user choice.

Self-host Be Vietnam Pro with `@font-face` before this theme file. Do not use the Google Fonts runtime stylesheet in production.

The Flutter app carries the full dark-first Futuristic Performance Glass identity. The Admin app intentionally uses mostly solid Bootstrap surfaces because dense data views benefit from stable contrast and lower rendering cost.

## Validation

Run this after changing design tokens:

```powershell
designmd lint DESIGN.md
```

The current baseline is zero errors and zero warnings.
