import 'dart:math';
import 'package:flutter/material.dart';

class FlipTarotCard extends StatefulWidget {
  final String frontImage;
  final String backImage;

  /// 부모(cardpicker)에서 선택 가능/불가 제어
  final bool disabled;

  /// 선택 순서 뱃지 (1,2,3) - null이면 표시 안 함
  final int? orderBadge;

  /// 뒤집힘 완료 후 호출 (부모가 선택 처리)
  final VoidCallback? onSelected;

  const FlipTarotCard({
    super.key,
    required this.frontImage,
    required this.backImage,
    this.disabled = false,
    this.orderBadge,
    this.onSelected,
  });

  @override
  State<FlipTarotCard> createState() => _FlipTarotCardState();
}

class _FlipTarotCardState extends State<FlipTarotCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  bool _locked = false; // 한 번 선택되면 재클릭 방지

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0, end: pi).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // 애니메이션 완료 후 콜백 실행
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onSelected?.call();
      }
    });
  }

  void _flip() {
    if (widget.disabled) return;
    if (_locked) return;
    if (_controller.isAnimating) return;

    _locked = true;
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badge = widget.orderBadge;

    return GestureDetector(
      onTap: _flip,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ✅ 카드만 뒤집힌다
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              final angle = _animation.value;
              final showFront = angle > (pi / 2);

              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(angle),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
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
                      ),

                      // ✅ 선택된 카드 표시 테두리 (뒤집혀도 상관 없음)
                      if (badge != null)
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
              );
            },
          ),

          // ✅ 숫자 뱃지 (카드 위에, 절대 안 뒤집힘)
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
                  "${badge!}",
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
