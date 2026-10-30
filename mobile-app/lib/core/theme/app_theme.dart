import 'package:flutter/material.dart';

/// Shared Material 3 theme adapter and design token source for Meta Gym.
///
/// Mirrors `design-system/meta-gym/adapters/meta_gym_theme.dart` and `DESIGN.md`
/// tokens so screens reuse semantic tokens rather than hard-coding hex values.
abstract final class MetaGymTheme {
  static const String fontFamily = 'Be Vietnam Pro';
  static const List<String> fontFamilyFallback = <String>[
    'Segoe UI',
    'Roboto',
    '.SF Pro Text',
    'sans-serif',
  ];

  // Brand & Accent Tokens (DESIGN.md §2.1 & §2.4)
  static const Color brandOrange = Color(0xFFFF5A36);
  static const Color brandOrangeHover = Color(0xFFE84729);
  static const Color brandOrangePressed = Color(0xFFCF3A1E);
  static const Color onBrandOrange = Color(0xFF090B0E);
  static const Color reflectionBlue = Color(0xFFA9C7E8);
  static const Color progressGreen = Color(0xFF23C997);
  static const Color warningAmber = Color(0xFFF2A93B);
  static const Color dangerCoral = Color(0xFFF15B64);
  static const Color infoSteelBlue = Color(0xFF70AEE8);
  static const Color focusBlue = Color(0xFF8DBCF0);

  // Dark Mode — Performance Obsidian Surfaces (DESIGN.md §2.3 & §3)
  static const Color darkCanvas = Color(0xFF080A0D);
  static const Color darkCanvasElevated = Color(0xFF0E1217);
  static const Color darkSurface = Color(0xFF11161C);
  static const Color darkSurfaceMid = Color(0xFF151B22);
  static const Color darkSurfaceRaised = Color(0xFF181F27);
  static const Color darkSurfaceInteractive = Color(0xFF1F2833);

  // Dark Mode — Text Hierarchy (DESIGN.md §2.3)
  static const Color darkTextPrimary = Color(0xFFF7F9FC);
  static const Color darkTextSecondary = Color(0xFFB8C2D0);
  static const Color darkTextTertiary = Color(0xFF818C9C);

  // Dark Mode — Borders & Dividers (DESIGN.md §2.3 & §5.3)
  /// Card border at ~10% opacity (within 8–12% rule).
  static const Color darkCardBorderSubtle = Color(0x1ACFE2FF);
  static const Color darkBorderSubtle = Color(0xFF222B35);
  static const Color darkBorderStrong = Color(0xFF3A4654);

  /// Vertical/inner divider at ~9% opacity (within 8–10% rule).
  static const Color darkDividerSubtle = Color(0x17D4E4FF);

  // Light Mode — Daylight Studio Surfaces (DESIGN.md §2.2)
  static const Color _lightBackground = Color(0xFFF5F7FA);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightText = Color(0xFF11151A);

  /// Level 2 Performance Glass (DESIGN.md §3.2 & Step 3/4).
  /// `rgba(18, 23, 30, 0.72)` with `14–16px` blur and `rgba(212, 228, 255, 0.18)` border.
  /// Use ONLY for Quick-action dock and Bottom navigation on Member Home.
  static const Color performanceGlass = Color(0xB812171E); // rgba(18, 23, 30, 0.72)
  static const Color performanceGlassBorder = Color(0x2ED4E4FF); // rgba(212, 228, 255, 0.18)
  static const Color performanceGlassTopHighlight = Color(0x38E6F1FF);
  static const double performanceGlassBlur = 14;
  static const double bottomNavGlassBlur = 16;

  /// Circular header icon glass (`search`, `avatar`) with cool reflective border.
  static const Color headerCircleGlass = Color(0xB812171E);
  static const Color headerCircleBorder = Color(0x38A9C7E8);

  /// Level 3 Modal / Overlay Glass (DESIGN.md §3.2).
  static const Color overlayGlass = Color(0xE60E1218);
  static const Color overlayGlassBorder = Color(0x52EBF6FF);
  static const double overlayGlassBlur = 18;

  // Radius Tokens (DESIGN.md §5.3)
  static const double radiusInput = 14;
  static const double radiusCard = 20;
  static const double radiusGlassDock = 24;

  // Spacing Tokens (DESIGN.md §5.1)
  static const double pageGutter = 16;
  static const double cardPadding = 18;
  static const double sectionGap = 20;

  // Motion Tokens (DESIGN.md §6.6)
  static const Duration pressDuration = Duration(milliseconds: 110);
  static const Duration localStateDuration = Duration(milliseconds: 220);
  static const Duration sheetTransitionDuration = Duration(milliseconds: 260);

  // Tabular figures feature for timers, calories, days, weights, reps.
  static const List<FontFeature> tabularFigures = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  /// Detects `flutter_test` binding so `RenderRepaintBoundary.toImage()` in
  /// fake-async widget tests does not deadlock on `BackdropFilter` layers.
  static bool get isFlutterTestEnvironment {
    final bindingName = WidgetsBinding.instance.runtimeType.toString();
    return bindingName.contains('TestWidgetsFlutterBinding') ||
        bindingName.contains('AutomatedTestWidgetsFlutterBinding');
  }

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final surface = isDark ? darkSurface : _lightSurface;
    final onSurface = isDark ? darkTextPrimary : _lightText;
    final outline = isDark ? darkBorderStrong : const Color(0xFFCBD4DF);

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: brandOrange,
          brightness: brightness,
          primary: brandOrange,
          onPrimary: onBrandOrange,
          secondary: reflectionBlue,
          onSecondary: const Color(0xFF071A2C),
          surface: surface,
          onSurface: onSurface,
          error: dangerCoral,
          onError: Colors.white,
        ).copyWith(
          outline: outline,
          tertiary: progressGreen,
          onTertiary: const Color(0xFF06261D),
          surfaceContainerLow: isDark ? darkSurface : const Color(0xFFFFFFFF),
          surfaceContainer: isDark ? darkSurfaceMid : const Color(0xFFF5F7FA),
          surfaceContainerHigh: isDark
              ? darkSurfaceRaised
              : const Color(0xFFEDF1F5),
        );

    final baseTextTheme = ThemeData(
      brightness: brightness,
      useMaterial3: true,
    ).textTheme;

    final textTheme = baseTextTheme
        .copyWith(
          displayLarge: baseTextTheme.displayLarge?.copyWith(
            fontFamily: fontFamily,
            fontSize: 40,
            height: 1.1,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
          headlineLarge: baseTextTheme.headlineLarge?.copyWith(
            fontFamily: fontFamily,
            fontSize: 30,
            height: 1.2,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.45,
          ),
          headlineMedium: baseTextTheme.headlineMedium?.copyWith(
            fontFamily: fontFamily,
            fontSize: 24,
            height: 1.2,
            fontWeight: FontWeight.w600,
          ),
          titleLarge: baseTextTheme.titleLarge?.copyWith(
            fontFamily: fontFamily,
            fontSize: 20,
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
          titleMedium: baseTextTheme.titleMedium?.copyWith(
            fontFamily: fontFamily,
            fontSize: 17,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: baseTextTheme.bodyLarge?.copyWith(
            fontFamily: fontFamily,
            fontSize: 16,
            height: 1.5,
          ),
          bodyMedium: baseTextTheme.bodyMedium?.copyWith(
            fontFamily: fontFamily,
            fontSize: 14,
            height: 1.5,
          ),
          labelLarge: baseTextTheme.labelLarge?.copyWith(
            fontFamily: fontFamily,
            fontSize: 14,
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
          labelMedium: baseTextTheme.labelMedium?.copyWith(
            fontFamily: fontFamily,
            fontSize: 12,
            height: 1.3,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.12,
          ),
        )
        .apply(bodyColor: onSurface, displayColor: onSurface);

    final roundedRectangle = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusInput),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark ? darkCanvas : _lightBackground,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      textTheme: textTheme,
      visualDensity: VisualDensity.standard,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: isDark ? darkCanvas : _lightBackground,
        foregroundColor: onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: BorderSide(color: outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: roundedRectangle,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: roundedRectangle,
          side: BorderSide(color: outline),
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: focusBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: dangerCoral),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: surface,
        indicatorColor: brandOrange.withValues(alpha: 0.16),
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
      ),
      dialogTheme: DialogThemeData(
        elevation: 8,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusGlassDock),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusGlassDock),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 1),
    );
  }
}

abstract final class AppTheme {
  static ThemeData get light => MetaGymTheme.light;
  static ThemeData get dark => MetaGymTheme.dark;
}
