import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

class AromaticTheme {
  AromaticTheme._();

  static const double spaceXS = 4;
  static const double spaceSM = 8;
  static const double spaceMD = 16;
  static const double spaceLG = 24;
  static const double spaceXL = 32;
  static const double space2XL = 48;
  static const double radiusSM = 6;
  static const double radiusMD = 10;
  static const double radiusLG = 16;
  static const double contentMaxWidth = 680;
  static const double inputMaxWidth = 600;

  static const Color pearlWhite = Color(0xFFFCF9F5);
  static const Color pearlLavender = Color(0xFFF3EEFA);

  static const Color lavenderLight = Color(0xFFD4C8EC);
  static const Color lavenderMid = Color(0xFFB8A8DC);
  static const Color lavenderDeep = Color(0xFF9A88C8);

  static const Color darkBase = Color(0xFF0B0714);
  static const Color darkSurface = Color(0xFF171125);
  static const Color darkOverlay = Color(0xFF1F1830);

  static const Color success = Color(0xFF7ECB9A);
  static const Color warning = Color(0xFFE8C97A);
  static const Color error = Color(0xFFE07A7A);

  static const LinearGradient bgGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xCC0F0A1C), Color(0xCC1A1030),
      Color(0xCC120C22), Color(0xCC0D0818),
    ],
    stops: [0.0, 0.35, 0.7, 1.0],
  );

  /// 浅色：冷珠光紫，无粉无米
  static const LinearGradient bgGradientLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xE0F0ECF8),
      Color(0xE0E8E2F4),
      Color(0xE0EDE6F8),
      Color(0xE0E2DAF2),
    ],
    stops: [0.0, 0.35, 0.7, 1.0],
  );

  static const LinearGradient pearlShimmer = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE8DCF8), Color(0xFFFDF5F0), Color(0xFFE0D4F4)],
  );

  static TextStyle gradientTextStyle({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w700,
    double letterSpacing = 0,
    double height = 1.3,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      foreground: Paint()
        ..shader = pearlShimmer.createShader(
          const ui.Rect.fromLTWH(0, 0, 300, 60),
        ),
    );
  }

  static AromaticColors of(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light
        ? AromaticColors.light
        : AromaticColors.dark;
  }

  static ThemeData get darkTheme => _buildTheme(Brightness.dark);
  static ThemeData get lightTheme => _buildTheme(Brightness.light);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final c = isDark ? AromaticColors.dark : AromaticColors.light;

    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: c.accent,
        secondary: c.accentSoft,
        surface: c.surface,
        onPrimary: isDark ? darkBase : pearlWhite,
        onSecondary: isDark ? darkBase : pearlWhite,
        onSurface: c.textPrimary,
        error: error,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: c.textPrimary, fontSize: 18,
          fontWeight: FontWeight.w600, letterSpacing: 0,
        ),
        iconTheme: IconThemeData(color: c.textSecondary, size: 20),
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          color: c.textPrimary, fontSize: 28,
          fontWeight: FontWeight.w700, letterSpacing: 0, height: 1.3,
        ),
        headlineMedium: TextStyle(
          color: c.textPrimary, fontSize: 22,
          fontWeight: FontWeight.w600, letterSpacing: 0, height: 1.3,
        ),
        titleMedium: TextStyle(
          color: c.textPrimary, fontSize: 16,
          fontWeight: FontWeight.w600, letterSpacing: 0,
        ),
        bodyLarge: TextStyle(
          color: c.textPrimary, fontSize: 15,
          height: 1.6, letterSpacing: 0,
        ),
        bodyMedium: TextStyle(
          color: c.textSecondary, fontSize: 14,
          height: 1.5, letterSpacing: 0,
        ),
        labelSmall: TextStyle(
          color: c.textMuted, fontSize: 12, letterSpacing: 0,
        ),
      ),
      iconTheme: IconThemeData(color: c.textSecondary, size: 20),
      dividerColor: c.border,
    );
  }

  static BoxDecoration glassDecoration(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark
          ? darkSurface.withValues(alpha: 0.25)
          : pearlWhite.withValues(alpha: 0.40),
      borderRadius: BorderRadius.circular(radiusMD),
      border: Border.all(
        color: isDark
            ? lavenderLight.withValues(alpha: 0.10)
            : lavenderLight.withValues(alpha: 0.20),
        width: 1,
      ),
    );
  }

  static BoxDecoration glassGlowDecoration(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark
          ? darkOverlay.withValues(alpha: 0.40)
          : pearlWhite.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(radiusMD),
      border: Border.all(
        color: isDark
            ? lavenderMid.withValues(alpha: 0.18)
            : lavenderMid.withValues(alpha: 0.30),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: lavenderMid.withValues(alpha: isDark ? 0.06 : 0.10),
          blurRadius: 20, spreadRadius: 1,
        ),
      ],
    );
  }

  static BoxDecoration barDecoration(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark
          ? darkOverlay.withValues(alpha: 0.40)
          : Color(0xFFEDE6F8).withValues(alpha: 0.50),
      borderRadius: BorderRadius.circular(radiusLG),
      border: Border.all(
        color: isDark
            ? lavenderLight.withValues(alpha: 0.12)
            : lavenderMid.withValues(alpha: 0.25),
        width: 1,
      ),
    );
  }

  /// Returns a [MarkdownStyleSheet] matching the current Aromatic theme.
  static MarkdownStyleSheet markdownStyle(BuildContext context) {
    final c = AromaticTheme.of(context);
    return MarkdownStyleSheet(
      p: TextStyle(color: c.textPrimary, fontSize: 14, height: 1.5),
      h1: TextStyle(color: c.textPrimary, fontSize: 22, fontWeight: FontWeight.w700, height: 1.3),
      h2: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w600, height: 1.3),
      h3: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w600, height: 1.3),
      code: TextStyle(color: c.accent, fontSize: 13, fontFamily: 'monospace'),
      codeblockDecoration: BoxDecoration(
        color: c.surfaceOverlay.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AromaticTheme.radiusSM),
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(left: BorderSide(color: c.accent.withValues(alpha: 0.4), width: 3)),
      ),
      a: TextStyle(color: c.accent),
      strong: TextStyle(fontWeight: FontWeight.w700),
    );
  }
}

class AromaticColors {
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color accentSoft;
  final Color surface;
  final Color surfaceOverlay;
  final Color border;
  final Color inputFill;

  const AromaticColors({
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentSoft,
    required this.surface,
    required this.surfaceOverlay,
    required this.border,
    required this.inputFill,
  });

  static const AromaticColors dark = AromaticColors(
    textPrimary: Color(0xFFE4DCF0),
    textSecondary: Color(0xFFB4AAC4),
    textMuted: Color(0xFF787090),
    accent: Color(0xFFC4B5E8),
    accentSoft: Color(0xFFD4C8F0),
    surface: Color(0xFF171125),
    surfaceOverlay: Color(0xFF1F1830),
    border: Color(0xFF2A2240),
    inputFill: Color(0xFF1F1830),
  );

  /// 浅色文字再加深一级
  static const AromaticColors light = AromaticColors(
    textPrimary: Color(0xFF060210),
    textSecondary: Color(0xFF2E2048),
    textMuted: Color(0xFF4E3E68),
    accent: Color(0xFF9A80CC),
    accentSoft: Color(0xFFBAA8E0),
    surface: Color(0xFFFFFFFF),
    surfaceOverlay: Color(0xFFF0ECF8),
    border: Color(0xFFD8D0EC),
    inputFill: Color(0xFFEDE6F8),
  );
}
