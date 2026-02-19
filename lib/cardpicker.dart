// lib/card_picker.dart
import 'dart:math';
import 'package:flutter/material.dart';

import 'arcana/arcana_labels.dart';
import 'theme/app_theme.dart'; // ✅ 폰트/컬러 통일용 (경로 다르면 수정)

// ✅ withOpacity 대체: 알파 정밀도/워닝 회피용
Color _a(Color c, double o) => c.withAlpha((o * 255).round());

// ✅ WriteDiary랑 같은 배경(별 없는 딥퍼플 그라데이션)
const Color _bgTop = Color(0xFF1B132E);
const Color _bgMid = Color(0xFF3A2B5F);
const Color _bgBot = Color(0xFF5A3F86);

// ✅ write_diary_one 헤더 잉크톤에 맞추기
Color get _ink => _a(AppTheme.homeInkWarm, 0.96);
Color get _inkSub => _a(AppTheme.homeInkWarm, 0.72);

// ✅ 선택/잠금 테두리 (골드 제거)
Color get _pickRing => _a(AppTheme.headerInk, 0.22);      // write_diary_one 느낌
Color get _pickRingStrong => _a(AppTheme.headerInk, 0.34);

// ✅ 카드 선택 모달 열기 (반환: 카드 id 리스트)
Future<List<int>?> openCardPicker({
  required BuildContext context,
  required int maxPickCount,
  List<int> preselected = const [],
}) {
  return showDialog<List<int>>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _CardPickerDialog(
      maxPickCount: maxPickCount.clamp(1, 3),
      preselected: preselected,
    ),
  );
}

class _CardPickerDialog extends StatefulWidget {
  final int maxPickCount;
  final List<int> preselected;

  const _CardPickerDialog({
    required this.maxPickCount,
    required this.preselected,
  });

  @override
  State<_CardPickerDialog> createState() => _CardPickerDialogState();
}

class _CardPickerDialogState extends State<_CardPickerDialog> {
  int _resetNonce = 0;

  late final List<int> _deck; // 0~77 shuffled
  final List<int> _picked = [];

  @override
  void initState() {
    super.initState();

    _deck = List<int>.generate(ArcanaLabels.kTarotFileNames.length, (i) => i)
      ..shuffle(Random());

    // ✅ preselected 유지
    for (final id in widget.preselected) {
      if (_picked.length >= widget.maxPickCount) break;
      if (id < 0 || id >= ArcanaLabels.kTarotFileNames.length) continue;
      if (_picked.contains(id)) continue;
      _picked.add(id);
    }
  }

  Widget _bg({required Widget child}) {
    return Container(
      color: const Color(0xFF2A1E44), // 🔥 단색 (홈 톤과 맞춤)
      child: child,
    );
  }


  void _resetPicks() {
    setState(() {
      _picked.clear();
      _resetNonce++;
    });
  }

  bool _isPicked(int id) => _picked.contains(id);

  void _select(int id) {
    setState(() {
      if (_picked.contains(id)) return;
      if (_picked.length >= widget.maxPickCount) return;
      _picked.add(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isComplete = _picked.length == widget.maxPickCount;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2A1E44),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _a(Colors.white, 0.12)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),

            // ===== 헤더 =====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  _TightIconButton(
                    icon: Icons.close,
                    color: _ink,
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "카드 선택",
                    style: AppTheme.title.copyWith(
                      fontSize: 18,
                      color: _ink,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    "${_picked.length}/${widget.maxPickCount}",
                    style: AppTheme.uiSmallLabel.copyWith(
                      color: _inkSub,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "뒷면을 눌러 선택해줘. (선택하면 뒤집혀)",
                  style: AppTheme.uiSmallLabel.copyWith(
                    color: _a(AppTheme.headerInk, 0.62),
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ===== 그리드 =====
            Expanded(
              child: Scrollbar(
                thumbVisibility: true,
                child: GridView.builder(
                  key: ValueKey(_resetNonce),
                  padding: const EdgeInsets.all(14),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1 / 1.64,
                  ),
                  itemCount: _deck.length,
                  itemBuilder: (context, index) {
                    final id = _deck[index];
                    final fn = ArcanaLabels.kTarotFileNames[id];

                    final picked = _isPicked(id);
                    final limitReached = _picked.length >= widget.maxPickCount;
                    final shouldLock = limitReached && !picked;

                    return FlipTarotCard(
                      key: ValueKey("card-$id"),
                      frontImage: 'asset/cards/$fn',
                      isLocked: shouldLock,
                      isFlipped: picked,
                      orderBadge: picked ? (_picked.indexOf(id) + 1) : null,
                      onFlippedToFront: () => _select(id),
                    );
                  },
                ),
              ),
            ),

            // ===== 하단 버튼 =====
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _picked.isEmpty ? null : _resetPicks,
                    icon: Icon(Icons.refresh, color: _a(_ink, 0.92)),
                    disabledColor: _a(_ink, 0.30),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        onPressed: isComplete
                            ? () =>
                            Navigator.pop(context, List<int>.from(_picked))
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _a(
                              Colors.white, isComplete ? 0.16 : 0.10),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: _a(Colors.white, 0.08),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: _a(Colors.white, 0.18)),
                          ),
                        ),
                        child: Text(
                          isComplete ? "선택 완료" : "카드를 ${widget
                              .maxPickCount}장 선택해줘",
                          style: AppTheme.uiSmallLabel.copyWith(
                            color: _a(_ink, isComplete ? 0.98 : 0.55),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

  /// ✅ 헤더 아이콘 타이트 버튼
class _TightIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _TightIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 22,
      splashColor: _a(Colors.white, 0.06),
      highlightColor: _a(Colors.white, 0.04),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Icon(icon, size: 22, color: color),
        ),
      ),
    );
  }
}

/// ✅ write_diary_one 카드 뒷면 스타일(픽커용)
class _PickerBackCard extends StatelessWidget {
  final bool dimmed;
  final bool highlighted;

  const _PickerBackCard({
    this.dimmed = false,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    const outerR = 7.0;
    const innerR = 5.6;

    const ivoryWarm = Color(0xFFF1E9DE);
    const top = Color(0xFF60407E);
    const bottom = Color(0xFF3F2A5B);

    final seamLine = _a(const Color(0xFF2A1636), 0.22);
    final star = _a(AppTheme.headerInk, 0.82);

    const framePad = 4.6;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(outerR),
        border: highlighted ? Border.all(color: _pickRingStrong, width: 1.2) : null,
        boxShadow: [
          BoxShadow(
            color: _a(Colors.black, 0.20),
            blurRadius: 18,
            offset: const Offset(0, 12),
            spreadRadius: -3,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(outerR),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: ivoryWarm,
                  borderRadius: BorderRadius.circular(outerR),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.25, -0.35),
                      radius: 1.2,
                      colors: [
                        _a(Colors.white, 0.26),
                        _a(Colors.white, 0.0),
                      ],
                      stops: const [0.0, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(framePad),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(innerR),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [top, bottom],
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  _a(Colors.black, 0.04),
                                  Colors.transparent,
                                  _a(const Color(0xFF20152E), 0.12),
                                ],
                                stops: const [0.0, 0.64, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: Icon(Icons.auto_awesome, size: 18, color: star),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Positioned.fill(
              child: IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.all(framePad - 0.8),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(innerR + 1.2),
                      border: Border.all(color: seamLine, width: 0.9),
                    ),
                  ),
                ),
              ),
            ),

            if (dimmed) Positioned.fill(child: Container(color: _a(Colors.black, 0.18))),
          ],
        ),
      ),
    );
  }
}

/// ✅ 카드 뒤집기 위젯 (스크롤해도 뒤집힘 유지)
class FlipTarotCard extends StatefulWidget {
  final String frontImage;
  final bool isLocked;
  final bool isFlipped; // ✅ 핵심
  final int? orderBadge;
  final VoidCallback onFlippedToFront;

  const FlipTarotCard({
    super.key,
    required this.frontImage,
    required this.onFlippedToFront,
    this.isLocked = false,
    this.isFlipped = false,
    this.orderBadge,
  });

  @override
  State<FlipTarotCard> createState() => _FlipTarotCardState();
}

class _FlipTarotCardState extends State<FlipTarotCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 420),
      vsync: this,
    );
    _anim = Tween<double>(begin: 0, end: pi).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // ✅ 처음부터 flipped면 completed 상태로 고정
    _controller.value = widget.isFlipped ? 1.0 : 0.0;
  }

  @override
  void didUpdateWidget(covariant FlipTarotCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // ✅ 부모 상태(_picked)가 바뀌면 컨트롤러도 강제로 동기화
    if (oldWidget.isFlipped != widget.isFlipped && !_controller.isAnimating) {
      _controller.value = widget.isFlipped ? 1.0 : 0.0;
    }
  }

  Future<void> _flipToFrontOnce() async {
    if (widget.isLocked) return;
    if (_controller.isAnimating) return;
    if (widget.isFlipped) return; // ✅ 이미 선택된 카드면 다시 뒤집기 금지

    await _controller.forward();
    widget.onFlippedToFront();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badge = widget.orderBadge;
    const double cardR = 7;

    final showPickBorder = widget.isLocked || badge != null;

    return GestureDetector(
      onTap: _flipToFrontOnce,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _anim,
            builder: (context, child) {
              final angle = _anim.value;
              final showFront = angle > (pi / 2);
              final showPickBorder = widget.isLocked || badge != null;

              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(angle),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(cardR),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [

                      // 🔮 카드 앞/뒤
                      Transform(
                        alignment: Alignment.center,
                        transform: showFront
                            ? (Matrix4.identity()..rotateY(pi))
                            : Matrix4.identity(),
                        child: showFront
                            ? Container(
                          color: _a(Colors.black, 0.08),
                          alignment: Alignment.center,
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(cardR - 1),
                              child: Transform.scale(
                                scaleX: 1.06, // 좌우 보더 제거용
                                scaleY: 1.03, // ✅ 위아래 아주 살짝만
                                child: Image.asset(
                                  widget.frontImage,
                                  fit: BoxFit.contain,
                                  alignment: Alignment.center,
                                  filterQuality: FilterQuality.high,
                                ),
                              ),
                            ),
                          ),

                        )
                            : _PickerBackCard(
                          dimmed: widget.isLocked,
                          highlighted: badge != null,
                        ),
                      ),

                      // 🔥 선택/잠금 테두리
                      if (showPickBorder)
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(cardR),
                            border: Border.all(
                              color: _a(AppTheme.headerInk, 0.55), // ✅ 기존 골드 제거
                              width: 1.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),


          // 순서 배지 (골드 제거, 잉크톤으로)
          if (badge != null)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: _a(Colors.black, 0.40),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _pickRing, width: 1.0),
                ),
                child: Text(
                  "$badge",
                  style: AppTheme.uiSmallLabel.copyWith(
                    color: _a(AppTheme.homeInkWarm, 0.92),
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
