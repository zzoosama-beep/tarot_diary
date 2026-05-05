// lib/backend/auth_service.dart
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../error/error_reporter.dart';

class AuthService {
  AuthService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static final GoogleSignIn _google = GoogleSignIn(
    scopes: <String>[
      'email',
      'https://www.googleapis.com/auth/drive.appdata',
    ],
  );

  static User? _normalizeUser(User? u) {
    if (u == null) return null;
    if (u.isAnonymous) return null;
    return u;
  }

  static User? get currentUser => _normalizeUser(_auth.currentUser);

  static bool get isSignedIn => currentUser != null;

  /// UI에서는 이 스트림 기준으로 로그인 상태를 보는 것을 권장합니다.
  static Stream<User?> authStateChanges() {
    return _auth.idTokenChanges().map(_normalizeUser);
  }

  /// 앱 시작 시 조용히 세션을 동기화합니다.
  ///
  /// - FirebaseAuth 세션은 원래 자체 복원됩니다.
  /// - 하지만 GoogleSignIn.currentUser 는 앱 재실행 후 비어 있을 수 있어
  ///   Drive accessToken 사용 시 signInSilently가 도움이 됩니다.
  static Future<void> restoreSessionSilently() async {
    try {
      await _google.signInSilently().catchError((_) => null);
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'AuthService.restoreSessionSilently',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// 로그인 보장
  ///
  /// - 이미 로그인되어 있으면 그대로 둡니다.
  /// - 아니면 Google 로그인을 진행합니다.
  ///
  /// forceAccountChooser:
  /// - 계정 선택을 다시 유도하고 싶을 때 사용
  ///
  /// hardDisconnect:
  /// - 기존 Google 세션을 강제로 정리한 뒤 다시 로그인
  /// - 일반적인 로그인 버튼에서는 false 권장
  static Future<UserCredential?> ensureSignedIn({
    bool forceAccountChooser = false,
    bool hardDisconnect = false,
  }) async {
    if (isSignedIn && !hardDisconnect) {
      await restoreSessionSilently();
      return null;
    }

    try {
      if (hardDisconnect || forceAccountChooser) {
        await _google.signOut().catchError((_) {});
        await _google.disconnect().catchError((_) {});
      }

      GoogleSignInAccount? account;

      if (!hardDisconnect && !forceAccountChooser) {
        account = await _google.signInSilently();
      }

      account ??= await _google.signIn();

      if (account == null) {
        throw Exception('로그인을 취소하셨습니다.');
      }

      final GoogleSignInAuthentication auth = await account.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);

      await restoreSessionSilently();

      return result;
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
      await _google.signOut().catchError((_) {});

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
      final u = currentUser;
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