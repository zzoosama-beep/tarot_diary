import 'package:flutter/material.dart';

Future<void> showDalnyangErrorDialog(
    BuildContext context, {
      required String message,
    }) {
  final msg = _visibleMessage(message);

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
          constraints: const BoxConstraints(
            maxHeight: 240,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      msg,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
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

String _visibleMessage(String message) {
  final s = message.trim();

  final idx = s.indexOf('\n---\n');
  if (idx >= 0) {
    return s.substring(0, idx).trim();
  }

  return s;
}