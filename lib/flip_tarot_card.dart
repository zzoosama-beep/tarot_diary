import 'dart:math';
import 'package:flutter/material.dart';

enum FlipTarotMode {
  /// 카드피커용: 탭하면 내부에서 flip 애니 -> 완료 후 onSelected 콜백
  picker,

  /// 자동탭용: 부모가 flipped를 제어 (탭 이벤트도 부모가 처리)
  auto,
}

/// =======================================================
/// FlipTarotCard
/// - ✅ 한 파일에서 모드 2개로 분기
///   1) picker: internal flip + locked + onSelected(after completed)
///   2) auto  : controlled flip (widget.flipped) + onTap (parent handles)
/// - ✅ orderBadge는 카드 위에 고정(뒤집혀도 안 뒤집힘)
/// - ✅ 앞면 좌우반전 방지(Front일 때 pi 보정)
/// - ✅ 반응형: 카드 실제 크기에 따라 radius / badge / icon / border 자동 조정
/// =======================================================
class FlipTarotCard extends StatefulWidget {
  final FlipTarotMode mode;

  /// 이미지 경로
  final String frontImage;
  final String backImage;

  /// 공통: 비활성화
  final bool disabled;

  /// 공통: 선택 순서 뱃지 (1,2,3) - null이면 표시 안 함
  final int? orderBadge;

  /// 공통: 선택 테두리 표시 여부(선택 강조)
  final bool selectedOutline;

  // -----------------------
  // Auto 모드 전용(Controlled)
  // -----------------------
  /// 부모가 현재 flipped 상태를 제공
  final bool flipped;

  /// Auto 모드에서 탭 시 호출(부모가 카드 뽑기/상태변경)
  final VoidCallback? onTap;

  // -----------------------
  // Picker 모드 전용(Internal)
  // -----------------------
  /// Picker 모드에서 "뒤집힘 완료 후" 호출 (부모가 선택 처리)
  final VoidCallback? onSelected;

  const FlipTarotCard({
    super.key,
    required this.mode,
    required this.frontImage,
    required this.backImage,
    this.disabled = false,
    this.orderBadge,
    this.selectedOutline = false,

    // auto
    this.flipped = false,
    this.onTap,

    // picker
    this.onSelected,
  }) : assert(
  mode == FlipTarotMode.picker || onTap != null,
  'Auto 모드에서는 onTap이 필요해',
  );

  @override
  State<FlipTarotCard> createState() => _FlipTarotCardState();
}

class _FlipTarotCardState extends State<FlipTarotCard>
    with TickerProviderStateMixin {
  late final AnimationController _flipC;
  late final AnimationController _pressC;
  late final AnimationController _popC;

  late final Animation<double> _pressScale;
  late final Animation<double> _popScale;

  bool _lockedPicker = false;
  bool _hasPoppedThisFlip = false;

  bool get _isPicker => widget.mode == FlipTarotMode.picker;
  bool get _isAuto => widget.mode == FlipTarotMode.auto;

  @override
  void initState() {
    super.initState();

    _flipC = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
      value: _isAuto ? (widget.flipped ? 1.0 : 0.0) : 0.0,
    );

    _pressC = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      value: 0.0,
    );

    _popC = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 170),
      value: 0.0,
    );

    _pressScale = Tween<double>(begin: 1.0, end: 0.985).animate(
      CurvedAnimation(parent: _pressC, curve: Curves.easeOut),
    );

    _popScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.035)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.035, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 45,
      ),
    ]).animate(_popC);

    _flipC.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_hasPoppedThisFlip) {
        _hasPoppedThisFlip = true;
        _popC.forward(from: 0.0);

        if (_isPicker) {
          widget.onSelected?.call();
        }
      }

      if (status == AnimationStatus.dismissed) {
        _hasPoppedThisFlip = false;
        if (_isPicker) {
          _lockedPicker = false;
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant FlipTarotCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_isAuto && oldWidget.flipped != widget.flipped) {
      if (widget.flipped) {
        _flipC.forward();
      } else {
        _flipC.reverse();
      }
    }

    if (_isPicker && oldWidget.frontImage != widget.frontImage) {
      // 부모가 key 변경으로 재생성하는 방식이 가장 안전
    }
  }

  @override
  void dispose() {
    _flipC.dispose();
    _pressC.dispose();
    _popC.dispose();
    super.dispose();
  }

  void _tapDown(TapDownDetails _) {
    if (widget.disabled) return;
    _pressC.forward();
  }

  void _tapCancel() {
    _pressC.reverse();
  }

  void _tapUp(TapUpDetails _) {
    _pressC.reverse();
    _handleTap();
  }

  void _handleTap() {
    if (widget.disabled) return;

    if (_isPicker) {
      if (_lockedPicker) return;
      if (_flipC.isAnimating) return;

      _lockedPicker = true;
      _flipC.forward(from: 0.0);
      return;
    }

    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final badge = widget.orderBadge;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardW = constraints.maxWidth.isFinite ? constraints.maxWidth : 100.0;
        final cardH = constraints.maxHeight.isFinite ? constraints.maxHeight : 160.0;
        final shortest = min(cardW, cardH);

        final ui = _FlipCardResponsive.fromSize(cardW, cardH, shortest);

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: _tapDown,
          onTapUp: _tapUp,
          onTapCancel: _tapCancel,
          child: Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_flipC, _pressC, _popC]),
                  builder: (context, _) {
                    final t = _flipC.value;
                    final angle = t * pi;
                    final showFront = angle > (pi / 2);

                    final m = Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(angle);

                    Widget face = Image.asset(
                      showFront ? widget.frontImage : widget.backImage,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.white.withAlpha((0.08 * 255).round()),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.auto_awesome,
                          size: ui.fallbackIconSize,
                          color: Colors.white.withAlpha((0.45 * 255).round()),
                        ),
                      ),
                    );

                    if (showFront) {
                      face = Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateY(pi),
                        child: face,
                      );
                    }

                    final scale = _pressScale.value * _popScale.value;

                    return Transform.scale(
                      scale: scale,
                      child: Transform(
                        alignment: Alignment.center,
                        transform: m,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(ui.cardRadius),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Positioned.fill(child: face),
                              if (widget.disabled)
                                Positioned.fill(
                                  child: Container(
                                    color: Colors.black.withAlpha((0.16 * 255).round()),
                                  ),
                                ),
                              if (widget.selectedOutline)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius:
                                      BorderRadius.circular(ui.cardRadius),
                                      border: Border.all(
                                        color: Colors.white
                                            .withAlpha((0.85 * 255).round()),
                                        width: ui.outlineWidth,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ✅ 숫자 뱃지(절대 안 뒤집힘)
              if (badge != null)
                Positioned(
                  top: ui.badgeInset,
                  right: ui.badgeInset,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ui.badgeHorizontalPadding,
                      vertical: ui.badgeVerticalPadding,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha((0.55 * 255).round()),
                      borderRadius: BorderRadius.circular(ui.badgeRadius),
                      border: Border.all(
                        color: Colors.white.withAlpha((0.25 * 255).round()),
                        width: ui.badgeBorderWidth,
                      ),
                    ),
                    child: Text(
                      "$badge",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: ui.badgeFontSize,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _FlipCardResponsive {
  final double cardRadius;
  final double outlineWidth;
  final double fallbackIconSize;

  final double badgeInset;
  final double badgeHorizontalPadding;
  final double badgeVerticalPadding;
  final double badgeRadius;
  final double badgeBorderWidth;
  final double badgeFontSize;

  const _FlipCardResponsive({
    required this.cardRadius,
    required this.outlineWidth,
    required this.fallbackIconSize,
    required this.badgeInset,
    required this.badgeHorizontalPadding,
    required this.badgeVerticalPadding,
    required this.badgeRadius,
    required this.badgeBorderWidth,
    required this.badgeFontSize,
  });

  factory _FlipCardResponsive.fromSize(
      double width,
      double height,
      double shortest,
      ) {
    double scale = shortest / 100.0;

    if (scale < 0.72) scale = 0.72;
    if (scale > 1.6) scale = 1.6;

    double radius = 14.0 * scale;
    radius = radius.clamp(9.0, 20.0);

    double outlineWidth = (2.0 * scale).clamp(1.2, 2.6);
    double fallbackIconSize = (24.0 * scale).clamp(16.0, 34.0);

    double badgeInset = (6.0 * scale).clamp(4.0, 10.0);
    double badgeHPad = (7.0 * scale).clamp(5.0, 10.0);
    double badgeVPad = (4.0 * scale).clamp(3.0, 6.0);
    double badgeRadius = (10.0 * scale).clamp(8.0, 14.0);
    double badgeBorderWidth = (1.0 * scale).clamp(0.8, 1.4);
    double badgeFontSize = (12.0 * scale).clamp(10.0, 16.0);

    return _FlipCardResponsive(
      cardRadius: radius,
      outlineWidth: outlineWidth,
      fallbackIconSize: fallbackIconSize,
      badgeInset: badgeInset,
      badgeHorizontalPadding: badgeHPad,
      badgeVerticalPadding: badgeVPad,
      badgeRadius: badgeRadius,
      badgeBorderWidth: badgeBorderWidth,
      badgeFontSize: badgeFontSize,
    );
  }
}