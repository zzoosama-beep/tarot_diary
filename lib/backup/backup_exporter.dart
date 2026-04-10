// lib/backup/backup_exporter.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../backend/arcana_repo.dart';
import '../backend/diary_repo.dart';
import '../error/error_reporter.dart';
import 'backup_models.dart';

class BackupException implements Exception {
  final String message;
  const BackupException(this.message);

  @override
  String toString() => message;
}

/// ✅ 백업 export 전용
///
/// 역할:
/// 1) diary / arcana / settings 데이터를 수집
/// 2) BackupBundle 생성
/// 3) json string / gzip bytes 생성
class BackupExporter {
  BackupExporter._();

  /// 설정 백업에 넣을 key 목록
  /// - 지금은 최소만 잡아두고, 나중에 필요한 설정 추가
  static const List<String> _settingsKeys = <String>[
    'google_drive_backup_enabled',
    'google_drive_last_backup_at',
    'google_drive_last_backup_success_at',
    'google_drive_last_restore_at',
  ];

  /// ✅ 전체 백업 번들 생성
  static Future<BackupBundle> buildBundle() async {
    try {
      final diaryRows = await DiaryRepo.I.exportAllForBackup();
      final arcanaRows = await ArcanaRepo.I.exportAllForBackup();
      final settings = await _exportSettings();

      final diaries = diaryRows
          .map(DiaryBackupItem.fromJson)
          .toList(growable: false);

      final arcanaNotes = arcanaRows
          .map(ArcanaBackupItem.fromJson)
          .toList(growable: false);

      final manifest = BackupManifest.create(
        diaryCount: diaries.length,
        arcanaCount: arcanaNotes.length,
        hasSettings: settings != null,
      );

      return BackupBundle(
        manifest: manifest,
        diaries: diaries,
        arcanaNotes: arcanaNotes,
        settings: settings,
      );
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'BackupExporter.buildBundle',
        error: e,
        stackTrace: st,
      );

      throw const BackupException(
        '백업 데이터를 준비하는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      );
    }
  }

  /// ✅ manifest json 문자열
  static Future<String> exportManifestJson() async {
    try {
      final bundle = await buildBundle();
      return bundle.encodeManifest();
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'BackupExporter.exportManifestJson',
        error: e,
        stackTrace: st,
      );

      throw const BackupException(
        '백업 정보를 만드는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      );
    }
  }

  /// ✅ diary json 문자열
  static Future<String> exportDiaryJson() async {
    try {
      final bundle = await buildBundle();
      return bundle.encodeDiaryList();
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'BackupExporter.exportDiaryJson',
        error: e,
        stackTrace: st,
      );

      throw const BackupException(
        '일기 백업 데이터를 만드는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      );
    }
  }

  /// ✅ arcana json 문자열
  static Future<String> exportArcanaJson() async {
    try {
      final bundle = await buildBundle();
      return bundle.encodeArcanaList();
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'BackupExporter.exportArcanaJson',
        error: e,
        stackTrace: st,
      );

      throw const BackupException(
        '아르카나 백업 데이터를 만드는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      );
    }
  }

  /// ✅ settings json 문자열 (없으면 null)
  static Future<String?> exportSettingsJsonOrNull() async {
    try {
      final bundle = await buildBundle();
      return bundle.encodeSettingsOrNull();
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'BackupExporter.exportSettingsJsonOrNull',
        error: e,
        stackTrace: st,
      );

      throw const BackupException(
        '설정 백업 데이터를 만드는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      );
    }
  }

  /// ✅ 한 번에 모두 export
  static Future<BackupExportResult> exportAll() async {
    try {
      final bundle = await buildBundle();

      final manifestJson = bundle.encodeManifest();
      final diaryJson = bundle.encodeDiaryList();
      final arcanaJson = bundle.encodeArcanaList();
      final settingsJson = bundle.encodeSettingsOrNull();

      return BackupExportResult(
        bundle: bundle,
        manifestJson: manifestJson,
        diaryJson: diaryJson,
        arcanaJson: arcanaJson,
        settingsJson: settingsJson,
      );
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'BackupExporter.exportAll',
        error: e,
        stackTrace: st,
      );

      throw const BackupException(
        '백업 데이터를 생성하는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      );
    }
  }

  /// ✅ 파일 단위 map
  /// Drive AppData 업로드할 때 그대로 쓰기 좋음
  static Future<Map<String, String>> exportFileMap({
    bool includeSettings = true,
  }) async {
    try {
      final result = await exportAll();

      final map = <String, String>{
        kBackupManifestFileName: result.manifestJson,
        kBackupDiaryFileName: result.diaryJson,
        kBackupArcanaFileName: result.arcanaJson,
      };

      if (includeSettings && result.settingsJson != null) {
        map[kBackupSettingsFileName] = result.settingsJson!;
      }

      return map;
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'BackupExporter.exportFileMap',
        error: e,
        stackTrace: st,
      );

      throw const BackupException(
        '백업 파일을 준비하는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      );
    }
  }

  /// ✅ 개별 json을 gzip으로 압축
  static Uint8List gzipString(String source) {
    try {
      final bytes = utf8.encode(source);
      final gz = GZipEncoder().encode(bytes);
      return Uint8List.fromList(gz ?? bytes);
    } catch (e, st) {
      unawaited(
        ErrorReporter.I.record(
          source: 'BackupExporter.gzipString',
          error: e,
          stackTrace: st,
        ),
      );
      return Uint8List.fromList(utf8.encode(source));
    }
  }

  /// ✅ 파일별 gzip map
  static Future<Map<String, Uint8List>> exportGzipFileMap({
    bool includeSettings = true,
  }) async {
    try {
      final files = await exportFileMap(includeSettings: includeSettings);

      final out = <String, Uint8List>{};
      for (final entry in files.entries) {
        out[entry.key] = gzipString(entry.value);
      }
      return out;
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'BackupExporter.exportGzipFileMap',
        error: e,
        stackTrace: st,
      );

      throw const BackupException(
        '백업 파일을 압축하는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      );
    }
  }

  /// ✅ 대략적인 백업 크기 확인용
  static Future<BackupSizeReport> estimateSize({
    bool includeSettings = true,
  }) async {
    try {
      final result = await exportAll();

      final manifestBytes = utf8.encode(result.manifestJson).length;
      final diaryBytes = utf8.encode(result.diaryJson).length;
      final arcanaBytes = utf8.encode(result.arcanaJson).length;
      final settingsBytes = includeSettings && result.settingsJson != null
          ? utf8.encode(result.settingsJson!).length
          : 0;

      final totalBytes = manifestBytes + diaryBytes + arcanaBytes + settingsBytes;

      final gzManifestBytes = gzipString(result.manifestJson).length;
      final gzDiaryBytes = gzipString(result.diaryJson).length;
      final gzArcanaBytes = gzipString(result.arcanaJson).length;
      final gzSettingsBytes = includeSettings && result.settingsJson != null
          ? gzipString(result.settingsJson!).length
          : 0;

      final gzTotalBytes =
          gzManifestBytes + gzDiaryBytes + gzArcanaBytes + gzSettingsBytes;

      return BackupSizeReport(
        diaryCount: result.bundle.diaries.length,
        arcanaCount: result.bundle.arcanaNotes.length,
        hasSettings: includeSettings && result.settingsJson != null,
        manifestBytes: manifestBytes,
        diaryBytes: diaryBytes,
        arcanaBytes: arcanaBytes,
        settingsBytes: settingsBytes,
        totalBytes: totalBytes,
        gzManifestBytes: gzManifestBytes,
        gzDiaryBytes: gzDiaryBytes,
        gzArcanaBytes: gzArcanaBytes,
        gzSettingsBytes: gzSettingsBytes,
        gzTotalBytes: gzTotalBytes,
      );
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'BackupExporter.estimateSize',
        error: e,
        stackTrace: st,
      );

      throw const BackupException(
        '백업 용량을 계산하는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      );
    }
  }

  /// ✅ 설정 export
  static Future<SettingsBackupData?> _exportSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final values = <String, dynamic>{};
      for (final key in _settingsKeys) {
        if (!prefs.containsKey(key)) continue;
        values[key] = prefs.get(key);
      }

      if (values.isEmpty) {
        return null;
      }

      return SettingsBackupData(
        schemaVersion: kBackupSchemaVersion,
        values: values,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e, st) {
      await ErrorReporter.I.record(
        source: 'BackupExporter._exportSettings',
        error: e,
        stackTrace: st,
      );

      throw const BackupException(
        '설정 데이터를 불러오는 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      );
    }
  }
}

/// ✅ export 결과물
class BackupExportResult {
  final BackupBundle bundle;
  final String manifestJson;
  final String diaryJson;
  final String arcanaJson;
  final String? settingsJson;

  const BackupExportResult({
    required this.bundle,
    required this.manifestJson,
    required this.diaryJson,
    required this.arcanaJson,
    required this.settingsJson,
  });
}

/// ✅ 백업 용량 리포트
class BackupSizeReport {
  final int diaryCount;
  final int arcanaCount;
  final bool hasSettings;

  final int manifestBytes;
  final int diaryBytes;
  final int arcanaBytes;
  final int settingsBytes;
  final int totalBytes;

  final int gzManifestBytes;
  final int gzDiaryBytes;
  final int gzArcanaBytes;
  final int gzSettingsBytes;
  final int gzTotalBytes;

  const BackupSizeReport({
    required this.diaryCount,
    required this.arcanaCount,
    required this.hasSettings,
    required this.manifestBytes,
    required this.diaryBytes,
    required this.arcanaBytes,
    required this.settingsBytes,
    required this.totalBytes,
    required this.gzManifestBytes,
    required this.gzDiaryBytes,
    required this.gzArcanaBytes,
    required this.gzSettingsBytes,
    required this.gzTotalBytes,
  });

  double get totalKb => totalBytes / 1024.0;
  double get totalMb => totalBytes / (1024.0 * 1024.0);

  double get gzTotalKb => gzTotalBytes / 1024.0;
  double get gzTotalMb => gzTotalBytes / (1024.0 * 1024.0);

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'diaryCount': diaryCount,
      'arcanaCount': arcanaCount,
      'hasSettings': hasSettings,
      'manifestBytes': manifestBytes,
      'diaryBytes': diaryBytes,
      'arcanaBytes': arcanaBytes,
      'settingsBytes': settingsBytes,
      'totalBytes': totalBytes,
      'totalKb': totalKb,
      'totalMb': totalMb,
      'gzManifestBytes': gzManifestBytes,
      'gzDiaryBytes': gzDiaryBytes,
      'gzArcanaBytes': gzArcanaBytes,
      'gzSettingsBytes': gzSettingsBytes,
      'gzTotalBytes': gzTotalBytes,
      'gzTotalKb': gzTotalKb,
      'gzTotalMb': gzTotalMb,
    };
  }

  @override
  String toString() {
    return 'BackupSizeReport('
        'diaryCount: $diaryCount, '
        'arcanaCount: $arcanaCount, '
        'hasSettings: $hasSettings, '
        'totalBytes: $totalBytes, '
        'totalMb: ${totalMb.toStringAsFixed(3)}, '
        'gzTotalBytes: $gzTotalBytes, '
        'gzTotalMb: ${gzTotalMb.toStringAsFixed(3)}'
        ')';
  }
}