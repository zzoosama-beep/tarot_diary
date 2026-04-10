// lib/ui/tarot_card_preview.dart
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

class TarotCardPreview {
  static Future<void> open(
      BuildContext context, {
        required String assetPath,
        String? heroTag,
      }) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'card-preview',
      barrierColor: Colors.transparent, // 🔥 변경
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) {
        return _CardPreviewDialog(
          assetPath: assetPath,
          heroTag: heroTag,
        );
      },
      transitionBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOut);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}

class _CardPreviewDialog extends StatelessWidget {
  final String assetPath;
  final String? heroTag;

  const _CardPreviewDialog({
    required this.assetPath,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final shortest = media.size.shortestSide;
    final isTablet = shortest >= 600;

    final double closeButtonSize = isTablet ? 52 : 42;
    final double closeIconSize = isTablet ? 24 : 20;
    final double closeTop = media.padding.top + (isTablet ? 14 : 10);
    final double closeRight = isTablet ? 18 : 14;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // 🔥 블러 + 터치 닫기
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(
                  color: Colors.black.withOpacity(0.25), // 🔥 살짝만 어둡게
                ),
              ),
            ),
          ),

          // 카드
          Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxW = constraints.maxWidth;
                final maxH = constraints.maxHeight;

                final isLandscape = maxW > maxH;

                final horizontalMargin =
                isTablet ? 48 : isLandscape ? 24 : 20;

                final verticalMargin =
                isTablet ? 40 : isLandscape ? 20 : 28;

                final availableW =
                math.max(0, maxW - horizontalMargin * 2);
                final availableH =
                math.max(0, maxH - verticalMargin * 2);

                const cardAspectRatio = 0.58;

                double targetW;
                double targetH;

                if (isLandscape) {
                  targetH = availableH * (isTablet ? 0.88 : 0.84);
                  targetW = targetH * cardAspectRatio;

                  if (targetW > availableW * 0.72) {
                    targetW = availableW * 0.72;
                    targetH = targetW / cardAspectRatio;
                  }
                } else {
                  targetW = availableW * (isTablet ? 0.60 : 0.78);
                  targetH = targetW / cardAspectRatio;

                  if (targetH > availableH * 0.86) {
                    targetH = availableH * 0.86;
                    targetW = targetH * cardAspectRatio;
                  }
                }

                final finalW =
                targetW.clamp(180.0, isTablet ? 420.0 : 340.0);
                final finalH =
                targetH.clamp(300.0, isTablet ? 720.0 : 620.0);

                return SizedBox(
                  width: finalW,
                  height: finalH,
                  child: ClipRRect(
                    borderRadius:
                    BorderRadius.circular(isTablet ? 22 : 16),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: isTablet ? 30 : 24,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: AspectRatio(
                        aspectRatio: cardAspectRatio,
                        child: _buildZoomableImage(context),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 닫기 버튼
          Positioned(
            top: closeTop,
            right: closeRight,
            child: _CloseButton(
              size: closeButtonSize,
              iconSize: closeIconSize,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoomableImage(BuildContext context) {
    final image = Image.asset(
      assetPath,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      cacheWidth: 600,
    );

    final child = InteractiveViewer(
      minScale: 1.0,
      maxScale: 3.2,
      boundaryMargin: const EdgeInsets.all(24),
      child: SizedBox.expand(
        child: Center(child: image),
      ),
    );

    if (heroTag == null) return child;

    return Hero(
      tag: heroTag!,
      child: child,
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  const _CloseButton({
    required this.onTap,
    required this.size,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(size * 0.3),
        side: BorderSide(
          color: Colors.white.withOpacity(0.14),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size * 0.3),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            Icons.close_rounded,
            size: iconSize,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}