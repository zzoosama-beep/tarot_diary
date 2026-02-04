import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'diary_local.dart';
import 'backup_drive.dart';

/// ✅ 백업/복원 총괄 매니저
/// - DB 파일을 zip으로 묶어서 Drive(appDataFolder)에 업로드
/// - Drive에서 zip 다운로드 후 DB 파일로 복원
/// - lastBackupAt 저장/조회
class BackupManager {
  BackupManager._();
  static final BackupManager instance = BackupManager._();

  static const String kBackupFileName = BackupDrive.defaultBackupFileName;

  // SharedPreferences keys
  static const String _kLastBackupAtMs = 'backup_last_at_ms';
  static const String _kLastRestoreAtMs = 'backup_last_restore_at_ms';

  /// -----------------------------------------
  /// ✅ last backup/restore time
  /// -----------------------------------------

  Future<DateTime?> getLastBackupAt() async {
    final sp = await SharedPreferences.getInstance();
    final ms = sp.getInt(_kLastBackupAtMs);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<DateTime?> getLastRestoreAt() async {
    final sp = await SharedPreferences.getInstance();
    final ms = sp.getInt(_kLastRestoreAtMs);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> _setLastBackupNow() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_kLastBackupAtMs, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _setLastRestoreNow() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_kLastRestoreAtMs, DateTime.now().millisecondsSinceEpoch);
  }

  /// -----------------------------------------
  /// ✅ local temp dir
  /// -----------------------------------------

  Future<Directory> _tempDir() async {
    final d = await getTemporaryDirectory();
    final out = Directory(p.join(d.path, 'tarot_backup'));
    if (!await out.exists()) await out.create(recursive: true);
    return out;
  }

  /// -----------------------------------------
  /// ✅ ZIP 만들기/풀기
  /// -----------------------------------------

  /// DB 파일을 zip으로 압축해서 반환
  /// zip 안에는 "tarot_diary.db" 파일 1개만 들어감(현재 DB 파일명 그대로)
  Future<File> createBackupZipFromDb() async {
    final dbPath = await DiaryLocal.instance.getDbPath();
    final dbFile = File(dbPath);

    if (!await dbFile.exists()) {
      throw Exception('로컬 DB 파일이 없습니다. (아직 저장된 데이터가 없을 수 있음)\n$dbPath');
    }

    final tmp = await _tempDir();
    final zipPath = p.join(tmp.path, kBackupFileName);
    final zipFile = File(zipPath);

    // 기존 zip 지우기
    if (await zipFile.exists()) {
      await zipFile.delete();
    }

    // zip 생성
    final encoder = ZipFileEncoder();
    encoder.create(zipPath);

    // zip 내부 파일명은 실제 파일명으로 넣는다
    encoder.addFile(dbFile);

    encoder.close();

    return zipFile;
  }

  /// zip을 풀어서 db 파일을 반환
  /// - zip 안의 *.db 파일을 찾아서 반환(보통 1개)
  Future<File> extractDbFromZip(File zipFile) async {
    if (!await zipFile.exists()) {
      throw Exception('zip 파일이 없습니다: ${zipFile.path}');
    }

    final tmp = await _tempDir();
    final extractDir = Directory(p.join(tmp.path, 'extract'));
    if (await extractDir.exists()) {
      await extractDir.delete(recursive: true);
    }
    await extractDir.create(recursive: true);

    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    File? foundDb;

    for (final entry in archive) {
      if (!entry.isFile) continue;

      final name = entry.name;
      if (!name.toLowerCase().endsWith('.db')) continue;

      final outPath = p.join(extractDir.path, p.basename(name));
      final outFile = File(outPath);
      await outFile.create(recursive: true);
      await outFile.writeAsBytes(entry.content as List<int>, flush: true);

      foundDb = outFile;
      break;
    }

    if (foundDb == null) {
      throw Exception('zip 안에서 .db 파일을 찾지 못했습니다.');
    }

    return foundDb;
  }

  /// -----------------------------------------
  /// ✅ Drive 백업/복원
  /// -----------------------------------------

  /// 1) 로컬 DB -> zip 생성
  /// 2) Drive(appDataFolder) 업로드
  /// 3) lastBackupAt 저장
  Future<void> backupToDrive() async {
    final zip = await createBackupZipFromDb();
    await BackupDrive.instance.uploadBackupZip(zipFile: zip);
    await _setLastBackupNow();
  }

  /// 1) Drive에서 zip 다운로드
  /// 2) zip에서 db 추출
  /// 3) 현재 db close
  /// 4) 기존 db 백업(.bak)
  /// 5) 새 db로 교체(복원)
  /// 6) lastRestoreAt 저장
  ///
  /// ⚠️ 복원은 데이터 덮어쓰기임. (병합 X)
  Future<void> restoreFromDrive() async {
    final tmp = await _tempDir();

    final zip = await BackupDrive.instance.downloadBackupZip(saveDir: tmp);
    final extractedDb = await extractDbFromZip(zip);

    // 현재 DB close (파일 잠김 방지)
    await DiaryLocal.instance.close();

    final targetPath = await DiaryLocal.instance.getDbPath();
    final targetFile = File(targetPath);

    // 기존 db가 있으면 .bak로 보관
    if (await targetFile.exists()) {
      final bakPath = '$targetPath.bak';
      final bakFile = File(bakPath);

      // 기존 bak 있으면 덮어쓰기 위해 삭제
      if (await bakFile.exists()) await bakFile.delete();

      await targetFile.rename(bakPath);
    } else {
      // 경로 폴더가 없을 수 있으니 생성
      await targetFile.parent.create(recursive: true);
    }

    // 새 db 복사(추출된 파일명과 상관없이 target 위치로)
    await extractedDb.copy(targetPath);

    await _setLastRestoreNow();

    // (선택) restore 직후 DB를 열어둬도 되지만,
    // 현재 DiaryLocal은 lazy-open이라 필요할 때 자동 open 됨.
  }

  /// Drive에 백업이 있는지 / 마지막 수정시간 등 확인용
  Future<BackupDriveFileMeta?> getDriveBackupMeta() async {
    return BackupDrive.instance.getBackupMeta();
  }
}
