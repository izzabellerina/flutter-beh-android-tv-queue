import 'package:flutter/material.dart';

/// สีเฉพาะของแอป TV ที่ ColorScheme ไม่มี — อ่านผ่าน `TvColors.of(context)`
@immutable
class TvColors extends ThemeExtension<TvColors> {
  /// กรอบของช่อง/ปุ่มที่รีโมทเลือกอยู่ ต้องเห็นชัดจากระยะ 2–3 เมตร
  final Color focusRing;

  /// พื้นหลังแผงด้านซ้าย (โลโก้ + นาฬิกา)
  final Color brandPanel;
  final Color onBrandPanel;
  final Color mutedText;

  const TvColors({
    required this.focusRing,
    required this.brandPanel,
    required this.onBrandPanel,
    required this.mutedText,
  });

  static TvColors of(BuildContext context) =>
      Theme.of(context).extension<TvColors>()!;

  @override
  TvColors copyWith({
    Color? focusRing,
    Color? brandPanel,
    Color? onBrandPanel,
    Color? mutedText,
  }) {
    return TvColors(
      focusRing: focusRing ?? this.focusRing,
      brandPanel: brandPanel ?? this.brandPanel,
      onBrandPanel: onBrandPanel ?? this.onBrandPanel,
      mutedText: mutedText ?? this.mutedText,
    );
  }

  @override
  TvColors lerp(TvColors? other, double t) {
    if (other == null) return this;
    return TvColors(
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
      brandPanel: Color.lerp(brandPanel, other.brandPanel, t)!,
      onBrandPanel: Color.lerp(onBrandPanel, other.onBrandPanel, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
    );
  }
}

class AppTheme {
  // ══════════════════════════════════════════════════════════════════════════
  // BRAND (จาก flutter_beh_ic_register + สีโลโก้)
  // ══════════════════════════════════════════════════════════════════════════

  static const Color primaryThemeApp = Color(0xff1d5898);
  static const Color brandTeal = Color(0xff2ba8b5);

  static const String fontFamily = 'Athiti';

  // ══════════════════════════════════════════════════════════════════════════
  // TV SIZING — จอ TV 1080p = 960×540 dp, ดูจากระยะ 2–3 เมตร
  // ══════════════════════════════════════════════════════════════════════════

  /// Overscan safe area: TV บางรุ่นตัดขอบจอ ~5%
  static const EdgeInsets overscanPadding = EdgeInsets.symmetric(
    horizontal: 48,
    vertical: 27,
  );

  static const double fieldHeight = 52;
  static const double buttonHeight = 56;
  static const double radius = 12;
  static const double focusRingWidth = 3;

  // ══════════════════════════════════════════════════════════════════════════
  // THEMES
  // ══════════════════════════════════════════════════════════════════════════

  static ThemeData get light => _build(
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: primaryThemeApp,
      onPrimary: Colors.white,
      secondary: brandTeal,
      surface: Colors.white,
      onSurface: Color(0xff1e2a3a),
      surfaceContainerHighest: Color(0xffeef2f7),
      outline: Color(0xffc9d3de),
      error: Color(0xffc62828),
    ),
    scaffold: const Color(0xffe9eef4),
    tvColors: const TvColors(
      focusRing: primaryThemeApp,
      brandPanel: primaryThemeApp,
      onBrandPanel: Colors.white,
      mutedText: Color(0xff5b6b7f),
    ),
  );

  static ThemeData get dark => _build(
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xff3d82cc),
      onPrimary: Colors.white,
      secondary: brandTeal,
      surface: Color(0xff142133),
      onSurface: Color(0xffe8eef5),
      surfaceContainerHighest: Color(0xff1c2c42),
      outline: Color(0xff2f435c),
      error: Color(0xffff8a80),
    ),
    scaffold: const Color(0xff0b1420),
    tvColors: const TvColors(
      focusRing: Color(0xff7fd8e0),
      brandPanel: Color(0xff0f1b2b),
      onBrandPanel: Color(0xffe8eef5),
      mutedText: Color(0xff93a4b8),
    ),
  );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme colorScheme,
    required Color scaffold,
    required TvColors tvColors,
  }) {
    return ThemeData(
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffold,
      fontFamily: fontFamily,
      extensions: [tvColors],
      // กรอบ focus วาดเองด้วย TvFocusFrame — ปิด highlight สีเทาของ Material
      focusColor: Colors.transparent,
      textTheme: const TextTheme(
        displaySmall: TextStyle(fontSize: 52, fontWeight: FontWeight.w600),
        headlineMedium: TextStyle(fontSize: 34, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(fontSize: 20),
        bodyMedium: TextStyle(fontSize: 18),
        labelLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
      ),
    );
  }
}
