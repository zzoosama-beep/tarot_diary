import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../ui/layout_tokens.dart';
import '../ui/app_buttons.dart';

Color _a(Color c, double o) => c.withAlpha((o * 255).round());

class TutorialPage extends StatefulWidget {
  const TutorialPage({super.key});

  @override
  State<TutorialPage> createState() => _TutorialPageState();
}

class _TutorialPageState extends State<TutorialPage> {
  static const int _kLoopBase = 1000;
  late final PageController _pageController =
  PageController(initialPage: _kLoopBase * 5);
  int _page = 0;

  // TODO: 실제 블로그 주소로 바꿔줘.
  static final Uri _blogUri = Uri.parse('https://blog.naver.com/');

  late final List<_TutorialItem> _items = [
    const _TutorialItem(
      title: '타로로 내일의 흐름을 기록하는 앱이야',
      body:
      '타로카드를 뽑고 내일의 흐름이나\n'
          '예상되는 일을 미리 기록해두는 앱이야.\n\n'
          '그리고 그 날짜가 되면,\n'
          '전날에 써둔 내용이 홈 화면에서\n'
          '오늘의 카드로 다시 보여져.\n\n'
          '그래서 하루가 지나고 나면\n'
          '내가 예상했던 흐름과 실제를\n'
          '자연스럽게 비교해볼 수 있어.',
      imageLabel: '홈 화면 예시',
      imagePath: 'asset/tutorial/tutorial_0.png',
    ),
    const _TutorialItem(
      title: '오늘의 카드',
      body:
      '홈에서는 오늘 날짜에 해당하는 카드와\n'
          '전날에 기록해둔 내용이 함께 보여.\n\n'
          '카드를 터치하면 해당 일기로 바로 이동해서\n'
          '내용을 확인하거나 이어서 작성할 수 있어.\n\n'
          '아직 기록이 없다면 캘린더로 이동해서\n'
          '날짜를 선택하고 새로 일기를 작성하면 돼.',
      imageLabel: '홈 카드 터치 흐름',
      imagePath: 'asset/tutorial/tutorial_1.png',
    ),
    const _TutorialItem(
      title: '내일 타로일기를 적어봐',
      body:
      '전날 카드를 뽑고\n'
          '내일의 흐름이나 예상되는 일을\n'
          '“예상” 탭에 미리 적어둘 수 있어.\n\n'
          '그리고 그날이 지나면\n'
          '“실제” 탭에 실제로 있었던 일을 기록해.\n\n'
          '이렇게 예상과 실제를 나란히 보면\n'
          '훨씬 더 잘 이해할 수 있어.\n\n'
          '해석이 어렵다면 AI에게 물어보면서\n'
          '정리하는 것도 가능해.',
      imageLabel: '내일 타로일기 쓰기 화면',
      imagePath: 'asset/tutorial/tutorial_2.png',
    ),
    const _TutorialItem(
      title: '아르카나 도감과 달냥이',
      body:
      '각 카드마다\n'
          '“기본 의미”와 “나의 해석”을\n'
          '따로 정리해둘 수 있어.\n\n'
          '필요할 때는 코인 1개를 사용해서\n'
          '달냥이에게 해석 도움을 받을 수 있어.\n\n'
          '코인이 없다면 광고를 보고 충전하거나,\n'
          '프롬프트를 복사해서\n'
          '무료로 AI를 사용할 수도 있어.',
      imageLabel: '아르카나 도감 / 달냥이 화면',
      imagePath: 'asset/tutorial/tutorial_3.png',
    ),
    /*
    const _TutorialItem(
      title: '더 자세한 사용법',
      body:
      '더 자세한 사용법이 궁금하다면\n'
          '블로그에서 이미지와 함께 확인할 수 있어.\n\n'
          '아래 버튼을 누르면 바로 이동할 수 있어.',
      imageLabel: '블로그 바로가기',
      contentType: _TutorialContentType.blogButton,
    ),*/
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _openBlog() async {
    if (!await launchUrl(_blogUri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('블로그를 열지 못했어. 주소를 확인해줘.')),
      );
    }
  }

  Widget _buildSectionCard({
    required Widget child,
    required double radius,
    required EdgeInsetsGeometry padding,
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _a(AppTheme.homeCream, 0.88),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: _a(AppTheme.headerInk, 0.22),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _a(Colors.black, 0.12),
            blurRadius: 18,
            offset: const Offset(0, 12),
            spreadRadius: -8,
          ),
          BoxShadow(
            color: _a(Colors.white, 0.18),
            blurRadius: 12,
            offset: const Offset(0, -6),
            spreadRadius: -8,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildImagePlaceholder({
    required String label,
    required bool isTablet,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: isTablet ? 260 : 220,
        decoration: BoxDecoration(
          color: _a(Colors.white, 0.48),
          borderRadius: BorderRadius.circular(isTablet ? 18 : 16),
          border: Border.all(
            color: _a(AppTheme.headerInk, 0.14),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTheme.body.copyWith(
              fontSize: isTablet ? 14.0 : 13.0,
              height: 1.4,
              color: _a(const Color(0xFF6A5876), 0.72),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTutorialImage({
    required _TutorialItem item,
    required bool isTablet,
  }) {
    final radius = BorderRadius.circular(isTablet ? 18 : 16);
    final imageHeight = isTablet ? 260.0 : 220.0;

    if (item.imagePath == null) {
      return _buildImagePlaceholder(
        label: item.imageLabel,
        isTablet: isTablet,
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: Container(
        width: double.infinity,
        height: imageHeight,
        decoration: BoxDecoration(
          color: _a(Colors.white, 0.20),
          borderRadius: radius,
          border: Border.all(
            color: _a(AppTheme.headerInk, 0.14),
            width: 1,
          ),
        ),
        child: Image.asset(
          item.imagePath!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildImagePlaceholder(
              label: item.imageLabel,
              isTablet: isTablet,
            );
          },
        ),
      ),
    );
  }

  Widget _buildIntroPanel({required bool isTablet}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 18 : 14,
        vertical: isTablet ? 20 : 16,
      ),
      decoration: BoxDecoration(
        color: _a(Colors.white, 0.32),
        borderRadius: BorderRadius.circular(isTablet ? 18 : 16),
        border: Border.all(
          color: _a(AppTheme.headerInk, 0.12),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            '✦',
            textAlign: TextAlign.center,
            style: AppTheme.body.copyWith(
              fontSize: isTablet ? 14 : 12,
              color: _a(const Color(0xFF6A5876), 0.65),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '내일을 미리 기록하고\n오늘 다시 확인하는 타로일기',
            textAlign: TextAlign.center,
            style: AppTheme.body.copyWith(
              fontSize: isTablet ? 16.0 : 14.6,
              height: 1.55,
              color: _a(const Color(0xFF3A2147), 0.88),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '예상과 실제를 차곡차곡 쌓아가며\n나만의 흐름을 돌아볼 수 있어.',
            textAlign: TextAlign.center,
            style: AppTheme.body.copyWith(
              fontSize: isTablet ? 14.2 : 13.2,
              height: 1.55,
              color: _a(const Color(0xFF3A2147), 0.68),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '✦',
            textAlign: TextAlign.center,
            style: AppTheme.body.copyWith(
              fontSize: isTablet ? 14 : 12,
              color: _a(const Color(0xFF6A5876), 0.65),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback onTap,
    required bool isTablet,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: _a(const Color(0xFF7A63B0), 0.88),
          foregroundColor: _a(AppTheme.homeCream, 0.96),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isTablet ? 15 : 13),
            side: BorderSide(
              color: _a(AppTheme.headerInk, 0.18),
              width: 1,
            ),
          ),
          padding: EdgeInsets.symmetric(vertical: isTablet ? 14 : 12),
          minimumSize: Size.fromHeight(isTablet ? 52 : 48),
        ),
        child: Text(
          label,
          style: AppTheme.body.copyWith(
            fontSize: isTablet ? 14.5 : 14.0,
            fontWeight: FontWeight.w900,
            color: _a(AppTheme.homeCream, 0.96),
          ),
        ),
      ),
    );
  }

  Widget _buildTopContent({
    required _TutorialItem item,
    required bool isTablet,
  }) {
    switch (item.contentType) {
      case _TutorialContentType.intro:
        return Column(
          children: [
            _buildIntroPanel(isTablet: isTablet),
            const SizedBox(height: 18),
          ],
        );
      case _TutorialContentType.blogButton:
        return Column(
          children: [
            _buildPrimaryButton(
              label: '블로그로 바로 가기',
              onTap: _openBlog,
              isTablet: isTablet,
            ),
            const SizedBox(height: 18),
          ],
        );
      case _TutorialContentType.image:
        return Column(
          children: [
            _buildTutorialImage(
              item: item,
              isTablet: isTablet,
            ),
            const SizedBox(height: 16),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final width = mq.size.width;
    final height = mq.size.height;
    final isTablet = mq.size.shortestSide >= 600;
    final isShort = height < 700;

    final double sidePad = width < 360 ? 12 : (width < 430 ? 14 : 18);

    final contentW = LayoutTokens.contentW(context);
    final cardRadius = isTablet ? 22.0 : 18.0;
    final sectionPad = isTablet
        ? const EdgeInsets.fromLTRB(22, 26, 22, 24)
        : const EdgeInsets.fromLTRB(18, 24, 18, 20);

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: SafeArea(
        left: false,
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                sidePad,
                LayoutTokens.scrollTopPad,
                sidePad,
                0,
              ),
              child: SizedBox(
                height: 40,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(
                      child: Text(
                        '사용법',
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.title.copyWith(
                          color: _a(AppTheme.homeInkWarm, 0.96),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Transform.translate(
                        offset: const Offset(
                          LayoutTokens.backBtnNudgeX,
                          0,
                        ),
                        child: AppHeaderBackIconButton(
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Transform.translate(
                        offset: const Offset(0, 2),
                        child: AppHeaderHomeIconButton(
                          onTap: () => Navigator.of(context)
                              .pushNamedAndRemoveUntil('/', (r) => false),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: sidePad),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: contentW,
                    child: Column(
                      children: [
                        Expanded(
                          child: PageView.builder(
                            controller: _pageController,
                            onPageChanged: (index) {
                              final realIndex = index % _items.length;
                              if (_page == realIndex) return;
                              setState(() => _page = realIndex);
                            },
                            itemBuilder: (context, index) {
                              final realIndex = index % _items.length;
                              final item = _items[realIndex];

                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: _buildSectionCard(
                                  radius: cardRadius,
                                  padding: sectionPad,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 180),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: Text(
                                            item.title,
                                            key: ValueKey('title_$realIndex'),
                                            textAlign: TextAlign.center,
                                            style: AppTheme.body.copyWith(
                                              fontSize: isTablet ? 15.6 : 14.8,
                                              height: 1.3,
                                              color: _a(const Color(0xFF3A2147), 0.92),
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      Expanded(
                                        child: SingleChildScrollView(
                                          physics: const BouncingScrollPhysics(),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              _buildTopContent(
                                                item: item,
                                                isTablet: isTablet,
                                              ),
                                              SizedBox(
                                                width: double.infinity,
                                                child: Text(
                                                  item.body,
                                                  textAlign: TextAlign.center,
                                                  style: AppTheme.body.copyWith(
                                                    fontSize: isTablet ? 14.4 : 13.6,
                                                    height: 1.65,
                                                    color: _a(const Color(0xFF3A2147), 0.78),
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(height: isShort ? 12 : 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _items.length,
                                (i) => AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              curve: Curves.easeOutCubic,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: _page == i ? 18 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _a(
                                  AppTheme.homeInkWarm,
                                  _page == i ? 0.66 : 0.24,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: isShort ? 32 : 52),
                      ],
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

enum _TutorialContentType {
  intro,
  image,
  blogButton,
}

class _TutorialItem {
  final String title;
  final String body;
  final String imageLabel;
  final String? imagePath;
  final _TutorialContentType contentType;

  const _TutorialItem({
    required this.title,
    required this.body,
    required this.imageLabel,
    this.imagePath,
    this.contentType = _TutorialContentType.image,
  });
}