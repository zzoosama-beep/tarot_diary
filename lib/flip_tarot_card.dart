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

  /// Picker 모드에서 외부에서 리셋 트리거하고 싶을 때 키 변경으로 리셋 가능
  /// (예: ValueKey(deckVersion)로 새로 만들기)

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
      // ✅ Auto는 외부 flipped 따라가야 하고,
      // ✅ Picker는 초기에 무조건 뒷면(0.0)에서 시작하는게 일반적
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

        // ✅ Picker 모드면: 뒤집힘 완료 후 콜백 호출
        if (_isPicker) {
          widget.onSelected?.call();
        }
      }
      if (status == AnimationStatus.dismissed) {
        _hasPoppedThisFlip = false;
        if (_isPicker) _lockedPicker = false; // 리셋 가능(키 재생성 안 해도)
      }
    });
  }

  @override
  void didUpdateWidget(covariant FlipTarotCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // ✅ Auto 모드: 외부 flipped 변경에 따라 애니
    if (_isAuto && oldWidget.flipped != widget.flipped) {
      if (widget.flipped) {
        _flipC.forward();
      } else {
        _flipC.reverse();
      }
    }

    // ✅ Picker 모드: 외부에서 이미지를 바꾸면(카드 교체 등) 다시 뒷면부터 시작시키고 싶을 수 있음
    // - 가장 안전한 방법은 부모가 key를 바꾸는 것(ValueKey)
    // - 여기서는 "frontImage가 바뀌었고, 아직 뒤집힌 상태면" 다시 뒤집어두는 정도만 제공
    if (_isPicker && oldWidget.frontImage != widget.frontImage) {
      // 필요하면 여기서 리셋/동작 변경 가능
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
      // -----------------------
      // Picker 모드: 내부에서 flip
      // -----------------------
      if (_lockedPicker) return;
      if (_flipC.isAnimating) return;

      _lockedPicker = true;
      _flipC.forward(from: 0.0);
      return;
    }

    // -----------------------
    // Auto 모드: 부모가 처리 후 flipped를 true로 바꿔주면 애니가 따라감
    // -----------------------
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final badge = widget.orderBadge;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: _tapDown,
      onTapUp: _tapUp,
      onTapCancel: _tapCancel,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
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
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.white.withOpacity(0.08),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.auto_awesome,
                    color: Colors.white.withOpacity(0.45),
                  ),
                ),
              );

              // ✅ 앞면 좌우반전 방지
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
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        face,
                        if (widget.selectedOutline)
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.85),
                                width: 2,
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

          // ✅ 숫자 뱃지(절대 안 뒤집힘)
          if (badge != null)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                ),
                child: Text(
                  "$badge",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
