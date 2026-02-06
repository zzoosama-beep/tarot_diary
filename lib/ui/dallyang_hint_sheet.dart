import 'package:flutter/material.dart';

class DallyangHintSheet {
  DallyangHintSheet._();

  static Future<void> open(
      BuildContext context, {
        required List<String> cardNames,
        required String hintText,
        VoidCallback? onAppendStarterToBefore,
      }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final viewInsetB = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + viewInsetB),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF332B57).withOpacity(0.96),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.pets_rounded, size: 18, color: Color(0xFFD4AF37)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('달냥이의 해석 힌트',
                            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: Colors.white)),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: Icon(Icons.close_rounded, color: Colors.white.withOpacity(0.7)),
                        splashRadius: 18,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: cardNames
                          .map((t) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4AF37).withOpacity(0.10),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.25)),
                        ),
                        child: Text(t,
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white)),
                      ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Text(
                      hintText,
                      style: TextStyle(fontSize: 13.3, height: 1.38, color: Colors.white.withOpacity(0.85)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (onAppendStarterToBefore != null)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          onAppendStarterToBefore();
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.add_circle_outline, size: 16),
                        label: const Text('Before에 문장 스타터 붙이기'),
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
}
