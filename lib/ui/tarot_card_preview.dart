// lib/ui/tarot_card_preview.dart
import 'dart:ui';
import 'package:flutter/material.dart';

class TarotCardPreview {
  /// 어디서든 호출:
  /// TarotCardPreview.open(context, assetPath: 'asset/cards/00-TheFool.png');
  static Future<void> open(
      BuildContext context, {
        required String assetPath,
        String? heroTag, // 있으면 Hero 애니메이션까지
      }) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'card-preview',
      barrierColor: Colors.black.withOpacity(0.55),
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
    // 바깥 탭하면 닫히게
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // ✅ 살짝 블러 + 탭 닫기
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: const SizedBox.expand(),
              ),
            ),
          ),

          // ✅ 카드 본체
          Center(
            child: GestureDetector(
              // 카드 자체를 누르면 닫히는 거 방지
              onTap: () {},
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  // 화면에서 너무 꽉 차지 않게
                  maxWidth: MediaQuery.of(context).size.width * 0.74,
                  maxHeight: MediaQuery.of(context).size.height * 0.78,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 24,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: _buildZoomableImage(context),
                  ),
                ),
              ),
            ),
          ),

          // ✅ 닫기 버튼(오른쪽 상단)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 14,
            child: _CloseButton(
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
    );

    final child = InteractiveViewer(
      minScale: 1.0,
      maxScale: 3.0,
      panEnabled: true,
      scaleEnabled: true,
      child: Center(child: image),
    );

    if (heroTag == null) return child;

    return Hero(
      tag: heroTag!,
      flightShuttleBuilder: (ctx, anim, __, ___, ____) {
        return FadeTransition(opacity: anim, child: image);
      },
      child: child,
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withOpacity(0.14), width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.close_rounded, size: 20, color: Colors.white),
        ),
      ),
    );
  }
}
