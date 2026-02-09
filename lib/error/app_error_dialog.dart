import 'package:flutter/material.dart';

Future<void> showDalnyangErrorDialog(
    BuildContext context, {
      required String exceptionMessage,
      bool showDebug = true, // true면 디버그 포함(Unknown)
    }) {
  final msg = _visibleMessage(exceptionMessage, showDebug: showDebug);

  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: ConstrainedBox(
          // ✅ Known(짧음)일 땐 더 작게, Unknown(길 수 있음)만 크게
          constraints: BoxConstraints(
            maxHeight: showDebug ? 340 : 220,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min, // ✅ 내용만큼만
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: const [
                    Icon(Icons.pets_rounded, size: 18),
                    SizedBox(width: 6),
                    Text(
                      '달냥이 안내',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Message (짧으면 그냥, 길면 스크롤)
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      msg,
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ),
                ),

                // ✅ Known이면 Divider/푸터 자체를 없앰 (중복 느낌 제거)
                if (showDebug) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  const Text(
                    '문제가 계속되면 문의해줘!',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: Colors.grey,
                    ),
                  ),
                ],

                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('닫기'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

String _visibleMessage(String exceptionMessage, {required bool showDebug}) {
  final s = exceptionMessage.trim();
  if (showDebug) return s;

  final idx = s.indexOf('\n---\n');
  if (idx >= 0) return s.substring(0, idx).trim();
  return s;
}
