// lib/backend/auth_service.dart
import 'dart:developer' as dev;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static User? get currentUser => _auth.currentUser;

  /// UI에서 상태 표시/감지용
  static Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// ✅ "로그인되어있다"의 정의:
  /// - user != null
  /// - 익명 계정 아님
  /// - providerData에 최소 1개
  /// - 그리고 (정책상) google.com 연결 필수
  static bool get isSignedIn {
    final u = _auth.currentUser;
    if (u == null) return false;
    if (u.isAnonymous) return false;

    // providerData가 비어있으면 "제대로 연결된 로그인"으로 보기 애매해서 false
    if (u.providerData.isEmpty) return false;

    // 지금 정책은 "구글 로그인만"이니까 google.com이 있어야 true
    final hasGoogle = u.providerData.any((p) => p.providerId == 'google.com');
    return hasGoogle;
  }

  /// ✅ 액션 진입 전에 "로그인 보장"
  /// - 이미 정상 구글 로그인 상태면 그대로 반환
  /// - 아니면 구글 로그인 시도
  ///
  /// [forceAccountChooser]
  /// - true면 매번 계정선택 UI를 띄우도록 구글 세션을 먼저 정리
  /// [hardDisconnect]
  /// - true면 signOut보다 더 강하게 disconnect()도 시도
  static Future<User> ensureSignedIn({
    bool forceAccountChooser = true,
    bool hardDisconnect = false,
  }) async {
    final u = _auth.currentUser;

    if (isSignedIn) return u!;

    // 익명 세션이 남아있거나 providerData가 이상하면 정리하고 시작
    if (u != null) {
      await signOut(hardDisconnect: hardDisconnect);
    }

    final cred = await signInWithGoogle(
      forceAccountChooser: forceAccountChooser,
      hardDisconnect: hardDisconnect,
    );

    final user = cred.user;
    if (user == null) throw Exception('로그인에 실패했어. (user=null)');

    // providerData 반영이 늦게 오는 경우가 있어 한 번 refresh
    await user.reload();
    return _auth.currentUser ?? user;
  }

  /// ✅ 구글 로그인
  /// [forceAccountChooser] = true면 기존 구글 세션을 끊어 계정 선택을 유도
  /// [hardDisconnect] = true면 disconnect()까지 시도(세션 꼬임 방지 강화)
  static Future<UserCredential> signInWithGoogle({
    bool forceAccountChooser = false,
    bool hardDisconnect = false,
  }) async {
    final google = GoogleSignIn();

    if (forceAccountChooser) {
      try {
        await google.signOut();
        if (hardDisconnect) {
          await google.disconnect();
        }
      } catch (e) {
        // 세션 정리 실패해도 로그인 시도는 진행
        dev.log('Google session cleanup failed: $e', name: 'AuthService');
      }
    }

    final GoogleSignInAccount? googleUser = await google.signIn();
    if (googleUser == null) {
      throw Exception('로그인을 취소했어.');
    }

    final GoogleSignInAuthentication googleAuth =
    await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final result = await _auth.signInWithCredential(credential);

    // 로그인 직후 상태 동기화
    await result.user?.reload();

    return result;
  }

  /// Firebase + Google 세션 함께 로그아웃
  static Future<void> signOut({bool hardDisconnect = false}) async {
    final google = GoogleSignIn();

    try {
      await google.signOut();
      if (hardDisconnect) {
        await google.disconnect();
      }
    } catch (e) {
      dev.log('Google signOut/disconnect failed: $e', name: 'AuthService');
    }

    await _auth.signOut();
  }

  /// 서버 호출에 쓸 Firebase ID 토큰
  static Future<String?> getIdToken({bool forceRefresh = false}) async {
    final u = _auth.currentUser;
    if (u == null) return null;
    return u.getIdToken(forceRefresh);
  }

  /// 디버깅용: 현재 로그인 상태 문자열
  static String debugSummary() {
    final u = _auth.currentUser;
    if (u == null) return 'AUTH: null';
    final providers = u.providerData.map((e) => e.providerId).join(',');
    return 'AUTH: uid=${u.uid}, anon=${u.isAnonymous}, email=${u.email ?? '-'}, providers=[$providers]';
  }
}
