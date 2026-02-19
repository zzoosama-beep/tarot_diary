// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // =========================================================
  // BASE
  // =========================================================
  static const Color bgSolid = Color(0xFF2E255A);
  static const Color bgColor = Color(0xFF564389);
  static const Color panelFill = Color(0xFF332B57);

  // =========================================================
  // BRAND ACCENT
  // =========================================================
  static const Color accent = Color(0xFF8F79FF);
  static const Color accentDeep = Color(0xFF6F5DE8);
  static const Color gold = Color(0xFFD4AF37);

  // =========================================================
  // TEXT
  // =========================================================
  static const Color tPrimary = Color(0xFFF3EDE0);
  static const Color tSecondary = Color(0xFFCBBFAE);
  static const Color tMuted = Color(0xFF9C90A8);

  // 🔥 기본 헤더 잉크 (약간 쿨톤)
  static const Color headerInk = Color(0xFFCEBDF8);

  // 🔥 홈 전용 따뜻한 잉크 (이번 디자인 핵심)
  static const Color homeInkWarm = Color(0xFFE7DDFB);
  static const Color homeInkWarmDim = Color(0xFFD6C9F5);

  static const Color sundayInk = Color(0xFFFF8A8A);
  static const Color saturdayInk = Color(0xFF8FB2FF);

  // =========================================================
  // CALENDAR ONLY (복구)
  // =========================================================
  static const Color calInk = Color(0xFFB8B2C8);
  static const Color calMuted = Color(0xFF6E6786);
  static const Color calLine = Color(0xFF4A4363);
  static const Color calSun = Color(0xFFC9A0A8);
  static const Color calSat = Color(0xFF9DB3D6);

  // =========================================================
  // EFFECT / BORDER
  // =========================================================
  static Color get inkSplash => accent.withOpacity(0.14);
  static Color get inkHighlight => accent.withOpacity(0.08);

  static Color get panelBorder => headerInk.withOpacity(0.14);
  static Color get panelBorderSoft => headerInk.withOpacity(0.10);

  static Color get glassBg => Colors.white.withOpacity(0.05);
  static Color get calendarBg => Colors.white.withOpacity(0.035);
  static Color get diaryFieldBg => Colors.white.withOpacity(0.06);

  // =========================================================
  // HOME PANEL TONE
  // =========================================================
  static const Color homePanelA = Color(0xFF6E5AB5);
  static const Color homePanelB = Color(0xFF4F3D86);
  static const Color homeCream = Color(0xFFFFF2E6);

  // =========================================================
  // RADIUS
  // =========================================================
  static const double radius = 18.0;
  static const double innerRadius = 14.0;

  // =========================================================
  // HOME TYPO (따뜻하게)
  // =========================================================
  static TextStyle homeTodayLabel({double opacity = 0.80}) =>
      GoogleFonts.notoSansKr(
        fontSize: 12.0,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.2,
        color: homeInkWarm.withOpacity(opacity),
        height: 1.0,
        shadows: [
          Shadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      );

  static TextStyle get homeMenuLabel => GoogleFonts.gowunDodum(
    fontSize: 14.5,
    fontWeight: FontWeight.w800,
    color: homeInkWarm.withOpacity(0.94),
    height: 1.2,
    shadows: [
      Shadow(
        color: Colors.black.withOpacity(0.14),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );

  // =========================================================
  // COMMON TYPO
  // =========================================================
  static TextStyle get title => GoogleFonts.gowunDodum(
    color: homeInkWarm,
    fontSize: 17,
    fontWeight: FontWeight.w900,
    height: 1.0,
  );

  static TextStyle get month => GoogleFonts.gowunDodum(
    color: accent.withOpacity(0.85),
    fontSize: 13.2,
    fontWeight: FontWeight.w800,
    height: 1.0,
  );

  static TextStyle get body => GoogleFonts.gowunDodum(
    color: tPrimary.withOpacity(0.88),
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.55,
  );

  static TextStyle get uiSmallLabel => GoogleFonts.gowunDodum(
    fontSize: 12.5,
    fontWeight: FontWeight.w800,
    color: tPrimary.withOpacity(0.82),
    height: 1.0,
  );

  static TextStyle tabLabel({required bool selected, required bool enabled}) {
    return GoogleFonts.gowunDodum(
      color: enabled
          ? (selected
          ? tPrimary.withOpacity(0.88)
          : tPrimary.withOpacity(0.60))
          : tPrimary.withOpacity(0.42),
      fontSize: 12.6,
      fontWeight: FontWeight.w900,
      height: 1.0,
      letterSpacing: selected ? 0.2 : 0.0,
    );
  }

  static TextStyle get diaryText => GoogleFonts.gowunDodum(
    color: const Color(0xFFF1E6C8).withOpacity(0.88),
    fontSize: 13.2,
    height: 1.6,
    fontWeight: FontWeight.w600,
  );

  static TextStyle get hint => GoogleFonts.gowunDodum(
    color: tMuted.withOpacity(0.90),
    fontSize: 12.4,
    fontWeight: FontWeight.w700,
    height: 1.5,
  );

  static const Color editBlue = Color(0xFF8FA2C8);
}

// =========================================================
// GLASS PANEL DECORATION
// =========================================================
BoxDecoration glassPanelDecoration({
  double radius = AppTheme.radius,
  Color? fill,
  Color? border,
  bool shadow = true,
}) {
  Color a(Color c, double o) => c.withAlpha((o * 255).round());

  final panelFill = fill ?? AppTheme.glassBg;
  final panelBorder = border ?? AppTheme.panelBorder;

  return BoxDecoration(
    color: panelFill,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: panelBorder),
    boxShadow: shadow
        ? [
      BoxShadow(
        color: a(Colors.black, 0.22),
        blurRadius: 18,
        offset: const Offset(0, 10),
      ),
    ]
        : null,
  );
}
