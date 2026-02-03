import 'dart:math';
import 'package:flutter/material.dart';

// ✅ WriteDiary랑 같은 배경(별 없는 딥퍼플 그라데이션)
const Color _bgTop = Color(0xFF1B132E);
const Color _bgMid = Color(0xFF3A2B5F);
const Color _bgBot = Color(0xFF5A3F86);

// 🎨 UI Tone (WriteDiary와 통일)
const Color uiTextMain = Color(0xFFD2CEC6); // 웜그레이(화이트틱 ↓)
const Color uiTextSub  = Color(0xFFBEB8AE); // 더 낮은 서브톤
const Color uiGoldSoft = Color(0xFFB6923A); // 브론즈 골드(노랑쨍 ↓)

// ✅ "예상 기록"에서 쓰는 포인트 컬러를 공용으로
const Color uiAccent = uiGoldSoft;
const double uiAccentOpacity = 0.85;

/// ✅ 78장 파일명 (0~77)
const List<String> kTarotFileNames = [
  "00-TheFool.png",
  "01-TheMagician.png",
  "02-TheHighPriestess.png",
  "03-TheEmpress.png",
  "04-TheEmperor.png",
  "05-TheHierophant.png",
  "06-TheLovers.png",
  "07-TheChariot.png",
  "08-Strength.png",
  "09-TheHermit.png",
  "10-WheelOfFortune.png",
  "11-Justice.png",
  "12-TheHangedMan.png",
  "13-Death.png",
  "14-Temperance.png",
  "15-TheDevil.png",
  "16-TheTower.png",
  "17-TheStar.png",
  "18-TheMoon.png",
  "19-TheSun.png",
  "20-Judgement.png",
  "21-TheWorld.png",
  "22-AceOfWands.png",
  "23-TwoOfWands.png",
  "24-ThreeOfWands.png",
  "25-FourOfWands.png",
  "26-FiveOfWands.png",
  "27-SixOfWands.png",
  "28-SevenOfWands.png",
  "29-EightOfWands.png",
  "30-NineOfWands.png",
  "31-TenOfWands.png",
  "32-PageOfWands.png",
  "33-KnightOfWands.png",
  "34-QueenOfWands.png",
  "35-KingOfWands.png",
  "36-AceOfCups.png",
  "37-TwoOfCups.png",
  "38-ThreeOfCups.png",
  "39-FourOfCups.png",
  "40-FiveOfCups.png",
  "41-SixOfCups.png",
  "42-SevenOfCups.png",
  "43-EightOfCups.png",
  "44-NineOfCups.png",
  "45-TenOfCups.png",
  "46-PageOfCups.png",
  "47-KnightOfCups.png",
  "48-QueenOfCups.png",
  "49-KingOfCups.png",
  "50-AceOfSwords.png",
  "51-TwoOfSwords.png",
  "52-ThreeOfSwords.png",
  "53-FourOfSwords.png",
  "54-FiveOfSwords.png",
  "55-SixOfSwords.png",
  "56-SevenOfSwords.png",
  "57-EightOfSwords.png",
  "58-NineOfSwords.png",
  "59-TenOfSwords.png",
  "60-PageOfSwords.png",
  "61-KnightOfSwords.png",
  "62-QueenOfSwords.png",
  "63-KingOfSwords.png",
  "64-AceOfPentacles.png",
  "65-TwoOfPentacles.png",
  "66-ThreeOfPentacles.png",
  "67-FourOfPentacles.png",
  "68-FiveOfPentacles.png",
  "69-SixOfPentacles.png",
  "70-SevenOfPentacles.png",
  "71-EightOfPentacles.png",
  "72-NineOfPentacles.png",
  "73-TenOfPentacles.png",
  "74-PageOfPentacles.png",
  "75-KnightOfPentacles.png",
  "76-QueenOfPentacles.png",
  "77-KingOfPentacles.png",
];

/// ✅ 카드 선택 모달 열기 (반환: 카드 id 리스트)
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

    _deck = List<int>.generate(kTarotFileNames.length, (i) => i)
      ..shuffle(Random());

    // ✅ preselected 유지
    for (final id in widget.preselected) {
      if (_picked.length >= widget.maxPickCount) break;
      if (id < 0 || id >= kTarotFileNames.length) continue;
      if (_picked.contains(id)) continue;
      _picked.add(id);
    }
  }

  Widget _bg({required Widget child}) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.55, 1.0],
          colors: [_bgTop, _bgMid, _bgBot],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black26,
                      Colors.transparent,
                      Colors.black12,
                    ],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: _bg(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              border: Border.all(color: Colors.white.withOpacity(0.16)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),

                // ===== 헤더 =====
                Padding(
                  // ✅ 헤더 좌우 여백을 약간 줄여서(14→12) 아이콘이 덜 밀려 보이게
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      // ✅ 기존 GestureDetector+Padding 대신
                      //    "시각 위치는 왼쪽으로", "터치 영역은 충분히"인 타이트 버튼 사용
                      _TightIconButton(
                        icon: Icons.close,
                      color: uiTextMain,
                        onTap: () => Navigator.pop(context),
                      ),

                      const SizedBox(width: 8),

                      Text(
                        "카드 선택",
                        style: TextStyle(
                          color: uiTextMain,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                      ),

                      const Spacer(),

                      Text(
                        "${_picked.length}/${widget.maxPickCount}",
                        style: TextStyle(
                          color: uiTextSub,
                          fontWeight: FontWeight.w900,
                        ),
                      )
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
                      style: TextStyle(
                        // ✅ 하드코딩 제거, 포인트 컬러 통일
                        color: uiAccent.withOpacity(uiAccentOpacity),
                        fontWeight: FontWeight.w700,
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
                      padding: const EdgeInsets.all(14),
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 2 / 3, // ✅ 0.642857... 카드 비율과 정확히 맞춤
                      ),

                      itemCount: _deck.length,
                      itemBuilder: (context, index) {
                        final id = _deck[index];
                        final fn = kTarotFileNames[id];

                        final picked = _isPicked(id);
                        final limitReached =
                            _picked.length >= widget.maxPickCount;

                        // ✅ 다 골랐으면 선택된 카드만 터치 허용
                        final shouldLock = picked || (limitReached && !picked);

                        return FlipTarotCard(
                          key: ValueKey("$_resetNonce-$id"),
                          backImage: 'asset/cards/back.png',
                          frontImage: 'asset/cards/$fn',
                          isLocked: shouldLock,
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
                        icon: Icon(Icons.refresh, color: uiTextMain),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: ElevatedButton(
                            onPressed: isComplete
                                ? () => Navigator.pop(
                                context, List<int>.from(_picked))
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(
                                  isComplete ? 0.20 : 0.10),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                    color: Colors.white.withOpacity(0.22)),
                              ),
                            ),
                            child: Text(
                              isComplete
                                  ? "선택 완료"
                                  : "카드를 ${widget.maxPickCount}장 선택해줘",
                              style: const TextStyle(
                                color: uiTextMain,
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
        ),
      ),
    );
  }
}

/// ✅ 헤더 아이콘이 "오른쪽으로 밀려 보이는" 느낌을 줄이는 타이트 버튼
/// - 시각적 위치는 딱 붙여주고
/// - 터치 영역은 40x40 정도로 유지
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

/// ✅ 카드 뒤집기 위젯
class FlipTarotCard extends StatefulWidget {
  final String frontImage;
  final String backImage;
  final bool isLocked;
  final int? orderBadge;
  final VoidCallback onFlippedToFront;

  const FlipTarotCard({
    super.key,
    required this.frontImage,
    required this.backImage,
    required this.onFlippedToFront,
    this.isLocked = false,
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
  }

  Future<void> _flipToFrontOnce() async {
    if (widget.isLocked) return;
    if (_controller.isAnimating) return;

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

              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(angle),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // ✅ 앞면 보여줄 때만 rotateY(pi) 추가해서 미러링 방지
                      Transform(
                        alignment: Alignment.center,
                        transform: showFront
                            ? (Matrix4.identity()..rotateY(pi))
                            : Matrix4.identity(),
                        child: Container(
                          color: Colors.black.withOpacity(0.10), // ✅ 앞/뒤 공통 아주 살짝만
                          child: Transform.scale(
                            // ✅ 뒷면(contain)이 너무 작아지는 걸 “살짝 확대”로 해결
                            scale: showFront ? 1 : 1,
                            child: Image.asset(
                              showFront ? widget.frontImage : widget.backImage,
                              fit: showFront ? BoxFit.cover : BoxFit.contain,
                              alignment: Alignment.center,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                        ),

                      ),

                      if (widget.isLocked || badge != null)
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: uiGoldSoft.withOpacity(0.75),
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

          if (badge != null)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55), // 그대로 유지
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFD4AF37).withOpacity(0.8), // 골드 라인
                  ),
                ),
                child: Text(
                  "$badge",
                  style: const TextStyle(
                    color: uiTextMain,
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
