import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../ads/rewarded_gate.dart';
import '../error/app_error_dialog.dart';
import '../error/app_error_handler.dart';

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
/// ------------------------------------------------------------
/// 2) ✅ 캘린더 하단 "일기 수정 / 일기 삭제" 전용 Pill 버튼 (스샷 스타일)
/// - 배경: 라벤더 톤 (고정)
/// - 보더: 골드 톤 다운
/// - 텍스트: 골드 톤 다운
/// - 아이콘: 기존 포인트 컬러 그대로(수정=블루, 삭제=버건디)
/// ------------------------------------------------------------
// lib/ui/app_buttons.dart

class AppDiaryPillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  /// 아이콘만 포인트 컬러로 바꿀 때 사용 (삭제 버튼)
  final bool danger;

  /// 크기
  final double height;
  final double fontSize;

  const AppDiaryPillButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed, // required 제거하여 null 허용 (비활성화 상태 대응)
    this.danger = false,
    this.height = 44,
    this.fontSize = 14.0,
  });

  @override
  Widget build(BuildContext context) {
    final can = onPressed != null;
    final gold = AppTheme.gold;

    // ✅ 배경: 깊고 차분한 라벤더 톤
    const Color lavenderBg = Color(0xFF4A446E);

    // ✅ 글자색: 배경과 어우러지는 뮤트 퍼플
    const Color lavenderText = Color(0xFF9F86C0);

    // ✅ 아이콘 포인트 컬러 (기존 유지)
    final Color editBlue = AppTheme.editBlue;
    const Color dangerInk = Color(0xFFB45A64);
    final iconColor = danger ? dangerInk : editBlue;

    // 상태에 따른 색상 계산
    final textC = _a(lavenderText, can ? 0.95 : 0.45);
    final borderC = _a(gold, can ? 0.22 : 0.12);
    final bgC = _a(lavenderBg, can ? 0.92 : 0.55);

    return SizedBox(
      height: height,
      child: Material(
        color: Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const StadiumBorder(),
          splashColor: _a(gold, 0.10),
          highlightColor: _a(gold, 0.06),
          child: Ink(
            decoration: BoxDecoration(
              color: bgC,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: borderC, width: 1),
              // ✅ 음영 효과 추가 (입체감 강화)
              boxShadow: can
                  ? [
                // 1) 바닥 그림자(멀리, 넓게) - 너무 과하지 않게
                BoxShadow(
                  color: _a(Colors.black, 0.30),
                  blurRadius: 16,
                  spreadRadius: 0.5,
                  offset: const Offset(0, 8),
                ),

                // 2) 바로 밑에 붙는 그림자(가까이, 선명) - "떠있음" 핵심
                BoxShadow(
                  color: _a(Colors.black, 0.22),
                  blurRadius: 6,
                  spreadRadius: 0.0,
                  offset: const Offset(0, 3),
                ),

                // 3) 윗면 하이라이트(빛 받는 느낌) - 입체감 체감 1등 공신
                BoxShadow(
                  color: _a(Colors.white, 0.10),
                  blurRadius: 6,
                  spreadRadius: -2.0, // 안쪽으로 살짝 말리게
                  offset: const Offset(0, -2),
                ),
              ]
                  : null,

            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: danger ? 22 : 18,
                      color: _a(iconColor, can ? 0.95 : 0.45), // 아이콘 색 유지
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: GoogleFonts.gowunDodum(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                        letterSpacing: -0.2,
                        color: textC, // ✅ 뮤트 퍼플 글자색 적용
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppFloatAction {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed; // null이면 disabled
  final bool primary;            // true면 강조(저장 같은)
  final bool visible;            // false면 렌더 안함

  const AppFloatAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.primary = false,
    this.visible = true,
  });
}

/// ✅ 페이지 하단에 “떠있는” 액션바(저장/수정/삭제 등 공용)
/// - 키보드 올라오면 같이 위로 올라감
/// - visible=false 액션은 자동으로 숨김
class AppFloatingActionBar extends StatelessWidget {
  final List<AppFloatAction> actions;

  /// 바깥 여백(디자인/안전영역)
  final EdgeInsets margin;

  const AppFloatingActionBar({
    super.key,
    required this.actions,
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 12),
  });

  @override
  Widget build(BuildContext context) {
    final items = actions.where((a) => a.visible).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    // ✅ 키보드 올라오면 같이 위로
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: margin.copyWith(bottom: margin.bottom + safeBottom),
          child: _GlassFloatBar(
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  Expanded(child: _FloatBtn(a: items[i])),
                  if (i != items.length - 1) const SizedBox(width: 10),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassFloatBar extends StatelessWidget {
  final Widget child;
  const _GlassFloatBar({required this.child});

  @override
  Widget build(BuildContext context) {
    const r = 18.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(r),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: _a(AppTheme.panelFill, 0.52),
          borderRadius: BorderRadius.circular(r),
          border: Border.all(color: _a(AppTheme.gold, 0.16), width: 1),
          boxShadow: [
            BoxShadow(
              color: _a(Colors.black, 0.22),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _FloatBtn extends StatelessWidget {
  final AppFloatAction a;
  const _FloatBtn({required this.a});

  @override
  Widget build(BuildContext context) {
    final enabled = a.onPressed != null;

    final Color borderC = a.primary
        ? _a(AppTheme.gold, enabled ? 0.55 : 0.18)
        : _a(AppTheme.tSecondary, enabled ? 0.45 : 0.18);

    final Color bgC = a.primary
        ? _a(AppTheme.gold, enabled ? 0.16 : 0.06)
        : _a(Colors.white, enabled ? 0.03 : 0.015);

    final Color iconC = a.primary
        ? _a(AppTheme.gold, enabled ? 0.95 : 0.35)
        : _a(AppTheme.tSecondary, enabled ? 0.90 : 0.35);

    final Color textC = a.primary
        ? _a(AppTheme.tPrimary, enabled ? 0.90 : 0.35)
        : _a(AppTheme.tSecondary, enabled ? 0.90 : 0.35);

    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: a.onPressed,
        icon: Icon(a.icon, size: 16, color: iconC),
        label: Text(
          a.label,
          style: AppTheme.uiSmallLabel.copyWith(
            color: textC,
            fontSize: 13.2,
            fontWeight: FontWeight.w900,
            height: 1.0,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: bgC,
          side: BorderSide(color: borderC, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
        ),
      ),
    );
  }
}


// 저장버튼 (플로팅)
class SaveFloatingButton extends StatelessWidget {
  final VoidCallback onPressed; // ✅ 항상 탭 가능
  final String tooltip;
  final bool enabled; // ✅ UI만 dim 처리

  const SaveFloatingButton({
    super.key,
    required this.onPressed,
    this.tooltip = '저장하기',
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.55, // ✅ 저장 불가 상태면 흐리게
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.22),
                blurRadius: 7,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: FloatingActionButton.small(
            onPressed: onPressed, // ✅ 항상 눌림 → _trySave에서 토스트 가능

            backgroundColor: const Color(0xFF4A446E),
            foregroundColor: const Color(0xFFD4C0F2),

            elevation: 0,
            shape: const CircleBorder(side: BorderSide.none),

            child: const Icon(Icons.save_rounded, size: 20),
          ),
        ),
      ),
    );
  }
}

// 홈버튼 (플로팅)
// 홈버튼 (플로팅) - ✅ 저장버튼과 동일한 "동그란" 톤 + 음영 강화
class HomeFloatingButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String tooltip;

  const HomeFloatingButton({
    super.key,
    required this.onPressed,
    this.tooltip = '홈으로',
  });

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF4A446E);
    const fg = Color(0xFFD4C0F2);

    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _a(Colors.black, 0.30),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: _a(Colors.black, 0.20),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
            BoxShadow(
              color: _a(Colors.white, 0.10),
              blurRadius: 6,
              spreadRadius: -2.0,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: ClipOval(
            child: InkWell(
              onTap: onPressed,
              splashColor: _a(fg, 0.18),
              highlightColor: _a(fg, 0.10),
              child: Ink(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: bg,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.home_rounded, size: 20, color: fg),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}



// ✅ 홈으로 이동하는 공용 액션
AppFloatAction homeAction(BuildContext context) {
  return AppFloatAction(
    label: '홈',
    icon: Icons.home_rounded,
    onPressed: () {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
    },
    primary: false,
    visible: true,
  );
}


/// ✅ FAB 2개 정렬용 슬롯: 두 버튼의 "정렬 기준 박스"를 통일
class FabSlot extends StatelessWidget {
  final Widget child;
  final double size;

  const FabSlot({
    super.key,
    required this.child,
    this.size = 52, // 필요하면 48~56 사이로 조절
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Align(
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}


/// ------------------------------------------------------------
/// ✅ 공용 "필터 칩" Pill 버튼 (리스트/도감/필터 어디서든 재사용)
/// - list_arcana.dart의 _FilterChipPill을 공용으로 승격
/// ------------------------------------------------------------
class AppFilterChipPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  /// 옵션(필요할 때 조절)
  final EdgeInsets padding;
  final double fontSize;
  final double radius;

  const AppFilterChipPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.fontSize = 12.8,
    this.radius = 999,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    final bg = selected
        ? _a(AppTheme.gold, 0.12) // 선택: 살짝 골드 배경
        : _a(AppTheme.panelFill, 0.18); // 비선택: 패널 톤

    final bd = selected
        ? _a(AppTheme.gold, 0.40) // 선택: 골드 보더
        : _a(AppTheme.gold, 0.14); // 비선택: 약한 골드 보더

    final fg = selected
        ? _a(AppTheme.gold, enabled ? 0.92 : 0.40) // 선택: 골드 글씨
        : _a(AppTheme.tSecondary, enabled ? 0.88 : 0.40); // 비선택: 서브톤 글씨

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        splashColor: _a(AppTheme.gold, 0.12),
        highlightColor: _a(AppTheme.gold, 0.06),
        child: Ink(
          padding: padding,
          decoration: BoxDecoration(
            color: enabled ? bg : _a(bg, 0.55),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: bd, width: 1),
          ),
          child: Text(
            label,
            style: GoogleFonts.gowunDodum(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              color: fg,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}

/// 달냥에게 물어보기 버튼 (공용)
class DallyangAskPill extends StatelessWidget {
  final bool enabled;
  final String confirmMessage;

  /// ✅ 광고 보상 획득 후 실행할 작업(서버 credit + ask 등)
  /// - 여기서 예외 던져도 됨 (UI에서 catch)
  final Future<void> Function() onReward;

  /// ✅ 광고 시작 전에 사전 체크(남은 횟수 등)
  /// - 성공: return
  /// - 실패: DalnyangKnownException / DalnyangUnknownException throw
  final Future<void> Function()? precheckBeforeAd;

  /// enabled=false일 때 눌렀을 때 처리(토스트 등) -> UI에서만
  final VoidCallback? onDisabledTap;

  /// 광고가 아직 준비 안 됐을 때 처리(토스트 등) -> UI에서만
  final VoidCallback? onNotReady;

  /// 광고를 끝까지 안 봐서 보상 못 받은 경우 -> UI에서만
  final VoidCallback? onRewardNotEarned;

  /// 광고 표시 자체 실패 -> UI에서만
  final void Function(Object error)? onShowFailed;

  const DallyangAskPill({
    super.key,
    required this.enabled,
    required this.confirmMessage,
    required this.onReward,
    this.precheckBeforeAd,
    this.onDisabledTap,
    this.onNotReady,
    this.onRewardNotEarned,
    this.onShowFailed,
  });

  @override
  Widget build(BuildContext context) {
    final fg = enabled
        ? _a(AppTheme.tPrimary, 0.90)
        : _a(AppTheme.tSecondary, 0.55);
    final bg = _a(AppTheme.gold, enabled ? 0.12 : 0.06);
    final bd = _a(AppTheme.gold, enabled ? 0.35 : 0.18);

    Future<void> _runAdFlow() async {
      if (!enabled) {
        onDisabledTap?.call();
        return;
      }

      try {
        // ✅ 0) 광고 보기 전 사전 체크 (남은 횟수 등)
        if (precheckBeforeAd != null) {
          await precheckBeforeAd!.call(); // 여기서 throw → 아래 catch로 잡힘
        }

        // ✅ 1) 미리 로드(있으면 좋고 없어도 OK)
        RewardedGate.preload(context);

        // ✅ 2) 광고 표시 + 보상 처리
        await RewardedGate.showAndReward(
          context,
          confirmTitle: '달냥이의 해석 힌트',
          confirmMessage: confirmMessage,
          onRewardEarned: () async {
            await onReward(); // onReward 내부에서도 throw 가능 (여긴 이미 write_diary에서 catch 중이지만 이중 안전)
          },
          onNotReady: () => onNotReady?.call(),
          onRewardNotEarned: () => onRewardNotEarned?.call(),
          onShowFailed: (e) => onShowFailed?.call(e),
        );
      } catch (e) {
        // ✅ 여기서 “횟수 제한(known)”도 다이얼로그로 뜸
        await handleDalnyangError(context, e);
      }
    }


    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async => await _runAdFlow(),
        borderRadius: BorderRadius.circular(999),
        splashColor: _a(AppTheme.gold, 0.12),
        highlightColor: _a(AppTheme.gold, 0.06),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: bd, width: 0.9),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pets_rounded, size: 14, color: fg),
              const SizedBox(width: 6),
              Text(
                '달냥이에게 물어보기',
                style: GoogleFonts.gowunDodum(
                  fontSize: 11.8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                  height: 1.0,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}