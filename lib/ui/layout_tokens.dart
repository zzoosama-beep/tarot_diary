// lib/ui/layout_tokens.dart
import 'package:flutter/material.dart';

class LayoutTokens {
  LayoutTokens._();

  // =======================
  // ✅ 기준 규격 (write_diary)
  // =======================
  static const double pageHPad = 24.0;

  // ScrollView padding (write_diary)
  static const double scrollTopPad = 24.0;
  static const double scrollBottomBase = 12.0;

  // Bottom CTA padding (write_diary)
  static const double bottomTopPad = 8.0;
  static const double bottomBottomPad = 24.0;

  // Header back button nudge (write_diary)
  static const double backBtnNudgeX = -8.0;

  // ✅ 타이틀 옵티컬 센터 보정 (왼쪽으로 살짝)
  static const double titleOpticalNudgeX = -12.0;

  // topbox 슬롯 폭 (여기서 “왼쪽 박스 줄이기” 가능)
  static const double topLeftSlotW = 42.0;  // 뒤로가기 영역(기존 40~48 추천)
  static const double topRightSlotW = 130.0; // 날짜 pill 영역(120~150 추천)

  // ✅ BottomBox가 덮는 만큼 스크롤 컨텐츠에 여유 공간 확보
  // 버튼(패딩 포함) + bottom padding + 약간의 여유
  static const double scrollBottomSpacer = 96.0;



  // =======================
  // ✅ TopBox 내부 3분할 슬롯 규격
  // - 타이틀을 "정중앙"으로 만들려면
  //   leftSlotW == rightSlotW 여야 함
  // - write_diary 우측 날짜 pill이 꽤 넓어서
  //   슬롯을 넉넉히 잡는 게 안정적
  // =======================
  static const double topSideSlotW = 140.0; // ✅ 필요하면 120~160 사이로 조절
  static const double topBarH = 40.0;       // _TightIconButton 기본 높이와 맞춤

  // =======================
  // ✅ content width (페이지마다 동일 폭 강제)
  // - 기본은 "화면 - 좌우패딩*2"
  // - 큰 화면에서 너무 넓어지는게 싫으면 maxContentW를 낮춰도 됨
  // =======================
  static const double maxContentW = 520.0; // ✅ 싫으면 크게(9999) 해도 됨

  static double contentW(BuildContext context) {
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final safe = mq.padding.left + mq.padding.right;
    final available = w - safe - (pageHPad * 2);
    return available.clamp(0.0, maxContentW);
  }

  // =======================
  // ✅ padding helpers
  // =======================
  static EdgeInsets scrollPadding(BuildContext context) {
    return EdgeInsets.fromLTRB(
      pageHPad,
      scrollTopPad,
      pageHPad,
      scrollBottomBase + MediaQuery.of(context).viewInsets.bottom,
    );
  }

  static EdgeInsets bottomBarPadding() {
    return const EdgeInsets.fromLTRB(
      pageHPad,
      bottomTopPad,
      pageHPad,
      bottomBottomPad,
    );
  }
}

// ======================================================
// ✅ 큰 박스 3개: TopBox / CenterBox / BottomBox
// ======================================================

/// ✅ TOP BOX (타이틀 절대 중앙 고정 버전)
/// - Row로 슬롯을 나누지 않고 Stack으로
/// - title은 항상 화면(콘텐츠 폭) 정중앙
/// - left/right는 양 끝에 고정 배치
class TopBox extends StatelessWidget {
  final Widget left;
  final Widget title;
  final Widget? right;

  const TopBox({
    super.key,
    required this.left,
    required this.title,
    this.right,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: LayoutTokens.contentW(context),
        height: LayoutTokens.topBarH,
        child: Row(
          children: [
            // ✅ LEFT 슬롯(고정폭) - 여기 폭 줄이면 "왼쪽 박스 줄이기" 효과
            SizedBox(
              width: LayoutTokens.topLeftSlotW,
              child: Align(
                alignment: Alignment.centerLeft,
                child: left,
              ),
            ),

            // ✅ TITLE (가운데 영역만 Expanded)
            Expanded(
              child: Align(
                alignment: Alignment.center,
                child: Transform.translate(
                  offset: const Offset(LayoutTokens.titleOpticalNudgeX, 0),
                  child: title,
                ),
              ),
            ),

            // ✅ RIGHT 슬롯(고정폭) - pill이 절대 늘어나지 않음
            SizedBox(
              width: LayoutTokens.topRightSlotW,
              child: Align(
                alignment: Alignment.centerRight,
                child: right ?? const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



/// ✅ CENTER BOX
/// - 폭: LayoutTokens.contentW
/// - height는 child가 결정(컨텐츠마다 달라지므로)
class CenterBox extends StatelessWidget {
  final Widget child;

  const CenterBox({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: LayoutTokens.contentW(context),
        child: child,
      ),
    );
  }
}

/// ✅ BOTTOM BOX
/// - 폭: LayoutTokens.contentW
/// - padding: write_diary 기준(bottomTopPad/bottomBottomPad)
/// - 저장 버튼 같은 CTA를 넣는 영역
class BottomBox extends StatelessWidget {
  final Widget child;

  const BottomBox({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: LayoutTokens.bottomBarPadding(),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: LayoutTokens.contentW(context),
            child: child,
          ),
        ),
      ),
    );
  }
}
