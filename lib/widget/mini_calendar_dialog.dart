// mini_calendar_dialog.dart
import 'package:flutter/material.dart';

/// ✅ WriteDiary랑 같은 배경(별 없는 딥퍼플 그라데이션)
const Color _bgTop = Color(0xFF1B132E);
const Color _bgMid = Color(0xFF3A2B5F);
const Color _bgBot = Color(0xFF5A3F86);

/// 🎨 UI Tone (WriteDiary와 통일)
const Color uiTextMain = Color(0xFFD2CEC6); // 웜그레이
const Color uiTextSub = Color(0xFFBEB8AE); // 서브톤
const Color uiGoldSoft = Color(0xFFB6923A); // 브론즈 골드

/// ✅ 포인트 컬러(“카드를 X장 선택해줘” 같은 문구 색과 통일용)
const Color uiAccent = uiGoldSoft;
const double uiAccentOpacity = 0.85;

/// 날짜 key를 “날짜만(시간 0)”으로 맞춰서 Map lookup 안정화
DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

/// ✅ 미니 달력 다이얼로그 열기
///
/// - 반환: 선택한 날짜(DateTime, time=0) 또는 null
/// - markedDays: 기록 있는 날짜 표시용 (dot 표시)
/// - cardPreviewByDay: 하단 왼쪽 “카드 미리보기(최대 3장)”
///   - key: DateTime(년/월/일)
///   - value: 카드 이미지 asset path 리스트 (예: 'asset/cards/00-TheFool.png')
Future<DateTime?> openMiniCalendarDialog({
  required BuildContext context,
  required DateTime initialDate,
  Set<DateTime> markedDays = const {},
  Map<DateTime, List<String>> cardPreviewByDay = const {},
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  final now = DateTime.now();
  final fd = firstDate ?? DateTime(now.year - 5, 1, 1);
  final ld = lastDate ?? DateTime(now.year + 5, 12, 31);

  // ✅ key normalize (혹시 시간 붙어 들어오면 매칭 안 되니까)
  final marked = <DateTime>{};
  for (final d in markedDays) {
    marked.add(_dayKey(d));
  }
  final preview = <DateTime, List<String>>{};
  cardPreviewByDay.forEach((k, v) {
    preview[_dayKey(k)] = v;
  });

  return showDialog<DateTime>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _MiniCalendarDialog(
      initialDate: _dayKey(initialDate),
      firstDate: _dayKey(fd),
      lastDate: _dayKey(ld),
      markedDays: marked,
      cardPreviewByDay: preview,
    ),
  );
}

class _MiniCalendarDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  final Set<DateTime> markedDays;
  final Map<DateTime, List<String>> cardPreviewByDay;

  const _MiniCalendarDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.markedDays,
    required this.cardPreviewByDay,
  });

  @override
  State<_MiniCalendarDialog> createState() => _MiniCalendarDialogState();
}

class _MiniCalendarDialogState extends State<_MiniCalendarDialog> {
  late DateTime _temp;

  @override
  void initState() {
    super.initState();
    _temp = widget.initialDate;
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

  @override
  Widget build(BuildContext context) {
    final accent = uiAccent.withOpacity(uiAccentOpacity);

    // ✅ “선택된 날짜” 숫자 흰색(명확하게 보이게)
    const selectedNumberColor = Colors.white;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: _bg(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              border: Border.all(color: Colors.white.withOpacity(0.16)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ===== 헤더 =====
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                  child: Row(
                    children: [
                      // ✅ X 버튼: “카드를 X장 선택해줘” 문구와 같은 색(= uiAccent)
                      _TightIconButton(
                        icon: Icons.close,
                        color: uiTextMain,
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "날짜 선택",
                        style: TextStyle(
                          color: uiTextMain,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(context, _dayKey(_temp)),
                        child: Text(
                          "확인",
                          style: TextStyle(
                            color: uiTextMain.withOpacity(0.95),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // ===== 달력 =====
                Theme(
                  data: Theme.of(context).copyWith(
                    brightness: Brightness.dark,
                    colorScheme: ColorScheme.dark(
                      // ✅ 선택 날짜 배경(톤다운)
                      primary: uiAccent.withOpacity(0.18),
                      // ✅ 선택 날짜 숫자(흰색)
                      onPrimary: selectedNumberColor,
                      surface: const Color(0xFF191320),
                      onSurface: uiTextMain.withOpacity(0.92),
                    ),
                    dialogBackgroundColor: const Color(0xFF191320),
                    datePickerTheme: DatePickerThemeData(
                      backgroundColor: const Color(0xFF191320),

                      headerBackgroundColor: const Color(0xFF191320),
                      headerForegroundColor: uiAccent.withOpacity(0.85),


                      // ✅ 터치 오버레이(퍼지는 효과)
                      dayOverlayColor:
                      MaterialStateProperty.resolveWith<Color?>((states) {
                        if (states.contains(MaterialState.selected)) {
                          return uiAccent.withOpacity(0.18);
                        }
                        if (states.contains(MaterialState.pressed)) {
                          return uiAccent.withOpacity(0.12);
                        }
                        return null;
                      }),

                      weekdayStyle: TextStyle(
                        color: uiTextSub.withOpacity(0.70),
                        fontWeight: FontWeight.w800,
                      ),
                      dayForegroundColor: MaterialStateProperty.resolveWith<Color?>(
                            (states) {
                          // 기본 숫자 색
                          return uiTextMain.withOpacity(0.90);
                        },
                      ),

                      todayForegroundColor:
                      MaterialStateProperty.all(uiAccent.withOpacity(0.80)),
                      todayBorder: BorderSide(
                        color: uiAccent.withOpacity(0.45),
                        width: 1,
                      ),

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                  child: CalendarDatePicker(
                    initialDate: widget.initialDate,
                    firstDate: widget.firstDate,
                    lastDate: widget.lastDate,
                    onDateChanged: (d) => setState(() => _temp = _dayKey(d)),
                    selectableDayPredicate: (d) => true,
                    // ✅ 아래 dot/미리보기 때문에 “캘린더 셀 커스텀”이 필요하면
                    // CalendarDatePicker만으로는 한계가 있어.
                    // 일단은 “선택 후 아래 카드 미리보기”로 충분히 가고,
                    // ‘날짜 아래 dot’은 달력 커스텀 위젯(직접 구현)로 확장하는 게 안전함.
                  ),
                ),

                // ===== 하단: 선택 날짜 카드 미리보기(왼쪽, 최대 3장) =====
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                  child: Row(
                    children: [
                      _CardPreviewStrip(
                        cards: widget.cardPreviewByDay[_dayKey(_temp)] ?? const [],
                      ),
                      const Spacer(),
                      Text(
                        _fmtKorean(_temp),
                        style: TextStyle(
                          color: uiTextSub.withOpacity(0.92),
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
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

/// ✅ 하단 왼쪽 카드 미리보기 (최대 3장)
class _CardPreviewStrip extends StatelessWidget {
  final List<String> cards;

  const _CardPreviewStrip({required this.cards});

  @override
  Widget build(BuildContext context) {
    final list = cards.take(3).toList();
    if (list.isEmpty) {
      return Opacity(
        opacity: 0.55,
        child: Text(
          "카드 없음",
          style: TextStyle(
            color: uiTextSub.withOpacity(0.9),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(list.length, (i) {
        final path = list[i];
        return Padding(
          padding: EdgeInsets.only(right: i == list.length - 1 ? 0 : 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: 24,
              height: 36,
              color: Colors.black.withOpacity(0.12),
              child: Image.asset(
                path,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        );
      }),
    );
  }
}

String _fmtKorean(DateTime d) => "${d.month}월 ${d.day}일 (${_dowK(d.weekday)})";

String _dowK(int w) {
  switch (w) {
    case DateTime.monday:
      return "월";
    case DateTime.tuesday:
      return "화";
    case DateTime.wednesday:
      return "수";
    case DateTime.thursday:
      return "목";
    case DateTime.friday:
      return "금";
    case DateTime.saturday:
      return "토";
    default:
      return "일";
  }
}

/// ✅ 헤더 아이콘 타이트 버튼 (터치영역 40x40 유지)
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
