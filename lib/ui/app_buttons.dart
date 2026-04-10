import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../ads/rewarded_gate.dart';
import '../error/app_error_handler.dart';

/// 공용 알파 헬퍼 (withOpacity 워닝 회피)
Color _a(Color c, double o) => c.withAlpha((o * 255).round());

/// ------------------------------------------------------------
/// ✅ 반응형 공용 헬퍼
/// ------------------------------------------------------------
class _UiScale {
  final bool isTablet;
  final bool isSmallPhone;
  final bool isLandscape;
  final double width;
  final double height;
  final double textScale;

  const _UiScale({
    required this.isTablet,
    required this.isSmallPhone,
    required this.isLandscape,
    required this.width,
    required this.height,
    required this.textScale,
  });

  factory _UiScale.of(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final shortest = size.shortestSide;
    return _UiScale(
      isTablet: shortest >= 600,
      isSmallPhone: shortest < 360,
      isLandscape: size.width > size.height,
      width: size.width,
      height: size.height,
      textScale: MediaQuery.textScalerOf(context).scale(1.0),
    );
  }

  double font(double base) {
    double v = base;
    if (isTablet) {
      v += 1.2;
    } else if (isSmallPhone) {
      v -= 0.6;
    }
    if (isLandscape && height < 430) {
      v -= 0.4;
    }
    return math.max(10.0, v);
  }

  double icon(double base) {
    double v = base;
    if (isTablet) {
      v += 2;
    } else if (isSmallPhone) {
      v -= 1;
    }
    if (isLandscape && height < 430) {
      v -= 1;
    }
    return math.max(12.0, v);
  }

  double h(double base) {
    double v = base;
    if (isTablet) {
      v += 4;
    } else if (isSmallPhone) {
      v -= 2;
    }
    if (isLandscape && height < 430) {
      v -= 2;
    }
    return math.max(36.0, v);
  }

  EdgeInsets inset({
    required double h,
    required double v,
    double tabletH = 0,
    double tabletV = 0,
    double smallH = 0,
    double smallV = 0,
  }) {
    double hh = h;
    double vv = v;

    if (isTablet) {
      hh += tabletH;
      vv += tabletV;
    } else if (isSmallPhone) {
      hh += smallH;
      vv += smallV;
    }

    if (isLandscape && height < 430) {
      vv = math.max(4, vv - 2);
    }

    return EdgeInsets.symmetric(horizontal: hh, vertical: vv);
  }
}

/// ------------------------------------------------------------
/// 1) ✅ WriteDiary '저장하기'용 CTA 버튼
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
    final s = _UiScale.of(context);
    final can = onPressed != null;

    const baseBg = Color(0xFF2E2348);
    final gold = AppTheme.gold;
    const Color dangerInk = Color(0xFFB45A64);

    final fg = danger ? dangerInk : gold;

    final bgOpacity = emphasis ? (can ? 0.96 : 0.42) : (can ? 0.70 : 0.42);
    final borderOpacity = emphasis ? (can ? 0.48 : 0.18) : (can ? 0.32 : 0.18);
    final fgOpacity = can ? 0.92 : 0.42;

    final resolvedHeight = s.h(height);
    final resolvedFont = s.font(fontSize);
    final resolvedRadius = s.isTablet ? radius + 2 : radius;
    final resolvedIcon = s.icon(18);
    final resolvedPadding = s.inset(
      h: 14,
      v: 0,
      tabletH: 2,
      smallH: -2,
    );

    return SizedBox(
      width: double.infinity,
      height: resolvedHeight,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: _a(baseBg, bgOpacity),
          disabledBackgroundColor: _a(baseBg, 0.42),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(resolvedRadius),
            side: BorderSide(
              color: _a(gold, borderOpacity),
              width: 1,
            ),
          ),
          padding: resolvedPadding,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: resolvedIcon, color: _a(fg, fgOpacity)),
              SizedBox(width: s.isTablet ? 9 : 8),
              Text(
                label,
                style: GoogleFonts.gowunDodum(
                  fontSize: resolvedFont,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                  height: 1.0,
                  color: _a(fg, fgOpacity),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ------------------------------------------------------------
/// 2) ✅ 캘린더 하단 "일기 수정 / 일기 삭제" 전용 Pill 버튼
/// ------------------------------------------------------------
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
    this.onPressed,
    this.danger = false,
    this.height = 44,
    this.fontSize = 14.0,
  });

  @override
  Widget build(BuildContext context) {
    final s = _UiScale.of(context);
    final can = onPressed != null;
    final gold = AppTheme.gold;

    const Color lavenderBg = Color(0xFF4A446E);
    const Color lavenderText = Color(0xFF9F86C0);

    final Color editBlue = AppTheme.editBlue;
    const Color dangerInk = Color(0xFFB45A64);
    final iconColor = danger ? dangerInk : editBlue;

    final textC = _a(lavenderText, can ? 0.95 : 0.45);
    final borderC = _a(gold, can ? 0.22 : 0.12);
    final bgC = _a(lavenderBg, can ? 0.92 : 0.55);

    final resolvedHeight = s.h(height);
    final resolvedFont = s.font(fontSize);
    final resolvedIconSize = s.icon(danger ? 22 : 18);
    final horizontalPad = s.isTablet ? 18.0 : (s.isSmallPhone ? 12.0 : 16.0);

    return SizedBox(
      height: resolvedHeight,
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
              boxShadow: can
                  ? [
                BoxShadow(
                  color: _a(Colors.black, 0.30),
                  blurRadius: s.isTablet ? 18 : 16,
                  spreadRadius: 0.5,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: _a(Colors.black, 0.22),
                  blurRadius: 6,
                  spreadRadius: 0.0,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: _a(Colors.white, 0.10),
                  blurRadius: 6,
                  spreadRadius: -2.0,
                  offset: const Offset(0, -2),
                ),
              ]
                  : null,
            ),
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPad),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: resolvedIconSize,
                        color: _a(iconColor, can ? 0.95 : 0.45),
                      ),
                      SizedBox(width: s.isTablet ? 9 : 8),
                      Text(
                        label,
                        style: GoogleFonts.gowunDodum(
                          fontSize: resolvedFont,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                          letterSpacing: -0.2,
                          color: textC,
                        ),
                      ),
                    ],
                  ),
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
  final VoidCallback? onPressed;
  final bool primary;
  final bool visible;

  const AppFloatAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.primary = false,
    this.visible = true,
  });
}

/// ✅ 페이지 하단에 “떠있는” 액션바
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
    final s = _UiScale.of(context);
    final items = actions.where((a) => a.visible).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    final resolvedMargin = EdgeInsets.fromLTRB(
      s.isTablet ? 20 : 16,
      margin.top,
      s.isTablet ? 20 : 16,
      (s.isTablet ? 14 : 12) + safeBottom,
    );

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: resolvedMargin,
          child: _GlassFloatBar(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool tooNarrow =
                    constraints.maxWidth < (items.length * 120);

                if (tooNarrow && items.length >= 3) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < items.length; i++) ...[
                        _FloatBtn(a: items[i]),
                        if (i != items.length - 1)
                          SizedBox(height: s.isTablet ? 12 : 10),
                      ],
                    ],
                  );
                }

                return Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    for (int i = 0; i < items.length; i++) ...[
                      Expanded(child: _FloatBtn(a: items[i])),
                      if (i != items.length - 1)
                        SizedBox(width: s.isTablet ? 12 : 10),
                    ],
                  ],
                );
              },
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
    final s = _UiScale.of(context);
    final r = s.isTablet ? 20.0 : 18.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(r),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          s.isTablet ? 14 : 12,
          s.isTablet ? 12 : 10,
          s.isTablet ? 14 : 12,
          s.isTablet ? 12 : 10,
        ),
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
    final s = _UiScale.of(context);
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

    final btnHeight = s.h(44);
    final iconSize = s.icon(16);
    final fontSize = s.font(13.2);
    final radius = s.isTablet ? 16.0 : 14.0;
    final horizontalPad = s.isTablet ? 14.0 : (s.isSmallPhone ? 10.0 : 12.0);

    return SizedBox(
      height: btnHeight,
      child: OutlinedButton.icon(
        onPressed: a.onPressed,
        icon: Icon(a.icon, size: iconSize, color: iconC),
        label: Flexible(
          child: Text(
            a.label,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.uiSmallLabel.copyWith(
              color: textC,
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: bgC,
          side: BorderSide(color: borderC, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          padding: EdgeInsets.symmetric(horizontal: horizontalPad),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
        ),
      ),
    );
  }
}

// 저장버튼 (플로팅)
class SaveFloatingButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String tooltip;
  final bool enabled;

  const SaveFloatingButton({
    super.key,
    required this.onPressed,
    this.tooltip = '저장하기',
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final s = _UiScale.of(context);
    final fabSize = s.isTablet ? 44.0 : (s.isSmallPhone ? 38.0 : 40.0);
    final iconSize = s.isTablet ? 22.0 : 20.0;

    return Tooltip(
      message: tooltip,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.55,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _a(Colors.black, 0.22),
                blurRadius: 7,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SizedBox(
            width: fabSize,
            height: fabSize,
            child: FloatingActionButton.small(
              onPressed: onPressed,
              backgroundColor: const Color(0xFF4A446E),
              foregroundColor: const Color(0xFFD4C0F2),
              elevation: 0,
              shape: const CircleBorder(side: BorderSide.none),
              child: Icon(Icons.save_rounded, size: iconSize),
            ),
          ),
        ),
      ),
    );
  }
}

// 홈버튼 (플로팅)
class HomeFloatingButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String tooltip;

  const HomeFloatingButton({
    super.key,
    required this.onPressed,
    this.tooltip = '홈으로',
  });

  @override
  State<HomeFloatingButton> createState() => _HomeFloatingButtonState();
}

class _HomeFloatingButtonState extends State<HomeFloatingButton> {
  bool _down = false;

  void _setDown(bool v) {
    if (_down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final s = _UiScale.of(context);

    const bg = Color(0xFF4A446E);
    const fg = Color(0xFFD4C0F2);

    final size = s.isTablet ? 44.0 : (s.isSmallPhone ? 38.0 : 40.0);
    final iconSize = s.isTablet ? 22.0 : 20.0;

    final fill = _down ? _a(fg, 0.16) : bg;

    return Tooltip(
      message: widget.tooltip,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        scale: _down ? 0.96 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _a(Colors.black, _down ? 0.16 : 0.28),
                blurRadius: _down ? 8 : 14,
                offset: Offset(0, _down ? 3 : 8),
              ),
              BoxShadow(
                color: _a(Colors.white, _down ? 0.03 : 0.08),
                blurRadius: 5,
                spreadRadius: -2,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            onTapDown: (_) => _setDown(true),
            onTapCancel: () => _setDown(false),
            onTapUp: (_) => _setDown(false),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: fill,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.home_rounded,
                  size: iconSize,
                  color: fg,
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

/// ✅ FAB 2개 정렬용 슬롯
class FabSlot extends StatelessWidget {
  final Widget child;
  final double size;

  const FabSlot({
    super.key,
    required this.child,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    final s = _UiScale.of(context);
    final resolved = s.isTablet ? math.max(size, 56.0) : size;

    return SizedBox.square(
      dimension: resolved,
      child: Align(
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

/// ------------------------------------------------------------
/// ✅ 공용 "필터 칩" Pill 버튼
/// ------------------------------------------------------------
class AppFilterChipPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

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
    final s = _UiScale.of(context);
    final enabled = onTap != null;

    final bg = selected
        ? _a(AppTheme.gold, 0.12)
        : _a(AppTheme.panelFill, 0.18);

    final bd = selected
        ? _a(AppTheme.gold, 0.40)
        : _a(AppTheme.gold, 0.14);

    final fg = selected
        ? _a(AppTheme.gold, enabled ? 0.92 : 0.40)
        : _a(AppTheme.tSecondary, enabled ? 0.88 : 0.40);

    final resolvedPadding = EdgeInsets.symmetric(
      horizontal: s.isTablet
          ? padding.horizontal / 2 + 2
          : (s.isSmallPhone ? padding.horizontal / 2 - 1 : padding.horizontal / 2),
      vertical: s.isTablet
          ? padding.vertical / 2 + 1
          : (s.isSmallPhone ? padding.vertical / 2 - 0.5 : padding.vertical / 2),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        splashColor: _a(AppTheme.gold, 0.12),
        highlightColor: _a(AppTheme.gold, 0.06),
        child: Ink(
          padding: resolvedPadding,
          decoration: BoxDecoration(
            color: enabled ? bg : _a(bg, 0.55),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: bd, width: 1),
          ),
          child: Text(
            label,
            style: GoogleFonts.gowunDodum(
              fontSize: s.font(fontSize),
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

  /// 광고 보상 확정 후 실행할 작업
  final Future<void> Function() onReward;

  /// 광고 보기 직전 서버/상태 사전 확인
  final Future<void> Function()? precheckBeforeAd;

  final VoidCallback? onDisabledTap;
  final VoidCallback? onNotReady;
  final VoidCallback? onRewardNotEarned;
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
    final s = _UiScale.of(context);

    unawaited(RewardedGate.warmUp());

    Future<void> _runAdFlow({
      required bool adReady,
      required bool adBusy,
    }) async {
      if (!enabled) {
        onDisabledTap?.call();
        return;
      }

      if (adBusy || !adReady) {
        unawaited(RewardedGate.preload());
        onNotReady?.call();
        return;
      }

      try {
        if (precheckBeforeAd != null) {
          await precheckBeforeAd!.call();
        }

        final rewarded = await RewardedGate.showForRewardResult(
          context,
          skipConfirm: false,
          confirmTitle: '달냥이의 해석 힌트',
          confirmMessage: confirmMessage,
          onNotReady: () => onNotReady?.call(),
          onShowFailed: (e) => onShowFailed?.call(e),
        );

        if (!rewarded) {
          onRewardNotEarned?.call();
          return;
        }

        await onReward();
      } catch (e) {
        await handleDalnyangError(context, e);
      }
    }

    return ValueListenableBuilder<bool>(
      valueListenable: RewardedGate.isReadyNotifier,
      builder: (context, adReady, _) {
        final adBusy = RewardedGate.isLoading || RewardedGate.isShowing;
        final effectiveEnabled = enabled && adReady && !adBusy;

        final fg = effectiveEnabled
            ? _a(AppTheme.tPrimary, 0.90)
            : _a(AppTheme.tSecondary, 0.55);
        final bg = _a(AppTheme.gold, effectiveEnabled ? 0.12 : 0.06);
        final bd = _a(AppTheme.gold, effectiveEnabled ? 0.35 : 0.18);

        final fontSize = s.font(11.8);
        final iconSize = s.icon(14);
        final horizontal = s.isTablet ? 12.0 : (s.isSmallPhone ? 8.0 : 10.0);
        final vertical = s.isTablet ? 8.0 : (s.isSmallPhone ? 6.0 : 7.0);

        final label = !enabled
            ? '달냥이에게 물어보기'
            : (effectiveEnabled ? '달냥이에게 물어보기' : '광고 준비중...');

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async => _runAdFlow(
              adReady: adReady,
              adBusy: adBusy,
            ),
            borderRadius: BorderRadius.circular(999),
            splashColor: _a(AppTheme.gold, 0.12),
            highlightColor: _a(AppTheme.gold, 0.06),
            child: Ink(
              padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: bd, width: 0.9),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: iconSize,
                      height: iconSize,
                      child: adBusy
                          ? SizedBox(
                        width: iconSize,
                        height: iconSize,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          valueColor: AlwaysStoppedAnimation<Color>(fg),
                        ),
                      )
                          : Icon(Icons.pets_rounded, size: iconSize, color: fg),
                    ),
                    SizedBox(width: s.isTablet ? 7 : 6),
                    Text(
                      label,
                      style: GoogleFonts.gowunDodum(
                        fontSize: fontSize,
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
          ),
        );
      },
    );
  }
}

class AppHeaderHomeButton extends StatefulWidget {
  final VoidCallback onTap;

  const AppHeaderHomeButton({
    super.key,
    required this.onTap,
  });

  @override
  State<AppHeaderHomeButton> createState() => _AppHeaderHomeButtonState();
}

class _AppHeaderHomeButtonState extends State<AppHeaderHomeButton> {
  bool _down = false;

  void _setDown(bool v) {
    if (_down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final s = _UiScale.of(context);

    final horizontal = s.isTablet ? 12.0 : (s.isSmallPhone ? 8.0 : 10.0);
    final vertical = s.isTablet ? 6.0 : 5.0;
    final radius = s.isTablet ? 14.0 : 12.0;
    final iconSize = s.icon(16);

    final normalFill = _a(Colors.white, 0.04);
    final pressedFill = _a(Colors.white, 0.09);

    final normalBorder = _a(Colors.white, 0.08);
    final pressedBorder = _a(Colors.white, 0.14);

    return Tooltip(
      message: '홈으로',
      waitDuration: const Duration(milliseconds: 400),
      showDuration: const Duration(seconds: 2),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => _setDown(true),
        onTapCancel: () => _setDown(false),
        onTapUp: (_) => _setDown(false),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          scale: _down ? 0.97 : 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [
                BoxShadow(
                  color: _a(Colors.black, _down ? 0.025 : 0.06),
                  blurRadius: _down ? 4 : 8,
                  offset: Offset(0, _down ? 1 : 3),
                  spreadRadius: -3,
                ),
              ],
            ),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: horizontal,
                vertical: vertical,
              ),
              decoration: BoxDecoration(
                color: _down ? pressedFill : normalFill,
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  color: _down ? pressedBorder : normalBorder,
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.home_rounded,
                size: iconSize,
                color: _a(AppTheme.tPrimary, 0.82),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppPressButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  final double scaleDown;
  final Duration animDuration;

  final BorderRadius? borderRadius;
  final Color? normalColor;
  final Color? pressedColor;
  final BoxBorder? border;

  const AppPressButton({
    super.key,
    required this.child,
    required this.onTap,
    this.scaleDown = 0.96,
    this.animDuration = const Duration(milliseconds: 110),
    this.borderRadius,
    this.normalColor,
    this.pressedColor,
    this.border,
  });

  @override
  State<AppPressButton> createState() => _AppPressButtonState();
}

class _AppPressButtonState extends State<AppPressButton> {
  bool _down = false;

  void _setDown(bool v) {
    if (_down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final fill = _down
        ? (widget.pressedColor ?? widget.normalColor)
        : widget.normalColor;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => _setDown(true),
      onTapCancel: () => _setDown(false),
      onTapUp: (_) => _setDown(false),
      child: AnimatedScale(
        duration: widget.animDuration,
        curve: Curves.easeOutCubic,
        scale: _down ? widget.scaleDown : 1.0,
        child: AnimatedContainer(
          duration: widget.animDuration,
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: widget.borderRadius,
            border: widget.border,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class AppHeaderHomeIconButton extends StatelessWidget {
  final VoidCallback onTap;

  const AppHeaderHomeIconButton({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppHeaderIconPressButton(
      onTap: onTap,
      icon: Icons.home_rounded,
    );
  }
}

class AppHeaderIconPressButton extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData icon;

  final double? size;
  final double? iconSize;
  final Color? iconColor;

  final double scaleDown;
  final Duration animDuration;
  final double pressedOpacity;

  const AppHeaderIconPressButton({
    super.key,
    required this.onTap,
    required this.icon,
    this.size,
    this.iconSize,
    this.iconColor,
    this.scaleDown = 0.94,
    this.animDuration = const Duration(milliseconds: 110),
    this.pressedOpacity = 0.08,
  });

  @override
  Widget build(BuildContext context) {
    final s = _UiScale.of(context);

    final resolvedSize = size ?? (s.isTablet ? 52.0 : 48.0);
    final resolvedIconSize = iconSize ?? s.icon(24);
    final resolvedIconColor =
        iconColor ?? _a(AppTheme.homeInkWarm, 0.96);

    return AppPressButton(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      normalColor: Colors.transparent,
      pressedColor: _a(Colors.white, pressedOpacity),
      scaleDown: scaleDown,
      animDuration: animDuration,
      child: SizedBox(
        width: resolvedSize,
        height: resolvedSize,
        child: Center(
          child: Icon(
            icon,
            size: resolvedIconSize,
            color: resolvedIconColor,
          ),
        ),
      ),
    );
  }
}


class AppHeaderBackIconButton extends StatelessWidget {
  final VoidCallback onTap;
  final double? size;
  final double? iconSize;

  const AppHeaderBackIconButton({
    super.key,
    required this.onTap,
    this.size,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return AppHeaderIconPressButton(
      onTap: onTap,
      icon: Icons.arrow_back_rounded,
      size: size ?? 40,
      iconSize: iconSize ?? 24,
    );
  }
}