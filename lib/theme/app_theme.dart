// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 앱 전체에서 공통으로 쓰는 컬러/폰트/보더/버튼 스타일 모음
/// - 캘린더/리스트/쓰기 페이지 모두 여기서 가져다 씀
/// - "값"만 관리하고, UI 로직은 각 페이지에 둔다
class AppTheme {
  AppTheme._();

  // =========================================================
  // ======================= BASE COLOR ======================
  // =========================================================
  /// 앱 배경(전체)
  static const Color bgSolid = Color(0xFF2E255A);

  /// 카드/패널 채움(내부 딥톤)
  static const Color panelFill = Color(0xFF332B57);

  /// 테마 포인트(골드)
  static const Color gold = Color(0xFFD4AF37);

  // =========================================================
  // ======================= TEXT COLOR ======================
  // =========================================================
  /// 기본 텍스트(크림/화이트 계열)
  static const Color tPrimary = Color(0xFFF3EDE0);

  /// 보조 텍스트(웜톤 크림)
  static const Color tSecondary = Color(0xFFCBBFAE);

  /// 약한 텍스트(뮤트)
  static const Color tMuted = Color(0xFF9C90A8);

  /// 헤더 타이틀/아이콘 잉크
  static const Color headerInk = Color(0xFFDAD6CC);

  /// 요일(일/토) 포인트
  static const Color sundayInk = Color(0xFFFF8A8A);
  static const Color saturdayInk = Color(0xFF8FB2FF);

  // =========================================================
  // ====================== CALENDAR ONLY ====================
  // =========================================================
  /// 기본 날짜 텍스트 (회보라)
  static const Color calInk = Color(0xFFB8B2C8);

  /// 다른 달/비활성
  static const Color calMuted = Color(0xFF6E6786);

  /// 캘린더 라인
  static const Color calLine = Color(0xFF4A4363);

  /// 캘린더 일/토(톤다운)
  static const Color calSun = Color(0xFFC9A0A8);
  static const Color calSat = Color(0xFF9DB3D6);

  // =========================================================
  // ===================== EFFECT / BORDER ===================
  // =========================================================
  /// 클릭 스플래시/하이라이트
  static Color get inkSplash => gold.withOpacity(0.14);
  static Color get inkHighlight => gold.withOpacity(0.08);

  /// 유리 패널 보더
  static Color get panelBorder => gold.withOpacity(0.22);
  static Color get panelBorderSoft => gold.withOpacity(0.13);

  /// 기본 유리 배경(기본 카드용)
  static Color get glassBg => Colors.white.withOpacity(0.05);

  /// 캘린더 카드 안쪽 깔림(레이어감)
  static Color get calendarBg => Colors.white.withOpacity(0.035);

  /// 텍스트 박스(일기 내용 영역) 배경
  static Color get diaryFieldBg => Colors.white.withOpacity(0.06);

  // =========================================================
  // ========================= RADIUS =========================
  // =========================================================
  static const double radius = 18.0;
  static const double innerRadius = 14.0;

  // =========================================================
  // ========================== FONT ==========================
  // =========================================================
  /// 상단 타이틀
  static TextStyle get title => GoogleFonts.gowunDodum(
    color: headerInk,
    fontSize: 17,
    fontWeight: FontWeight.w900,
    height: 1.0,
  );

  /// 월 이동 라벨(골드 톤)
  static TextStyle get month => GoogleFonts.gowunDodum(
    color: gold.withOpacity(0.78),
    fontSize: 13.2,
    fontWeight: FontWeight.w800,
    height: 1.0,
  );

  /// 일반 본문
  static TextStyle get body => GoogleFonts.gowunDodum(
    color: tPrimary.withOpacity(0.88),
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.55,
  );

  /// 카드 접기/펼치기 같은 작은 UI 라벨
  static TextStyle get uiSmallLabel => GoogleFonts.gowunDodum(
    fontSize: 12.5,
    fontWeight: FontWeight.w800,
    color: tPrimary.withOpacity(0.82),
    height: 1.0,
  );

  /// 탭(나의 예상 / 실제 하루)
  static TextStyle tabLabel({required bool selected, required bool enabled}) {
    return GoogleFonts.gowunDodum(
      color: enabled
          ? (selected ? tPrimary.withOpacity(0.88) : tPrimary.withOpacity(0.60))
          : tPrimary.withOpacity(0.42),
      fontSize: 12.6,
      fontWeight: FontWeight.w900,
      height: 1.0,
      letterSpacing: selected ? 0.2 : 0.0,
    );
  }

  /// 일기 본문(너가 선택한 크림톤)
  static TextStyle get diaryText => GoogleFonts.gowunDodum(
    color: const Color(0xFFF1E6C8).withOpacity(0.88),
    fontSize: 13.2,
    height: 1.6,
    fontWeight: FontWeight.w600,
  );

  /// 힌트 텍스트(내용 없음)
  static TextStyle get hint => GoogleFonts.gowunDodum(
    color: tMuted.withOpacity(0.90),
    fontSize: 12.4,
    fontWeight: FontWeight.w700,
    height: 1.5,
  );

  /// 일기 수정 아이콘 (연필)
  static const Color editBlue = Color(0xFF8FA2C8);
}
