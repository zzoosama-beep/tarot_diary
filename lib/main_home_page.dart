// lib/main_home_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../diary/write_diary.dart';
import '../diary/calander_diary.dart';

import '../backend/diary_repo.dart';
import '../arcana/arcana_labels.dart';

import '../login.dart';

// ✅ withOpacity 대체: 알파 정밀도/워닝 회피용
Color _a(Color c, double o) => c.withAlpha((o * 255).round());

/// ======================================================
/// ✅ Home (2단 레이아웃)
/// - 상단: 1/3 (bg #f0e0fc) + 오늘 날짜 카드 1~3장 가로 나열 + 달냥이(랜턴)
/// - 하단: 2/3 (bg #f7ebfc, 상단만 라운드) + 2열 타일 버튼들 + 하단 링크
/// - 텍스트/아이콘 컬러 통일: #7a41c2
/// ======================================================
class _ThemeX {
  // ✅ BG
  static const Color topBg = Color(0xFFF0E0FC); // #f0e0fc
  static const Color bottomBg = Color(0xFFF7EBFC); // #f7ebfc

  // ✅ Text/Icon (통일)
  static const Color ink = Color(0xFF7A41C2); // #7a41c2

  // ✅ 버튼 타일 BG
  static const Color btn1 = Color(0xFFE8E3FF);
  static const Color btn2 = Color(0xFFFFE3E6);
  static const Color btn3 = Color(0xFFFFF2D6);
  static const Color btn4 = Color(0xFFE4D2F7); // 예비 버튼 bg
}

class MainHomePage extends StatefulWidget {
  const MainHomePage({super.key});

  @override
  State<MainHomePage> createState() => _MainHomePageState();
}

class _MainHomePageState extends State<MainHomePage> {
  Future<void> _openWithLogin(
      BuildContext context,
      Widget page, {
        String? reason,
      }) async {
    final ok = await requireGoogleLogin(
      context,
      title: '로그인이 필요해',
      message: reason ?? '구글 로그인하면 기기 변경/재설치 후에도 데이터를 안전하게 사용할 수 있어.',
    );
    if (!ok) return;
    if (!context.mounted) return;
    Navigator.of(context).push(_fadeRoute(page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ 라운드가 보이려면 틈(top:12) 뒤 배경이 topBg여야 함
      backgroundColor: _ThemeX.topBg,
      body: SafeArea(
        child: Column(
          children: [
            // =========================
            // ✅ TOP (1/3)
            // - 카드(왼쪽) + 달냥이(오른쪽) + 랜턴 빛
            // =========================
            Expanded(
              flex: 1,
              child: Container(
                width: double.infinity,
                color: _ThemeX.topBg,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: const _TopShowcase(),
              ),
            ),

            // =========================
            // ✅ BOTTOM (2/3) - 상단만 라운드
            // =========================
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.only(top: 12), // ✅ 라운드 공간
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(34),
                    topRight: Radius.circular(34),
                  ),
                  child: Container(
                    width: double.infinity,
                    color: _ThemeX.bottomBg,
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final contentW = (c.maxWidth - 32).clamp(0.0, 520.0);

                        return Center(
                          child: SizedBox(
                            width: contentW,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
                              child: Column(
                                children: [
                                  // ✅ 2개씩(2열) 타일
                                  Expanded(
                                    child: GridView.count(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      childAspectRatio: 1.55,
                                      physics: const NeverScrollableScrollPhysics(),
                                      padding: EdgeInsets.zero,
                                      children: [
                                        _HomeTile2Col(
                                          bg: _ThemeX.btn1,
                                          icon: Icons.edit_rounded,
                                          title: '내일의 타로일기',
                                          subtitle: '내일의 흐름 기록',
                                          onTap: () {
                                            _openWithLogin(context, const WriteDiaryPage());
                                          },
                                        ),
                                        _HomeTile2Col(
                                          bg: _ThemeX.btn2,
                                          icon: Icons.calendar_month_rounded,
                                          title: '일기 보관함',
                                          subtitle: '달력으로 보기',
                                          onTap: () {
                                            _openWithLogin(context, const CalanderDiaryPage());
                                          },
                                        ),
                                        _HomeTile2Col(
                                          bg: _ThemeX.btn3,
                                          icon: Icons.auto_awesome_rounded,
                                          title: '아르카나',
                                          subtitle: '78장 카드 보기',
                                          onTap: () {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('아르카나 도감(준비중)')),
                                            );
                                          },
                                        ),
                                        _HomeTile2Col(
                                          bg: _ThemeX.btn4, // ✅ 예비색 #e4d2f7
                                          icon: Icons.settings_rounded,
                                          title: '예비',
                                          subtitle: '추가 메뉴',
                                          onTap: () {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('준비중')),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  // 하단 링크
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      TextButton(
                                        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('설정(준비중)')),
                                        ),
                                        child: Text(
                                          '설정',
                                          style: GoogleFonts.gowunDodum(
                                            fontSize: 12.6,
                                            fontWeight: FontWeight.w900,
                                            color: _ThemeX.ink,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '·',
                                        style: GoogleFonts.gowunDodum(
                                          fontSize: 12.6,
                                          fontWeight: FontWeight.w900,
                                          color: _a(_ThemeX.ink, 0.55),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('문의하기(준비중)')),
                                        ),
                                        child: Text(
                                          '문의하기',
                                          style: GoogleFonts.gowunDodum(
                                            fontSize: 12.6,
                                            fontWeight: FontWeight.w900,
                                            color: _ThemeX.ink,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ======================================================
/// ✅ TOP Showcase
/// - 카드 영역(왼쪽) + 달냥이(오른쪽)
/// - 오른쪽에서 왼쪽으로 랜턴 빛 오버레이
/// ======================================================
class _TopShowcase extends StatelessWidget {
  const _TopShowcase();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        // 오른쪽에 달냥이 자리 확보
        final catW = (c.maxWidth * 0.30).clamp(110.0, 150.0);
        final gap = 8.0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // ✅ 카드 영역(왼쪽)
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(right: catW + gap),
                child: const Align(
                  alignment: Alignment.topCenter,
                  child: _TodayCardsPlainRow(),
                ),
              ),
            ),

            // ✅ 랜턴 빛(오른쪽 -> 왼쪽) : 존재감 올림
            Positioned(
              right: 0,
              top: 6,
              bottom: 6,
              width: catW + 120, // 카드 쪽으로 빛이 퍼지게
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [
                        _a(Colors.white, 0.30),
                        _a(Colors.white, 0.16),
                        _a(Colors.white, 0.00),
                      ],
                      stops: const [0.0, 0.35, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // ✅ 달냥이(오른쪽) - 안 잘리게 + 살짝 띄워 배치
            Positioned(
              right: 6,
              bottom: 8,
              width: catW,
              child: Align(
                alignment: Alignment.bottomRight,
                child: Image.asset(
                  'asset/dalnyang_hermit.png',
                  width: catW, // 전체 폭 맞춤
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  isAntiAlias: true,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// ======================================================
/// ✅ TOP: 오늘 날짜 카드 1~3장 가로 일렬
/// - 카드에 입체감(그림자) + 랜턴 하이라이트(오른쪽)
/// ======================================================
class _TodayCardsPlainRow extends StatelessWidget {
  const _TodayCardsPlainRow();

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<List<int>> _loadTodayCards() async {
    final today = _dateOnly(DateTime.now());
    final doc = await DiaryRepo.I.read(date: today);
    if (doc == null) return const [];

    final raw = doc['cards'];
    if (raw is! List) return const [];

    final out = <int>[];
    for (final v in raw) {
      if (v is int) out.add(v);
      else if (v is num) out.add(v.toInt());
      else if (v is String) {
        final n = int.tryParse(v);
        if (n != null) out.add(n);
      }
    }

    final max = ArcanaLabels.kTarotFileNames.length;
    return out.where((e) => e >= 0 && e < max).take(3).toList();
  }

  String _path(int id) => 'asset/cards/${ArcanaLabels.kTarotFileNames[id]}';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<int>>(
      future: _loadTodayCards(),
      builder: (context, snap) {
        final ids = snap.data ?? const <int>[];

        if (snap.connectionState != ConnectionState.done || ids.isEmpty) {
          return Center(
            child: Text(
              '오늘 기록이 없어요.\n일기를 쓰면 카드가 여기 보여요.',
              textAlign: TextAlign.center,
              style: GoogleFonts.gowunDodum(
                fontSize: 12.6,
                fontWeight: FontWeight.w800,
                color: _a(_ThemeX.ink, 0.85),
                height: 1.25,
              ),
            ),
          );
        }

        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(ids.length, (i) {
                final path = _path(ids[i]);
                return Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 12),
                  child: _CardWithLanternHighlight(path: path),
                );
              }),
            ),
          ),
        );
      },
    );
  }
}

class _CardWithLanternHighlight extends StatelessWidget {
  final String path;
  const _CardWithLanternHighlight({required this.path});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 136,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _a(Colors.black, 0.14),
            blurRadius: 14,
            spreadRadius: -6,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                path,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                isAntiAlias: true,
              ),
            ),

            // ✅ 랜턴 하이라이트: 오른쪽 가장자리만 살짝 밝게
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [
                        _a(Colors.white, 0.24),
                        _a(Colors.white, 0.08),
                        _a(Colors.white, 0.00),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // ✅ 아주 약한 비네팅(입체감)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _a(Colors.black, 0.00),
                        _a(Colors.black, 0.10),
                      ],
                      stops: const [0.55, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ======================================================
/// ✅ 하단 2열 타일 버튼
/// - 좌상단: 아이콘(보라색, 크게)
/// - 좌하단: 제목(굵고 크게) + 설명
/// ======================================================
class _HomeTile2Col extends StatelessWidget {
  final Color bg;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HomeTile2Col({
    required this.bg,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ 좌상단 아이콘 (더 크게)
              Icon(
                icon,
                size: 34,
                color: _ThemeX.ink,
              ),
              const Spacer(),

              // ✅ 좌하단 텍스트
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.gowunDodum(
                  fontSize: 17.5,
                  fontWeight: FontWeight.w900,
                  color: _ThemeX.ink,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.gowunDodum(
                  fontSize: 12.2,
                  fontWeight: FontWeight.w700,
                  color: _a(_ThemeX.ink, 0.70),
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// ✅ 페이드 라우트
// ---------------------------------------------------------
PageRouteBuilder _fadeRoute(Widget page) {
  return PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}
