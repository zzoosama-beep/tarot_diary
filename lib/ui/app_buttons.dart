import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// 공용 알파 헬퍼 (withOpacity 워닝 회피)
Color _a(Color c, double o) => c.withAlpha((o * 255).round());

/// ------------------------------------------------------------
/// 1) ✅ WriteDiary '저장하기'용 CTA 버튼 (그대로 유지)
/// ------------------------------------------------------------
class AppCtaButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  /// 메인 CTA인지(저장/수정)
  final bool emphasis;

  /// 위험 버튼(삭제)인지
  final bool danger;

  /// 버튼 높이
  final double height;

  /// 폰트 사이즈
  final double fontSize;

  /// 모서리 라운드
  final double radius;

  const AppCtaButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.emphasis = true,
    this.danger = false,
    this.height = 44,
    this.fontSize = 14.0,
    this.radius = 14.0,
  });

  @override
  Widget build(BuildContext context) {
    final can = onPressed != null;

    const baseBg = Color(0xFF2E2348);
    final gold = AppTheme.gold;
    const Color dangerInk = Color(0xFFB45A64);

    final fg = danger ? dangerInk : gold;

    final bgOpacity = emphasis
        ? (can ? 0.96 : 0.42)
        : (can ? 0.70 : 0.42);

    final borderOpacity = emphasis
        ? (can ? 0.48 : 0.18)
        : (can ? 0.32 : 0.18);

    final fgOpacity = can ? 0.92 : 0.42;

    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: _a(baseBg, bgOpacity),
          disabledBackgroundColor: _a(baseBg, 0.42),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: BorderSide(
              color: _a(gold, borderOpacity),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: _a(fg, fgOpacity)),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.gowunDodum(
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
                height: 1.0,
                color: _a(fg, fgOpacity),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ------------------------------------------------------------
/// 2) ✅ 캘린더 하단 "일기 수정 / 일기 삭제" 전용 Pill 버튼 (스샷 스타일)
/// - 텍스트는 골드
/// - 배경은 딥퍼플 + 안쪽 골드 필
/// - 아이콘만 포인트: 수정=블루, 삭제=X만 버건디
/// ------------------------------------------------------------
class AppDiaryPillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  /// 아이콘만 포인트 컬러로 바꿀 때 사용
  final bool danger;

  /// 크기
  final double height;
  final double fontSize;

  const AppDiaryPillButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.danger = false,
    this.height = 44,
    this.fontSize = 14.0,
  });

  @override
  Widget build(BuildContext context) {
    final can = onPressed != null;

    final gold = AppTheme.gold;
    const baseBg = Color(0xFF2E2348);

    final Color editBlue = AppTheme.editBlue;
    const Color dangerInk = Color(0xFFB45A64);
    final iconColor = danger ? dangerInk : editBlue;

    // ✅ 스샷 느낌: 딥퍼플 바탕 + 골드 보더 + (아주 은은한) 골드 필 단색
    final bg = _a(baseBg, can ? 0.90 : 0.55);
    final border = _a(gold, can ? 0.30 : 0.14);
    final fillGold = _a(gold, can ? 0.10 : 0.05); // ✅ 단색 필 (그라데이션 X)

    return SizedBox(
      height: height,
      child: Material(
        color: Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const StadiumBorder(),
          splashColor: _a(gold, 0.14),
          highlightColor: _a(gold, 0.08),
          child: Ink(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: border, width: 1),
              boxShadow: can
                  ? [
                BoxShadow(
                  color: _a(Colors.black, 0.22),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ]
                  : null,
            ),
            child: Stack(
              children: [
                // ✅ 단색 골드 필 (그라데이션 제거)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: fillGold,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),

                // ✅ 수직 정렬: Strut + height로 "말려 올라감" 방지
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          icon,
                          size: danger ? 22 : 18, // ✅ X만 커짐, 연필은 그대로
                          color: _a(iconColor, can ? 0.95 : 0.45),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          textHeightBehavior: const TextHeightBehavior(
                            applyHeightToFirstAscent: false,
                            applyHeightToLastDescent: false,
                          ),
                          strutStyle: StrutStyle(
                            fontSize: fontSize,
                            height: 1.15,
                            forceStrutHeight: true,
                          ),
                          style: GoogleFonts.gowunDodum(
                            fontSize: fontSize,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                            letterSpacing: -0.2,
                            color: _a(gold, can ? 0.90 : 0.40),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
