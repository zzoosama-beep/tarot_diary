// lib/backend/auth_service.dart
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _google = GoogleSignIn();

  static User? get currentUser => _auth.currentUser;

  /// ✅ "로그인되어있다"의 정의: 익명 아니고, provider가 붙어있는 계정
  static bool get isSignedIn {
    final u = _auth.currentUser;
    if (u == null) return false;
    if (u.isAnonymous) return false;
    return true;
  }

  static Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// ✅ 로그인 보장
  /// - 이미 로그인되어있으면 그대로
  /// - 아니면 구글 로그인 진행
  ///
  /// forceAccountChooser=true면 계정 선택창을 최대한 띄우려는 의도
  /// hardDisconnect=true면 기존 구글 세션을 끊고 새로 선택 유도
  static Future<UserCredential?> ensureSignedIn({
    bool forceAccountChooser = false,
    bool hardDisconnect = false,
  }) async {
    if (isSignedIn) return null;

    if (hardDisconnect) {
      // 강제 계정 선택 유도를 위해 세션을 끊어줌
      await _google.signOut();
      await _google.disconnect().catchError((_) {});
    }

    // forceAccountChooser가 true라도 플랫폼/상태에 따라 항상 뜨진 않을 수 있음
    final GoogleSignInAccount? account = await _google.signIn();
    if (account == null) {
      // 유저가 로그인 취소
      throw Exception('로그인을 취소했어.');
    }

    final GoogleSignInAuthentication auth = await account.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );

    return _auth.signInWithCredential(credential);
  }

  static Future<void> signOut({bool hardDisconnect = false}) async {
    await _auth.signOut();
    await _google.signOut();
    if (hardDisconnect) {
      await _google.disconnect().catchError((_) {});
    }
  }

  static Future<String> getIdTokenOrThrow({bool forceRefresh = false}) async {
    final u = _auth.currentUser;
    if (u == null) throw Exception('로그인이 필요해.');

    final String? token = await u.getIdToken(forceRefresh);
    if (token == null || token.trim().isEmpty) {
      throw Exception('idToken을 가져오지 못했어.');
    }
    return token;
  }
}
