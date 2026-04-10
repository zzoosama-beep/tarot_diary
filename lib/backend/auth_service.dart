// lib/backend/auth_service.dart
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../error/error_reporter.dart';

class AuthService {
  AuthService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Drive appData 권한까지 같이 요청합니다.
  static final GoogleSignIn _google = GoogleSignIn(
    scopes: <String>[
      'email',
      'https://www.googleapis.com/auth/drive.appdata',
    ],
  );

  static User? get currentUser => _auth.currentUser;

  /// 로그인 상태의 기준:
  /// - currentUser가 있고
  /// - 익명 계정이 아니면 로그인 상태로 봅니다.
  static bool get isSignedIn {
    final u = _auth.currentUser;
    if (u == null) return false;
    if (u.isAnonymous) return false;
    return true;
  }

  static Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// 로그인 보장
  /// - 이미 로그인되어 있으면 그대로 둡니다.
  /// - 아니면 Google 로그인을 진행합니다.
  ///
  /// forceAccountChooser:
  /// - 현재 구현에서는 하위 옵션과 직접 연결되지는 않지만,
  ///   호출 의도를 보존하기 위해 유지합니다.
  ///
  /// hardDisconnect:
  /// - 기존 Google 세션을 끊고 다시 계정 선택을 유도합니다.
  static Future<UserCredential?> ensureSignedIn({
    bool forceAccountChooser = false,
    bool hardDisconnect = false,
  }) async {
    if (isSignedIn) return null;

    try {
      if (hardDisconnect) {
        await _google.signOut();
        await _google.disconnect().catchError((_) {});
      }

      final GoogleSignInAccount? account = await _google.signIn();
      if (account == null) {
        throw Exception('로그인을 취소하셨습니다.');
      }

      final GoogleSignInAuthentication auth = await account.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'AuthService.ensureSignedIn',
        error: e,
        stackTrace: st,
        extra: {
          'forceAccountChooser': forceAccountChooser,
          'hardDisconnect': hardDisconnect,
        },
      );

      rethrow;
    }
  }

  static Future<void> signOut({bool hardDisconnect = false}) async {
    try {
      await _auth.signOut();
      await _google.signOut();

      if (hardDisconnect) {
        await _google.disconnect().catchError((_) {});
      }
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'AuthService.signOut',
        error: e,
        stackTrace: st,
        extra: {
          'hardDisconnect': hardDisconnect,
        },
      );

      rethrow;
    }
  }

  static Future<String> getIdTokenOrThrow({bool forceRefresh = false}) async {
    try {
      final u = _auth.currentUser;
      if (u == null) {
        throw Exception('로그인이 필요합니다.');
      }

      final String? token = await u.getIdToken(forceRefresh);
      if (token == null || token.trim().isEmpty) {
        throw Exception('로그인 토큰을 가져오지 못했습니다.');
      }

      return token;
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'AuthService.getIdTokenOrThrow',
        error: e,
        stackTrace: st,
        extra: {
          'forceRefresh': forceRefresh,
        },
      );

      rethrow;
    }
  }

  /// Drive API 호출용 accessToken이 필요할 때 사용합니다.
  static Future<String> getGoogleAccessTokenOrThrow() async {
    try {
      GoogleSignInAccount? account = _google.currentUser;

      account ??= await _google.signInSilently();

      if (account == null) {
        throw Exception('구글 로그인이 필요합니다.');
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      final accessToken = auth.accessToken;

      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('Google accessToken을 가져오지 못했습니다.');
      }

      return accessToken;
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'AuthService.getGoogleAccessTokenOrThrow',
        error: e,
        stackTrace: st,
      );

      rethrow;
    }
  }
}