import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../backup/drive_backup_service.dart';
import '../error/error_reporter.dart';
import 'arcana_local.dart';
import 'diary_local.dart';
import 'auth_service.dart';

class AccountDeleteResult {
  final bool success;
  final String message;

  const AccountDeleteResult({
    required this.success,
    required this.message,
  });
}

class AccountDeleteService {
  AccountDeleteService._();
  static final AccountDeleteService I = AccountDeleteService._();

  Future<AccountDeleteResult> deleteAccountAndLocalData() async {
    try {
      // 1) Drive 백업 파일 전체 삭제
      await _deleteRemoteBackupFiles();

      // 2) 로컬 DB 연결 종료
      await _closeLocalDatabases();

      // 3) 실제 SQLite 파일 삭제
      await _deleteLocalDatabaseFile();

      // 4) Firebase / Google 계정 정리
      await _deleteOrSignOutAuth();

      // 5) SharedPreferences 정리
      await _clearPrefs();

      return const AccountDeleteResult(
        success: true,
        message: '계정과 기기 데이터, Google Drive 백업이 모두 삭제되었습니다.',
      );
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'AccountDeleteService.deleteAccountAndLocalData',
        error: e,
        stackTrace: st,
      );

      return const AccountDeleteResult(
        success: false,
        message: '계정 삭제 중 문제가 발생했습니다. 잠시 후 다시 시도해주세요.',
      );
    }
  }

  Future<void> _deleteRemoteBackupFiles() async {
    try {
      await DriveBackupService.I.deleteAllRemoteBackupFiles(
        interactiveIfNeeded: true,
      );
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'AccountDeleteService._deleteRemoteBackupFiles',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> _closeLocalDatabases() async {
    try {
      await ArcanaLocal.instance.close();
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'AccountDeleteService._closeLocalDatabases.arcana',
        error: e,
        stackTrace: st,
      );
    }

    try {
      await DiaryLocal.instance.close();
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'AccountDeleteService._closeLocalDatabases.diary',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _deleteLocalDatabaseFile() async {
    final dbPath = await DiaryLocal.instance.getDbPath();
    await deleteDatabase(dbPath);
  }

  Future<void> _deleteOrSignOutAuth() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        await user.delete();
      } catch (e, st) {
        await ErrorReporter.I.record(
          source: 'AccountDeleteService._deleteOrSignOutAuth.userDelete',
          error: e,
          stackTrace: st,
        );
      }
    }

    try {
      await AuthService.signOut(hardDisconnect: true);
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'AccountDeleteService._deleteOrSignOutAuth.signOut',
        error: e,
        stackTrace: st,
      );
    }

    try {
      await DriveBackupService.I.disconnect();
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'AccountDeleteService._deleteOrSignOutAuth.driveDisconnect',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _clearPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}