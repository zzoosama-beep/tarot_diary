// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ✅ withOpacity 경고 회피용
  static Color a(Color c, double o) => c.withAlpha((o * 255).round());

  // =========================================================
  // BASE (배경은 "기존 보라" 유지)
  // =========================================================
  static const Color bgSolid = Color(0xFF2E255A);
  static const Color bgColor = Color(0xFF564389);

  // (기존 패널 톤 - write_diary 등 다른 화면이 쓰고 있다면 유지)
  static const Color panelFill = Color(0xFF332B57);

  // ✅ 캘린더 전용: 배경은 그대로, "박스만" 라벤더 톤으로
  // 너무 하얗지 않고, 회색도 아닌 라벤더(감성 + 캐주얼)
  static const Color calPanelFill = Color(0xFFB8AFDA);   // 메인 박스
  static const Color calInnerBg = Color(0xFFC7BFE6);     // 요일/탭/내부 바탕
  static const Color calFieldBg = Color(0xFFD7D0F0);     // 텍스트 영역(조금 더 밝게)

  // =========================================================
  // BRAND ACCENT
  // =========================================================
  static const Color accent = Color(0xFF8F79FF);
  static const Color accentDeep = Color(0xFF6F5DE8);

  // (gold는 이번 캘린더에서는 안씀. 남겨두기)
  static const Color gold = Color(0xFFD4AF37);

  // =========================================================
  // TEXT (✅ 칙칙함 해결: 따뜻한 크림/아이보리로 대비 올림)
  // =========================================================
  static const Color tPrimary = Color(0xFFF6F0E6);   // 메인 텍스트(따뜻한 크림)
  static const Color tSecondary = Color(0xFFE9DFD3);
  static const Color tMuted = Color(0xFFE0D6CC);

  static TextStyle tsTitle() {
    return title.copyWith(
      color: a(homeInkWarm, 0.96),
    );
  }

  // 헤더/라인용 잉크(보라 위에서 너무 회색되지 않게)
  static const Color headerInk = Color(0xFFEAE3FF);

  // 홈 전용 따뜻한 잉크(기존 유지)
  static const Color homeInkWarm = Color(0xFFE7DDFB);
  static const Color homeInkWarmDim = Color(0xFFD6C9F5);

  static const Color sundayInk = Color(0xFFFF8A8A);
  static const Color saturdayInk = Color(0xFF8FB2FF);

  // =========================================================
  // CALENDAR ONLY (✅ 숫자/라인 대비)
  // =========================================================
  static const Color calInk = Color(0xFFF2ECFF);   // 평일 숫자(또렷)
  static const Color calMuted = Color(0xFFD0C7EA); // 전달/다음달 숫자
  static const Color calLine = Color(0xFF9B90C6);  // 구분선(너무 흐리지 않게)
  static const Color calSun = Color(0xFFE4A3A8);
  static const Color calSat = Color(0xFFA8BCEB);

  // =========================================================
  // EFFECT / BORDER
  // =========================================================
  static Color get inkSplash => a(accent, 0.14);
  static Color get inkHighlight => a(accent, 0.08);

  // 캘린더 박스 테두리(너무 흐리면 탁해 보임 → 살짝 또렷하게)
  static Color get panelBorder => a(headerInk, 0.18);
  static Color get panelBorderSoft => a(headerInk, 0.12);

  // 기존 글래스용(다른 화면에서 쓰면 유지)
  static Color get glassBg => a(Colors.white, 0.05);
  static Color get calendarBg => a(Colors.white, 0.035);
  static Color get diaryFieldBg => a(Colors.white, 0.06);

  // =========================================================
  // HOME PANEL TONE (기존 유지)
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
  // HOME TYPO (기존 유지)
  // =========================================================
  static TextStyle homeTodayLabel({double opacity = 0.80}) =>
      GoogleFonts.notoSansKr(
        fontSize: 12.0,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.2,
        color: a(homeInkWarm, opacity),
        height: 1.0,
        shadows: [
          Shadow(
            color: a(Colors.black, 0.18),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      );

  static TextStyle get homeMenuLabel => GoogleFonts.gowunDodum(
    fontSize: 14.5,
    fontWeight: FontWeight.w800,
    color: a(homeInkWarm, 0.94),
    height: 1.2,
    shadows: [
      Shadow(
        color: a(Colors.black, 0.14),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );

  // =========================================================
  // COMMON TYPO
  // =========================================================
  static TextStyle get title => GoogleFonts.gowunDodum(
    color: tPrimary,
    fontSize: 17,
    fontWeight: FontWeight.w900,
    height: 1.0,
  );

  static TextStyle get month => GoogleFonts.gowunDodum(
    color: a(tPrimary, 0.90),
    fontSize: 13.2,
    fontWeight: FontWeight.w800,
    height: 1.0,
  );

  static TextStyle get body => GoogleFonts.gowunDodum(
    color: a(tPrimary, 0.88),
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.55,
  );

  static TextStyle get uiSmallLabel => GoogleFonts.gowunDodum(
    fontSize: 12.5,
    fontWeight: FontWeight.w800,
    color: a(tPrimary, 0.86),
    height: 1.0,
  );

  static TextStyle tabLabel({required bool selected, required bool enabled}) {
    return GoogleFonts.gowunDodum(
      color: enabled
          ? (selected ? a(tPrimary, 0.92) : a(tPrimary, 0.66))
          : a(tPrimary, 0.44),
      fontSize: 12.6,
      fontWeight: FontWeight.w900,
      height: 1.0,
      letterSpacing: selected ? 0.2 : 0.0,
    );
  }

  static TextStyle get diaryText => GoogleFonts.gowunDodum(
    color: a(tPrimary, 0.90),
    fontSize: 13.2,
    height: 1.6,
    fontWeight: FontWeight.w600,
  );

  static TextStyle get hint => GoogleFonts.gowunDodum(
    color: a(tMuted, 0.92),
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
  final panelFill = fill ?? AppTheme.glassBg;
  final panelBorder = border ?? AppTheme.panelBorder;

  return BoxDecoration(
    color: panelFill,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: panelBorder),
    boxShadow: shadow
        ? [
      BoxShadow(
        color: AppTheme.a(Colors.black, 0.22),
        blurRadius: 18,
        offset: const Offset(0, 10),
      ),
    ]
        : null,
  );
}


