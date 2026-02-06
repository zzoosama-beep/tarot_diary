import 'package:flutter/material.dart';
import '../backend/auth_service.dart';

/// ✅ B안: "액션 시 로그인 필요"를 위한 공용 게이트
/// - 이미 로그인(익명X)이면 true
/// - 아니면 바텀시트 띄워서 로그인 시도
/// - 성공하면 true / 취소 or 실패면 false
Future<bool> requireGoogleLogin(
    BuildContext context, {
      String title = '로그인이 필요해',
      String message = '로그인하면 기기 변경/재설치 후에도 데이터를 안전하게 사용할 수 있어.',
    }) async {
  if (AuthService.isSignedIn) return true;

  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: false,
    backgroundColor: Colors.transparent,
    builder: (_) => _LoginBottomSheet(title: title, message: message),
  );

  return result == true;
}

class _LoginBottomSheet extends StatefulWidget {
  final String title;
  final String message;

  const _LoginBottomSheet({
    required this.title,
    required this.message,
  });

  @override
  State<_LoginBottomSheet> createState() => _LoginBottomSheetState();
}

class _LoginBottomSheetState extends State<_LoginBottomSheet> {
  bool _loading = false;
  String? _err;

  Color _a(Color c, double o) => c.withAlpha((o * 255).round());

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1B2E),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _a(Colors.white, 0.08)),
          boxShadow: [
            BoxShadow(
              color: _a(Colors.black, 0.35),
              blurRadius: 18,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFFF3EDE0),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: _a(const Color(0xFFF3EDE0), 0.80),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            if (_err != null) ...[
              Text(
                _err!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _a(Colors.redAccent, 0.90),
                  fontSize: 12.5,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
            ],

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading ? null : () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _a(const Color(0xFFF3EDE0), 0.92),
                      side: BorderSide(color: _a(Colors.white, 0.18)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : _doLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _a(const Color(0xFFD4AF37), 0.22),
                      foregroundColor: _a(const Color(0xFFF3EDE0), 0.95),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: _a(const Color(0xFFD4AF37), 0.55)),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Text(
                      '구글 로그인',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _doLogin() async {
    setState(() {
      _loading = true;
      _err = null;
    });

    try {
      // ✅ 핵심: signInWithGoogle() 직접 호출 X
      // -> ensureSignedIn()이 익명 세션 정리까지 포함해서 "로그인 보장"
      await AuthService.ensureSignedIn();

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = _prettyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _prettyError(Object e) {
    final s = e.toString();

    // 사용자가 취소
    if (s.contains('취소')) return '로그인을 취소했어.';

    // 흔한 케이스들 부드럽게
    if (s.contains('network_error') || s.contains('NETWORK')) {
      return '네트워크가 불안정해. 인터넷 연결을 확인해줘.';
    }
    if (s.contains('sign_in_failed')) {
      return '구글 로그인에 실패했어. 잠시 후 다시 시도해줘.';
    }

    // 너무 길면 자르기
    if (s.length > 140) return s.substring(0, 140) + '…';
    return s;
  }
}
