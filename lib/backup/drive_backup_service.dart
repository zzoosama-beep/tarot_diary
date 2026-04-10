import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart' as auth show AuthClient;
import 'package:shared_preferences/shared_preferences.dart';

import '../backend/arcana_repo.dart';
import '../backend/diary_repo.dart';
import '../error/error_reporter.dart';
import 'backup_exporter.dart';
import 'backup_models.dart';

class DriveBackupService {
  DriveBackupService._();
  static final DriveBackupService I = DriveBackupService._();

  static const String _kDriveAppDataScope =
      'https://www.googleapis.com/auth/drive.appdata';

  static const String _prefsEnabledKey = 'google_drive_backup_enabled';
  static const String _prefsLastBackupAtKey = 'google_drive_last_backup_at';
  static const String _prefsLastBackupSuccessAtKey =
      'google_drive_last_backup_success_at';
  static const String _prefsLastRestoreAtKey = 'google_drive_last_restore_at';
  static const String _prefsLastBackupEmailKey =
      'google_drive_last_backup_email';

  static const String _prefsPendingBackupKey = 'google_drive_pending_backup';
  static const String _prefsPendingBackupChangedAtKey =
      'google_drive_pending_backup_changed_at';

  static const Duration _autoBackupDebounce = Duration(seconds: 2);

  final GoogleSignIn _signIn = GoogleSignIn(
    scopes: const <String>[
      _kDriveAppDataScope,
      'email',
    ],
  );

  Future<DriveBackupResult>? _runningBackup;
  Timer? _autoBackupTimer;
  bool _autoBackupScheduled = false;

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsEnabledKey) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsEnabledKey, value);
  }

  Future<int?> getLastBackupAt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefsLastBackupAtKey);
  }

  Future<int?> getLastBackupSuccessAt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefsLastBackupSuccessAtKey);
  }

  Future<int?> getLastRestoreAt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefsLastRestoreAtKey);
  }

  Future<String?> getLastBackupEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsLastBackupEmailKey);
  }

  Future<bool> hasPendingBackup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsPendingBackupKey) ?? false;
  }

  Future<int?> getPendingBackupChangedAt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefsPendingBackupChangedAtKey);
  }

  Future<void> markDirty() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsPendingBackupKey, true);
    await prefs.setInt(
      _prefsPendingBackupChangedAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> clearDirty() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsPendingBackupKey, false);
    await prefs.remove(_prefsPendingBackupChangedAtKey);
  }

  Future<String?> currentSignedInEmail() async {
    try {
      final account = _signIn.currentUser ?? await _signIn.signInSilently();
      return account?.email;
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DriveBackupService.currentSignedInEmail',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  Future<void> disconnect() async {
    try {
      _cancelAutoBackupTimer();
      await _signIn.disconnect();
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DriveBackupService.disconnect',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<bool> ensureAuthorized() async {
    final client = await _getAuthClient(interactiveIfNeeded: true);
    if (client == null) return false;
    client.close();
    return true;
  }

  Future<void> notifyDataChanged() async {
    try {
      await markDirty();

      final enabled = await isEnabled();
      if (!enabled) return;

      _scheduleAutoBackup();
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DriveBackupService.notifyDataChanged',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<int> deleteAllRemoteBackupFiles({
    bool interactiveIfNeeded = true,
  }) async {
    final auth.AuthClient? client = await _getAuthClient(
      interactiveIfNeeded: interactiveIfNeeded,
    );

    if (client == null) {
      throw const BackupException(
        'Google 로그인 또는 Drive 권한 인증이 필요합니다.\n다시 시도해주세요.',
      );
    }

    try {
      final api = drive.DriveApi(client);

      final targets = <String>[
        kBackupManifestFileName,
        kBackupDiaryFileName,
        kBackupArcanaFileName,
        kBackupSettingsFileName,
      ];

      int deletedCount = 0;

      for (final fileName in targets) {
        final deleted = await _deleteFileByNameIfExists(
          api: api,
          fileName: fileName,
        );
        if (deleted) {
          deletedCount += 1;
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsLastBackupAtKey);
      await prefs.remove(_prefsLastBackupSuccessAtKey);
      await prefs.remove(_prefsLastRestoreAtKey);
      await prefs.remove(_prefsLastBackupEmailKey);
      await prefs.remove(_prefsEnabledKey);

      await clearDirty();
      _cancelAutoBackupTimer();

      return deletedCount;
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DriveBackupService.deleteAllRemoteBackupFiles',
        error: e,
        stackTrace: st,
      );

      if (e is BackupException) rethrow;

      throw const BackupException(
        'Google Drive 백업 삭제 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      );
    } finally {
      client.close();
    }
  }

  Future<bool> _deleteFileByNameIfExists({
    required drive.DriveApi api,
    required String fileName,
  }) async {
    try {
      final existing = await _findFileByName(
        api: api,
        fileName: fileName,
      );

      if (existing == null || existing.id.isEmpty) {
        return false;
      }

      await api.files.delete(existing.id);
      return true;
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DriveBackupService._deleteFileByNameIfExists',
        error: e,
        stackTrace: st,
        extra: {'fileName': fileName},
      );

      throw const BackupException(
        'Drive 백업 파일을 삭제하는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      );
    }
  }

  void _scheduleAutoBackup() {
    _autoBackupTimer?.cancel();

    _autoBackupScheduled = true;
    _autoBackupTimer = Timer(_autoBackupDebounce, () {
      unawaited(_runScheduledAutoBackup());
    });
  }

  void _cancelAutoBackupTimer() {
    _autoBackupTimer?.cancel();
    _autoBackupTimer = null;
    _autoBackupScheduled = false;
  }

  Future<void> _runScheduledAutoBackup() async {
    _autoBackupTimer = null;

    if (!_autoBackupScheduled) return;
    _autoBackupScheduled = false;

    try {
      await backupIfNeeded(
        includeSettings: true,
        interactiveIfNeeded: false,
      );
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DriveBackupService._runScheduledAutoBackup',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<DriveBackupResult> backupIfNeeded({
    bool includeSettings = true,
    bool interactiveIfNeeded = false,
  }) async {
    try {
      final enabled = await isEnabled();
      if (!enabled) {
        final now = DateTime.now().millisecondsSinceEpoch;
        return DriveBackupResult(
          success: false,
          startedAt: now,
          finishedAt: now,
          uploadedFileCount: 0,
          message: '백업 기능이 꺼져 있습니다.',
          skipped: true,
        );
      }

      final pending = await hasPendingBackup();
      if (!pending) {
        final now = DateTime.now().millisecondsSinceEpoch;
        return DriveBackupResult(
          success: false,
          startedAt: now,
          finishedAt: now,
          uploadedFileCount: 0,
          message: '추가로 백업할 데이터가 없습니다.',
          skipped: true,
        );
      }

      final client = await _getAuthClient(
        interactiveIfNeeded: interactiveIfNeeded,
      );
      if (client == null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        return DriveBackupResult(
          success: false,
          startedAt: now,
          finishedAt: now,
          uploadedFileCount: 0,
          message: '로그인 또는 Drive 인증 상태를 확인하지 못했습니다.',
          skipped: true,
        );
      }
      client.close();

      return backupNow(
        includeSettings: includeSettings,
        interactiveIfNeeded: interactiveIfNeeded,
      );
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DriveBackupService.backupIfNeeded',
        error: e,
        stackTrace: st,
      );

      final now = DateTime.now().millisecondsSinceEpoch;
      return DriveBackupResult(
        success: false,
        startedAt: now,
        finishedAt: now,
        uploadedFileCount: 0,
        message: '백업 확인 중 문제가 발생했습니다.',
        skipped: true,
      );
    }
  }

  Future<DriveBackupResult> backupNow({
    bool includeSettings = true,
    bool interactiveIfNeeded = true,
  }) async {
    final running = _runningBackup;
    if (running != null) {
      return running;
    }

    final future = _backupNowImpl(
      includeSettings: includeSettings,
      interactiveIfNeeded: interactiveIfNeeded,
    );
    _runningBackup = future;

    try {
      return await future;
    } finally {
      if (identical(_runningBackup, future)) {
        _runningBackup = null;
      }
    }
  }

  Future<DriveBackupResult> _backupNowImpl({
    required bool includeSettings,
    required bool interactiveIfNeeded,
  }) async {
    final startedAt = DateTime.now().millisecondsSinceEpoch;
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt(_prefsLastBackupAtKey, startedAt);

    final diaryRows = await DiaryRepo.I.exportAllForBackup();
    final arcanaRows = await ArcanaRepo.I.exportAllForBackup();

    if (diaryRows.isEmpty && arcanaRows.isEmpty) {
      throw const BackupException(
        '현재 저장된 데이터가 없어 백업할 수 없습니다.\n기존 백업을 덮어쓸 수 있으니 먼저 복원 여부를 확인해주세요.',
      );
    }

    final auth.AuthClient? client = await _getAuthClient(
      interactiveIfNeeded: interactiveIfNeeded,
    );

    if (client == null) {
      throw BackupException(
        interactiveIfNeeded
            ? 'Google 로그인 또는 Drive 권한 인증이 필요합니다.\n다시 시도해주세요.'
            : 'Google 인증 상태를 확인하지 못했습니다.',
      );
    }

    try {
      final api = drive.DriveApi(client);
      final files = await BackupExporter.exportFileMap(
        includeSettings: includeSettings,
      );

      int uploaded = 0;
      for (final entry in files.entries) {
        await _upsertJsonFile(
          api: api,
          fileName: entry.key,
          jsonString: entry.value,
          backupKind: _kindForFileName(entry.key),
        );
        uploaded += 1;
      }

      final finishedAt = DateTime.now().millisecondsSinceEpoch;
      final email = _signIn.currentUser?.email;

      await prefs.setInt(_prefsLastBackupSuccessAtKey, finishedAt);
      if (email != null && email.isNotEmpty) {
        await prefs.setString(_prefsLastBackupEmailKey, email);
      }

      await clearDirty();

      return DriveBackupResult(
        success: true,
        startedAt: startedAt,
        finishedAt: finishedAt,
        uploadedFileCount: uploaded,
        message: '지금 백업이 완료되었습니다.',
      );
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DriveBackupService._backupNowImpl',
        error: e,
        stackTrace: st,
      );

      if (e is BackupException) rethrow;

      throw const BackupException(
        'Drive 백업 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      );
    } finally {
      client.close();
    }
  }

  Future<bool> hasRemoteBackup() async {
    final client = await _getAuthClient(interactiveIfNeeded: false);
    if (client == null) return false;

    try {
      final api = drive.DriveApi(client);
      final file = await _findFileByName(
        api: api,
        fileName: kBackupManifestFileName,
      );
      return file != null;
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DriveBackupService.hasRemoteBackup',
        error: e,
        stackTrace: st,
      );
      return false;
    } finally {
      client.close();
    }
  }

  Future<BackupManifest?> loadRemoteManifest() async {
    try {
      final remote = await downloadRemoteBackup(
        includeDiary: false,
        includeArcana: false,
        includeSettings: false,
      );
      return remote?.manifest;
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DriveBackupService.loadRemoteManifest',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<RemoteBackupData?> downloadRemoteBackup({
    bool includeDiary = true,
    bool includeArcana = true,
    bool includeSettings = true,
  }) async {
    final auth.AuthClient? client =
    await _getAuthClient(interactiveIfNeeded: true);
    if (client == null) {
      throw const BackupException(
        'Google 로그인 또는 Drive 권한 인증이 필요합니다.\n다시 시도해주세요.',
      );
    }

    try {
      final api = drive.DriveApi(client);

      final manifestText = await _readJsonFileByName(
        api: api,
        fileName: kBackupManifestFileName,
      );
      if (manifestText == null || manifestText.trim().isEmpty) {
        return null;
      }

      final manifest = BackupManifest.decode(manifestText);

      String? diaryText;
      String? arcanaText;
      String? settingsText;

      if (includeDiary) {
        diaryText = await _readJsonFileByName(
          api: api,
          fileName: kBackupDiaryFileName,
        );
      }

      if (includeArcana) {
        arcanaText = await _readJsonFileByName(
          api: api,
          fileName: kBackupArcanaFileName,
        );
      }

      if (includeSettings) {
        settingsText = await _readJsonFileByName(
          api: api,
          fileName: kBackupSettingsFileName,
        );
      }

      final diaries = _decodeDiaryItems(diaryText);
      final arcanaNotes = _decodeArcanaItems(arcanaText);
      final settings = _decodeSettings(settingsText);

      return RemoteBackupData(
        manifest: manifest,
        diaries: diaries,
        arcanaNotes: arcanaNotes,
        settings: settings,
        rawManifestJson: manifestText,
        rawDiaryJson: diaryText,
        rawArcanaJson: arcanaText,
        rawSettingsJson: settingsText,
      );
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DriveBackupService.downloadRemoteBackup',
        error: e,
        stackTrace: st,
      );

      if (e is BackupException) rethrow;

      throw const BackupException(
        '원격 백업을 불러오는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      );
    } finally {
      client.close();
    }
  }

  Future<auth.AuthClient?> _getAuthClient({
    required bool interactiveIfNeeded,
  }) async {
    try {
      GoogleSignInAccount? account = _signIn.currentUser;
      account ??= await _signIn.signInSilently();

      if (account == null && interactiveIfNeeded) {
        account = await _signIn.signIn();
      }

      if (account == null) return null;

      final client = await _signIn.authenticatedClient();
      return client;
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DriveBackupService._getAuthClient',
        error: e,
        stackTrace: st,
        extra: {
          'interactiveIfNeeded': interactiveIfNeeded,
        },
      );
      return null;
    }
  }

  Future<DriveFileInfo?> _findFileByName({
    required drive.DriveApi api,
    required String fileName,
  }) async {
    try {
      final escaped = _escapeQueryValue(fileName);

      final res = await api.files.list(
        spaces: 'appDataFolder',
        q: "name = '$escaped'",
        orderBy: 'modifiedTime desc',
        $fields: 'files(id,name,modifiedTime,size,appProperties,mimeType)',
      );

      final files = res.files ?? const <drive.File>[];
      if (files.isEmpty) return null;

      final f = files.first;
      return DriveFileInfo(
        id: f.id ?? '',
        name: f.name ?? '',
        mimeType: f.mimeType,
        modifiedTimeIso: f.modifiedTime?.toIso8601String(),
        size: _safeInt64ToInt(f.size),
        appProperties: f.appProperties == null
            ? const <String, String>{}
            : Map<String, String>.from(f.appProperties!),
      );
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DriveBackupService._findFileByName',
        error: e,
        stackTrace: st,
        extra: {'fileName': fileName},
      );

      throw const BackupException(
        'Drive 파일을 조회하는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      );
    }
  }

  Future<void> _upsertJsonFile({
    required drive.DriveApi api,
    required String fileName,
    required String jsonString,
    required String backupKind,
  }) async {
    try {
      final existing = await _findFileByName(
        api: api,
        fileName: fileName,
      );

      final bytes = Uint8List.fromList(utf8.encode(jsonString));
      final media = drive.Media(
        Stream<List<int>>.value(bytes),
        bytes.length,
        contentType: 'application/json; charset=utf-8',
      );

      final metadata = drive.File()
        ..name = fileName
        ..mimeType = 'application/json'
        ..appProperties = <String, String>{
          'appId': 'tarot_diary',
          'backupKind': backupKind,
        };

      if (existing == null) {
        metadata.parents = <String>['appDataFolder'];

        await api.files.create(
          metadata,
          uploadMedia: media,
          $fields: 'id,name,modifiedTime',
        );
        return;
      }

      await api.files.update(
        metadata,
        existing.id,
        uploadMedia: media,
        $fields: 'id,name,modifiedTime',
      );
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DriveBackupService._upsertJsonFile',
        error: e,
        stackTrace: st,
        extra: {
          'fileName': fileName,
          'backupKind': backupKind,
        },
      );

      if (e is BackupException) rethrow;

      throw const BackupException(
        'Drive 파일을 업로드하는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      );
    }
  }

  Future<String?> _readJsonFileByName({
    required drive.DriveApi api,
    required String fileName,
  }) async {
    try {
      final existing = await _findFileByName(
        api: api,
        fileName: fileName,
      );
      if (existing == null || existing.id.isEmpty) {
        return null;
      }

      final response = await api.files.get(
        existing.id,
        downloadOptions: drive.DownloadOptions.fullMedia,
      );

      if (response is! drive.Media) {
        return null;
      }

      final bytes = await _readAllBytes(response);
      if (bytes.isEmpty) return null;

      return utf8.decode(bytes, allowMalformed: true);
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DriveBackupService._readJsonFileByName',
        error: e,
        stackTrace: st,
        extra: {'fileName': fileName},
      );

      if (e is BackupException) rethrow;

      throw const BackupException(
        'Drive 파일을 읽는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      );
    }
  }

  Future<DriveRestoreResult> restoreFromRemoteBackup({
    bool replaceExisting = true,
  }) async {
    final startedAt = DateTime.now().millisecondsSinceEpoch;
    final prefs = await SharedPreferences.getInstance();

    try {
      final remote = await downloadRemoteBackup(
        includeDiary: true,
        includeArcana: true,
        includeSettings: false,
      );

      if (remote == null) {
        throw const BackupException(
          'Google Drive에 복원할 백업 데이터가 없습니다.',
        );
      }

      final diaryItems =
      remote.diaries.map((e) => e.toJson()).toList(growable: false);

      final arcanaItems =
      remote.arcanaNotes.map((e) => e.toJson()).toList(growable: false);

      await DiaryRepo.I.importAllFromBackup(
        diaryItems,
        replaceExisting: replaceExisting,
      );

      await ArcanaRepo.I.importAllFromBackup(
        arcanaItems,
        replaceExisting: replaceExisting,
      );

      final finishedAt = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(_prefsLastRestoreAtKey, finishedAt);

      await clearDirty();
      _cancelAutoBackupTimer();

      return DriveRestoreResult(
        success: true,
        startedAt: startedAt,
        finishedAt: finishedAt,
        restoredDiaryCount: diaryItems.length,
        restoredArcanaCount: arcanaItems.length,
        message: '기존 데이터 복원이 완료되었습니다.',
      );
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DriveBackupService.restoreFromRemoteBackup',
        error: e,
        stackTrace: st,
        extra: {
          'replaceExisting': replaceExisting,
        },
      );

      if (e is BackupException) rethrow;

      throw const BackupException(
        '기존 데이터를 복원하는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      );
    }
  }

  Future<Uint8List> _readAllBytes(drive.Media media) async {
    try {
      final builder = BytesBuilder(copy: false);
      await for (final chunk in media.stream) {
        builder.add(chunk);
      }
      return builder.takeBytes();
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'DriveBackupService._readAllBytes',
        error: e,
        stackTrace: st,
      );

      throw const BackupException(
        'Drive 데이터를 읽는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      );
    }
  }

  List<DiaryBackupItem> _decodeDiaryItems(String? source) {
    try {
      if (source == null || source.trim().isEmpty) {
        return const <DiaryBackupItem>[];
      }

      final decoded = jsonDecode(source);
      if (decoded is! List) {
        return const <DiaryBackupItem>[];
      }

      return decoded
          .whereType<Map>()
          .map((e) => DiaryBackupItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e, st) {
      unawaited(
        ErrorReporter.I.record(
          source: 'DriveBackupService._decodeDiaryItems',
          error: e,
          stackTrace: st,
        ),
      );
      return const <DiaryBackupItem>[];
    }
  }

  List<ArcanaBackupItem> _decodeArcanaItems(String? source) {
    try {
      if (source == null || source.trim().isEmpty) {
        return const <ArcanaBackupItem>[];
      }

      final decoded = jsonDecode(source);
      if (decoded is! List) {
        return const <ArcanaBackupItem>[];
      }

      return decoded
          .whereType<Map>()
          .map((e) => ArcanaBackupItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e, st) {
      unawaited(
        ErrorReporter.I.record(
          source: 'DriveBackupService._decodeArcanaItems',
          error: e,
          stackTrace: st,
        ),
      );
      return const <ArcanaBackupItem>[];
    }
  }

  SettingsBackupData? _decodeSettings(String? source) {
    try {
      if (source == null || source.trim().isEmpty) {
        return null;
      }

      final decoded = jsonDecode(source);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      return SettingsBackupData.fromJson(decoded);
    } catch (e, st) {
      unawaited(
        ErrorReporter.I.record(
          source: 'DriveBackupService._decodeSettings',
          error: e,
          stackTrace: st,
        ),
      );
      return null;
    }
  }

  String _kindForFileName(String fileName) {
    switch (fileName) {
      case kBackupManifestFileName:
        return 'manifest';
      case kBackupDiaryFileName:
        return 'diary';
      case kBackupArcanaFileName:
        return 'arcana';
      case kBackupSettingsFileName:
        return 'settings';
      default:
        return 'unknown';
    }
  }

  String _escapeQueryValue(String input) {
    return input.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
  }

  int? _safeInt64ToInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}

class DriveBackupResult {
  final bool success;
  final int startedAt;
  final int finishedAt;
  final int uploadedFileCount;
  final String message;
  final bool skipped;

  const DriveBackupResult({
    required this.success,
    required this.startedAt,
    required this.finishedAt,
    required this.uploadedFileCount,
    required this.message,
    this.skipped = false,
  });

  int get elapsedMs => finishedAt - startedAt;
}

class DriveFileInfo {
  final String id;
  final String name;
  final String? mimeType;
  final String? modifiedTimeIso;
  final int? size;
  final Map<String, String> appProperties;

  const DriveFileInfo({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.modifiedTimeIso,
    required this.size,
    required this.appProperties,
  });
}

class RemoteBackupData {
  final BackupManifest manifest;
  final List<DiaryBackupItem> diaries;
  final List<ArcanaBackupItem> arcanaNotes;
  final SettingsBackupData? settings;
  final String rawManifestJson;
  final String? rawDiaryJson;
  final String? rawArcanaJson;
  final String? rawSettingsJson;

  const RemoteBackupData({
    required this.manifest,
    required this.diaries,
    required this.arcanaNotes,
    required this.settings,
    required this.rawManifestJson,
    required this.rawDiaryJson,
    required this.rawArcanaJson,
    required this.rawSettingsJson,
  });
}

class DriveRestoreResult {
  final bool success;
  final int startedAt;
  final int finishedAt;
  final int restoredDiaryCount;
  final int restoredArcanaCount;
  final String message;

  const DriveRestoreResult({
    required this.success,
    required this.startedAt,
    required this.finishedAt,
    required this.restoredDiaryCount,
    required this.restoredArcanaCount,
    required this.message,
  });

  int get elapsedMs => finishedAt - startedAt;
}

class BackupException implements Exception {
  final String message;

  const BackupException(this.message);

  @override
  String toString() => message;
}