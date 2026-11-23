import 'package:flutter/material.dart';

/// Warm smoked-glass token set aligned with `design-system/meta-gym/pages/member-home.md`
/// and `design-system/flutter-screens/22-11-2026/tokens.css`.
abstract final class MetaGymWarmGlassTokens {
  static const Color heroTop = Color(0xCD342D28);
  static const Color heroBottom = Color(0xC829241F);
  static const Color heroBorder = Color(0xB7B3A99D);
  static const Color heroHighlight = Color(0x75FFF5E9);

  static const Color cardFill = Color(0xC42B2622);
  static const Color cardFeaturedFill = Color(0xB82D2824);
  static const Color cardBorder = Color(0xA3A79D92);
  static const Color cardHighlight = Color(0x70FFF6EA);

  static const Color metricPanelFill = Color(0x80211E1C);
  static const Color metricPanelBorder = Color(0x9A8C8176);

  static const Color circleButtonFill = Color(0x9E2F2924);
  static const Color circleButtonBorder = Color(0x95ADA295);

  static const Color navGlassFill = Color(0xBF302923);
  static const Color navSolidFill = Color(0xFF292420);

  static const Color mutedText = Color(0xFFC8C2BC);
  static const Color subtitleMuted = Color(0xFFB8B0A8);
}

/// Adaptive Dark / Light palette mirroring `tokens.css` (`:root` and `body.light-mode`).
///
/// Access via `MetaGymTheme.paletteOf(context)` so components adapt cleanly
/// between Futuristic Performance Glass (Dark) and Daylight Studio (Light).
@immutable
class MetaGymPalette extends ThemeExtension<MetaGymPalette> {
  const MetaGymPalette({
    required this.canvas,
    required this.surfaceSolid,
    required this.surfaceRaised,
    required this.borderSolid,
    required this.glassCoolBg,
    required this.glassCoolBorder,
    required this.glassHighlight,
    required this.warmGlassTop,
    required this.warmGlassBottom,
    required this.warmGlassBorder,
    required this.metricPanelBg,
    required this.metricPanelBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.textWarmMuted,
    required this.primaryText,
    required this.chipActiveBg,
    required this.chipActiveText,
    required this.reflection,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
  });

  final Color canvas;
  final Color surfaceSolid;
  final Color surfaceRaised;
  final Color borderSolid;
  final Color glassCoolBg;
  final Color glassCoolBorder;
  final Color glassHighlight;
  final Color warmGlassTop;
  final Color warmGlassBottom;
  final Color warmGlassBorder;
  final Color metricPanelBg;
  final Color metricPanelBorder;
  final Color textPrimary;
  final Color textSecondary;
  final Color textWarmMuted;
  final Color primaryText;
  final Color chipActiveBg;
  final Color chipActiveText;
  final Color reflection;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;

  static const MetaGymPalette dark = MetaGymPalette(
    canvas: MetaGymTheme.scaffoldBackground,
    surfaceSolid: MetaGymTheme.cardSurface,
    surfaceRaised: MetaGymTheme.elevatedSurface,
    borderSolid: MetaGymTheme.cardBorder,
    glassCoolBg: MetaGymTheme.performanceGlass,
    glassCoolBorder: MetaGymTheme.performanceGlassBorder,
    glassHighlight: MetaGymTheme.performanceGlassTopHighlight,
    warmGlassTop: MetaGymWarmGlassTokens.heroTop,
    warmGlassBottom: MetaGymWarmGlassTokens.heroBottom,
    warmGlassBorder: MetaGymWarmGlassTokens.heroBorder,
    metricPanelBg: MetaGymWarmGlassTokens.metricPanelFill,
    metricPanelBorder: MetaGymWarmGlassTokens.metricPanelBorder,
    textPrimary: MetaGymTheme.textPrimary,
    textSecondary: MetaGymTheme.textSecondary,
    textWarmMuted: MetaGymWarmGlassTokens.mutedText,
    primaryText: MetaGymTheme.primary,
    chipActiveBg: Color(0x38FF5E36),
    chipActiveText: Color(0xFFFFFFFF),
    reflection: MetaGymTheme.reflectionBlue,
    success: MetaGymTheme.success,
    warning: MetaGymTheme.warning,
    error: MetaGymTheme.dangerCoral,
    info: MetaGymTheme.infoSteelBlue,
  );

  static const MetaGymPalette light = MetaGymPalette(
    canvas: Color(0xFFE8EEF5),
    surfaceSolid: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFECF1F7),
    borderSolid: Color(0xFFC2CDD9),
    glassCoolBg: Color(0xEBFFFFFF),
    glassCoolBorder: Color(0xF2B8C5D6),
    glassHighlight: Color(0xFAFFFFFF),
    warmGlassTop: Color(0xFAFFFFFF),
    warmGlassBottom: Color(0xF5F7F9FC),
    warmGlassBorder: Color(0xF2BFCBDA),
    metricPanelBg: Color(0xFFEDF2F8),
    metricPanelBorder: Color(0xFFC4D0DF),
    textPrimary: Color(0xFF11151A),
    textSecondary: Color(0xFF475569),
    textWarmMuted: Color(0xFF475569),
    primaryText: Color(0xFFC93B16),
    chipActiveBg: Color(0x24FF5E36),
    chipActiveText: Color(0xFFC93B16),
    reflection: Color(0xFF1D5FA7),
    success: Color(0xFF15803D),
    warning: Color(0xFFB45309),
    error: Color(0xFFC92A37),
    info: Color(0xFF1D63B8),
  );

  @override
  MetaGymPalette copyWith({
    Color? canvas,
    Color? surfaceSolid,
    Color? surfaceRaised,
    Color? borderSolid,
    Color? glassCoolBg,
    Color? glassCoolBorder,
    Color? glassHighlight,
    Color? warmGlassTop,
    Color? warmGlassBottom,
    Color? warmGlassBorder,
    Color? metricPanelBg,
    Color? metricPanelBorder,
    Color? textPrimary,
    Color? textSecondary,
    Color? textWarmMuted,
    Color? primaryText,
    Color? chipActiveBg,
    Color? chipActiveText,
    Color? reflection,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
  }) {
    return MetaGymPalette(
      canvas: canvas ?? this.canvas,
      surfaceSolid: surfaceSolid ?? this.surfaceSolid,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      borderSolid: borderSolid ?? this.borderSolid,
      glassCoolBg: glassCoolBg ?? this.glassCoolBg,
      glassCoolBorder: glassCoolBorder ?? this.glassCoolBorder,
      glassHighlight: glassHighlight ?? this.glassHighlight,
      warmGlassTop: warmGlassTop ?? this.warmGlassTop,
      warmGlassBottom: warmGlassBottom ?? this.warmGlassBottom,
      warmGlassBorder: warmGlassBorder ?? this.warmGlassBorder,
      metricPanelBg: metricPanelBg ?? this.metricPanelBg,
      metricPanelBorder: metricPanelBorder ?? this.metricPanelBorder,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textWarmMuted: textWarmMuted ?? this.textWarmMuted,
      primaryText: primaryText ?? this.primaryText,
      chipActiveBg: chipActiveBg ?? this.chipActiveBg,
      chipActiveText: chipActiveText ?? this.chipActiveText,
      reflection: reflection ?? this.reflection,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
    );
  }

  @override
  MetaGymPalette lerp(ThemeExtension<MetaGymPalette>? other, double t) {
    if (other is! MetaGymPalette) return this;
    return MetaGymPalette(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surfaceSolid: Color.lerp(surfaceSolid, other.surfaceSolid, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      borderSolid: Color.lerp(borderSolid, other.borderSolid, t)!,
      glassCoolBg: Color.lerp(glassCoolBg, other.glassCoolBg, t)!,
      glassCoolBorder: Color.lerp(glassCoolBorder, other.glassCoolBorder, t)!,
      glassHighlight: Color.lerp(glassHighlight, other.glassHighlight, t)!,
      warmGlassTop: Color.lerp(warmGlassTop, other.warmGlassTop, t)!,
      warmGlassBottom: Color.lerp(warmGlassBottom, other.warmGlassBottom, t)!,
      warmGlassBorder: Color.lerp(warmGlassBorder, other.warmGlassBorder, t)!,
      metricPanelBg: Color.lerp(metricPanelBg, other.metricPanelBg, t)!,
      metricPanelBorder: Color.lerp(
        metricPanelBorder,
        other.metricPanelBorder,
        t,
      )!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textWarmMuted: Color.lerp(textWarmMuted, other.textWarmMuted, t)!,
      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
      chipActiveBg: Color.lerp(chipActiveBg, other.chipActiveBg, t)!,
      chipActiveText: Color.lerp(chipActiveText, other.chipActiveText, t)!,
      reflection: Color.lerp(reflection, other.reflection, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}

/// Shared Material 3 theme adapter and design token source for Meta Gym.
///
/// Mirrors `DESIGN.md`, `design-system/meta-gym/MASTER.md`, and
/// `design-system/flutter-screens/22-11-2026/tokens.css` so screens reuse
/// semantic tokens rather than hard-coding hex values.
abstract final class MetaGymTheme {
  static const String fontFamily = 'Be Vietnam Pro';
  static const List<String> fontFamilyFallback = <String>[
    'Segoe UI',
    'Roboto',
    '.SF Pro Text',
    'sans-serif',
  ];

  // Mandatory Semantic Design Tokens (DESIGN.md — Futuristic Performance Glass)
  static const Color scaffoldBackground = Color(0xFF0F1115);
  static const Color cardSurface = Color(0xFF181B22);
  static const Color elevatedSurface = Color(0xFF1F232C);
  static const Color cardBorder = Color(0xFF262A34);
  static const Color primary = Color(0xFFFF5E36);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color success = Color(0xFF2ECC71);
  static const Color onSuccess = Color(0xFF06261D);
  static const Color warning = Color(0xFFF39C12);
  static const Color onWarning = Color(0xFF2A1900);
  static const Color onError = Color(0xFF2C080B);
  static const Color onInfo = Color(0xFF071A2C);
  static const Color textPrimary = Color(0xFFF7F9FC);
  static const Color textSecondary = Color(0xFF8E95A5);
  static const Color coachAvatarBackground = Color(0xFFF5B041);
  static const Color coachAvatarForeground = Color(0xFF181B22);
  static const Color scrim = Color(0xB8040609); // rgba(4, 6, 9, 0.72)

  // Brand & Accent Tokens (DESIGN.md)
  static const Color brandOrange = primary;
  static const Color brandOrangeHover = Color(0xFFE84E27);
  static const Color brandOrangePressed = Color(0xFFCF3A1E);
  static const Color onBrandOrange = onPrimary;
  static const Color reflectionBlue = Color(0xFFA9C7E8);
  static const Color progressGreen = success;
  static const Color warningAmber = warning;
  static const Color dangerCoral = Color(0xFFF15B64);
  static const Color infoSteelBlue = Color(0xFF70AEE8);
  static const Color focusBlue = Color(0xFF8DBCF0);

  // Dark Mode — Performance Obsidian Surfaces
  static const Color darkCanvas = scaffoldBackground;
  static const Color darkCanvasElevated = Color(0xFF14171E);
  static const Color darkSurface = cardSurface;
  static const Color darkSurfaceMid = Color(0xFF1A1E26);
  static const Color darkSurfaceRaised = elevatedSurface;
  static const Color darkSurfaceInteractive = Color(0xFF232934);

  // Dark Mode — Text Hierarchy
  static const Color darkTextPrimary = textPrimary;
  static const Color darkTextSecondary = textSecondary;
  static const Color darkTextTertiary = Color(0xFF6B7280);

  // Dark Mode — Borders & Dividers
  /// Card border at ~10% opacity (within 8–12% rule).
  static const Color darkCardBorderSubtle = Color(0x1ACFE2FF);
  static const Color darkBorderSubtle = Color(0xFF222B35);
  static const Color darkBorderStrong = Color(0xFF3A4654);

  /// Vertical/inner divider at ~9% opacity (within 8–10% rule).
  static const Color darkDividerSubtle = Color(0x17D4E4FF);

  // Light Mode — Daylight Studio Surfaces
  static const Color _lightBackground = Color(0xFFF5F7FA);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightText = Color(0xFF11151A);

  /// Level 2 Performance Glass (DESIGN.md §2).
  /// `rgba(24, 27, 34, 0.78)` with `12px` blur and `rgba(212, 228, 255, 0.18)` border.
  static const Color performanceGlass = Color(0xC7181B22);
  static const Color performanceGlassBorder = Color(0x2ED4E4FF);
  static const Color performanceGlassTopHighlight = Color(0x52EBF6FF);
  static const double performanceGlassBlur = 12;
  static const double bottomNavGlassBlur = 12;

  /// Circular header icon glass (`search`, `avatar`) with cool reflective border.
  static const Color headerCircleGlass = Color(0xC7181B22);
  static const Color headerCircleBorder = Color(0x38A9C7E8);

  /// Level 3 Modal / Overlay Glass (DESIGN.md §2).
  /// `rgba(15, 17, 21, 0.90)` with `18px` blur.
  static const Color overlayGlass = Color(0xE60F1115);
  static const Color overlayGlassBorder = Color(0x52EBF6FF);
  static const double overlayGlassBlur = 18;

  // Radius Tokens (DESIGN.md §6)
  static const double radiusXs = 6;
  static const double radiusSm = 10;
  static const double radiusInput = 14;
  static const double radiusCard = 20;
  static const double radiusGlassDock = 24;
  static const double radiusFull = 999;

  // Spacing Tokens (DESIGN.md §5)
  static const double pageGutter = 16;
  static const double cardPadding = 18;
  static const double sectionGap = 20;

  // Motion Tokens (DESIGN.md §9)
  static const Duration pressDuration = Duration(milliseconds: 110);
  static const Duration localStateDuration = Duration(milliseconds: 220);
  static const Duration sheetTransitionDuration = Duration(milliseconds: 260);
  static const Duration pageTransitionDuration = Duration(milliseconds: 280);

  static Duration stateDurationOf(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : localStateDuration;

  /// Returns the active [MetaGymPalette] from the nearest [Theme], defaulting
  /// to [MetaGymPalette.dark] (dark-first) when no extension is registered.
  static MetaGymPalette paletteOf(BuildContext context) {
    return Theme.of(context).extension<MetaGymPalette>() ?? MetaGymPalette.dark;
  }

  /// Whether the active Meta Gym theme is Daylight Studio (Light Mode).
  static bool isLightPalette(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<MetaGymPalette>() != null &&
        theme.brightness == Brightness.light;
  }

  /// Shared pressed/focus feedback that stays visible on graphite and warm glass.
  static Color interactionOverlay(Set<WidgetState> states) {
    if (states.contains(WidgetState.focused) ||
        states.contains(WidgetState.hovered)) {
      return reflectionBlue.withValues(alpha: 0.16);
    }
    if (states.contains(WidgetState.pressed)) {
      return brandOrange.withValues(alpha: 0.18);
    }
    return Colors.transparent;
  }

  // Tabular figures feature for timers, calories, days, weights, reps.
  static const List<FontFeature> tabularFigures = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  /// Detects `flutter_test` binding so `RenderRepaintBoundary.toImage()` in
  /// fake-async widget tests does not deadlock on `BackdropFilter` layers.
  static bool get isFlutterTestEnvironment {
    try {
      final bindingName = WidgetsBinding.instance.runtimeType.toString();
      return bindingName.contains('TestWidgetsFlutterBinding') ||
          bindingName.contains('AutomatedTestWidgetsFlutterBinding');
    } catch (_) {
      return true;
    }
  }

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final palette = isDark ? MetaGymPalette.dark : MetaGymPalette.light;
    final surface = isDark ? darkSurface : _lightSurface;
    final onSurface = isDark ? darkTextPrimary : _lightText;
    final outline = isDark ? cardBorder : const Color(0xFFCBD4DF);

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: brandOrange,
          brightness: brightness,
          primary: brandOrange,
          onPrimary: onBrandOrange,
          secondary: palette.reflection,
          onSecondary: onInfo,
          surface: surface,
          onSurface: onSurface,
          error: palette.error,
          onError: Colors.white,
        ).copyWith(
          outline: outline,
          tertiary: palette.success,
          onTertiary: onSuccess,
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
            height: 1.25,
            fontWeight: FontWeight.w700,
          ),
          titleLarge: baseTextTheme.titleLarge?.copyWith(
            fontFamily: fontFamily,
            fontSize: 20,
            height: 1.3,
            fontWeight: FontWeight.w700,
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
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
          labelMedium: baseTextTheme.labelMedium?.copyWith(
            fontFamily: fontFamily,
            fontSize: 12,
            height: 1.35,
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
      extensions: <ThemeExtension<dynamic>>[palette],
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
        style:
            FilledButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: roundedRectangle,
              textStyle: textTheme.labelLarge,
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith(interactionOverlay),
            ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style:
            ElevatedButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: roundedRectangle,
              textStyle: textTheme.labelLarge,
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith(interactionOverlay),
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: roundedRectangle,
              side: BorderSide(color: outline),
              textStyle: textTheme.labelLarge,
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith(interactionOverlay),
            ),
      ),
      textButtonTheme: TextButtonThemeData(
        style:
            TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: roundedRectangle,
              textStyle: textTheme.labelLarge,
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith(interactionOverlay),
            ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style:
            IconButton.styleFrom(
              minimumSize: const Size(48, 48),
              fixedSize: const Size(48, 48),
              padding: EdgeInsets.zero,
              shape: const CircleBorder(),
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith(interactionOverlay),
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
          borderSide: BorderSide(color: palette.error),
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
