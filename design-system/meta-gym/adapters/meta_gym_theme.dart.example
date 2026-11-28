import 'package:flutter/material.dart';

/// Shared Material 3 theme adapter for the Meta Gym Member and Coach app.
///
/// Bundle Be Vietnam Pro locally before using this theme in production.
/// See the adapter README for the expected family name.
abstract final class MetaGymTheme {
  static const Color brandOrange = Color(0xFFFF5E36);
  static const Color brandOrangeHover = Color(0xFFE84E27);
  static const Color reflectionBlue = Color(0xFFA9C7E8);
  static const Color progressGreen = Color(0xFF2ECC71);
  static const Color warningAmber = Color(0xFFF39C12);
  static const Color textGray = Color(0xFF8E95A5);
  static const Color focusBlue = Color(0xFF8DBCF0);
  static const Color coachAvatarBg = Color(0xFFF5B041);
  static const Color coachAvatarText = Color(0xFF181B22);

  static const Color _lightBackground = Color(0xFFF5F7FA);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightText = Color(0xFF11151A);
  static const Color _darkBackground = Color(0xFF0F1115);
  static const Color _darkSurface = Color(0xFF181B22);
  static const Color _darkText = Color(0xFFF7F9FC);
  static const Color _error = Color(0xFFF15B64);

  /// Level 2 glass. Use only for compact docks, navigation, and floating tools.
  static const Color performanceGlass = Color(0xC7181B22);
  static const Color performanceGlassBorder = Color(0x2ED4E4FF);
  static const double performanceGlassBlur = 12;

  /// Level 3 glass. Use only for sheets, dialogs, and the AI Coach overlay.
  static const Color overlayGlass = Color(0xE60F1115);
  static const Color overlayGlassBorder = Color(0x52EBF6FF);
  static const double overlayGlassBlur = 18;

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final surface = isDark ? _darkSurface : _lightSurface;
    final onSurface = isDark ? _darkText : _lightText;
    final outline = isDark ? const Color(0xFF262A34) : const Color(0xFFCBD4DF);

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: brandOrange,
          brightness: brightness,
          primary: brandOrange,
          onPrimary: const Color(0xFFFFFFFF),
          secondary: reflectionBlue,
          onSecondary: const Color(0xFF071A2C),
          surface: surface,
          onSurface: onSurface,
          error: _error,
          onError: Colors.white,
        ).copyWith(
          outline: outline,
          tertiary: progressGreen,
          onTertiary: const Color(0xFF06261D),
          surfaceContainerLow: isDark
              ? const Color(0xFF181B22)
              : const Color(0xFFFFFFFF),
          surfaceContainer: isDark
              ? const Color(0xFF1D212A)
              : const Color(0xFFF5F7FA),
          surfaceContainerHigh: isDark
              ? const Color(0xFF222731)
              : const Color(0xFFEDF1F5),
        );

    final baseTextTheme = ThemeData(
      brightness: brightness,
      useMaterial3: true,
    ).textTheme;

    final textTheme = baseTextTheme
        .copyWith(
          displayLarge: baseTextTheme.displayLarge?.copyWith(
            fontFamily: 'Be Vietnam Pro',
            fontSize: 40,
            height: 1.1,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
          headlineLarge: baseTextTheme.headlineLarge?.copyWith(
            fontFamily: 'Be Vietnam Pro',
            fontSize: 30,
            height: 1.2,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.45,
          ),
          headlineMedium: baseTextTheme.headlineMedium?.copyWith(
            fontFamily: 'Be Vietnam Pro',
            fontSize: 24,
            height: 1.2,
            fontWeight: FontWeight.w600,
          ),
          titleLarge: baseTextTheme.titleLarge?.copyWith(
            fontFamily: 'Be Vietnam Pro',
            fontSize: 20,
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
          titleMedium: baseTextTheme.titleMedium?.copyWith(
            fontFamily: 'Be Vietnam Pro',
            fontSize: 17,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: baseTextTheme.bodyLarge?.copyWith(
            fontFamily: 'Be Vietnam Pro',
            fontSize: 16,
            height: 1.5,
          ),
          bodyMedium: baseTextTheme.bodyMedium?.copyWith(
            fontFamily: 'Be Vietnam Pro',
            fontSize: 14,
            height: 1.5,
          ),
          labelLarge: baseTextTheme.labelLarge?.copyWith(
            fontFamily: 'Be Vietnam Pro',
            fontSize: 14,
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
          labelMedium: baseTextTheme.labelMedium?.copyWith(
            fontFamily: 'Be Vietnam Pro',
            fontSize: 12,
            height: 1.3,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.12,
          ),
        )
        .apply(bodyColor: onSurface, displayColor: onSurface);

    final roundedRectangle = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark ? _darkBackground : _lightBackground,
      fontFamily: 'Be Vietnam Pro',
      textTheme: textTheme,
      visualDensity: VisualDensity.standard,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: isDark ? _darkBackground : _lightBackground,
        foregroundColor: onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
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
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: focusBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _error),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 1),
    );
  }
}
