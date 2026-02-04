import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

/// Drive API 호출용 인증 클라이언트
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }

  @override
  void close() {
    _client.close();
    super.close();
  }
}

/// ✅ Google Drive(AppDataFolder) 백업 전용
/// - 파일을 사용자가 Drive에서 직접 보지 않게 숨김(appDataFolder)
/// - 백업 파일 1개를 "생성 또는 업데이트" 방식으로 관리
class BackupDrive {
  BackupDrive._();
  static final BackupDrive instance = BackupDrive._();

  /// appDataFolder에 올릴 기본 파일명
  static const String defaultBackupFileName = 'tarot_diary_backup_v1.zip';

  GoogleSignIn? _signIn;
  drive.DriveApi? _api;
  GoogleAuthClient? _client;

  /// Drive scope는 appDataFolder 전용으로 최소 권한 추천
  List<String> get _scopes => const [
    drive.DriveApi.driveAppdataScope,
  ];

  /// 현재 로그인된 계정 (없으면 null)
  GoogleSignInAccount? get currentAccount => _signIn?.currentUser;

  /// -----------------------------------------
  /// ✅ Auth / API 준비
  /// -----------------------------------------

  /// 로그인 + DriveApi 준비
  Future<drive.DriveApi> ensureDriveApi() async {
    if (_api != null) return _api!;

    _signIn ??= GoogleSignIn(scopes: _scopes);

    // 이미 로그인 돼 있으면 silent로 재사용
    GoogleSignInAccount? account = _signIn!.currentUser;
    account ??= await _signIn!.signInSilently();

    // 없으면 인터랙티브 로그인
    account ??= await _signIn!.signIn();

    if (account == null) {
      throw Exception('Google 로그인 취소됨');
    }

    final headers = await account.authHeaders;
    _client?.close();
    _client = GoogleAuthClient(headers);

    _api = drive.DriveApi(_client!);
    return _api!;
  }

  /// (선택) 로그아웃
  Future<void> signOut() async {
    try {
      await _signIn?.signOut();
    } catch (_) {}
    _api = null;
    _client?.close();
    _client = null;
  }

  /// -----------------------------------------
  /// ✅ 내부 유틸: appDataFolder 파일 찾기
  /// -----------------------------------------

  /// appDataFolder에서 name으로 파일 검색
  Future<drive.File?> _findFileByName({
    required drive.DriveApi api,
    required String fileName,
  }) async {
    final res = await api.files.list(
      spaces: 'appDataFolder',
      q: "name = '$fileName' and trashed = false",
      $fields: 'files(id,name,modifiedTime,size)',
      pageSize: 10,
    );

    final files = res.files ?? const <drive.File>[];
    if (files.isEmpty) return null;

    // name이 같으면 첫 번째 사용(보통 1개만 유지)
    return files.first;
  }

  /// -----------------------------------------
  /// ✅ 업로드(생성 또는 업데이트)
  /// -----------------------------------------

  /// zipFile을 appDataFolder에 업로드.
  /// - 같은 이름 파일이 있으면 update
  /// - 없으면 create
  Future<void> uploadBackupZip({
    required File zipFile,
    String fileName = defaultBackupFileName,
  }) async {
    final api = await ensureDriveApi();

    if (!await zipFile.exists()) {
      throw Exception('백업 파일이 존재하지 않습니다: ${zipFile.path}');
    }

    final length = await zipFile.length();
    final media = drive.Media(zipFile.openRead(), length);

    final existing = await _findFileByName(api: api, fileName: fileName);

    final meta = drive.File()
      ..name = fileName
      ..parents = ['appDataFolder'];

    if (existing?.id == null) {
      await api.files.create(meta, uploadMedia: media);
    } else {
      await api.files.update(meta, existing!.id!, uploadMedia: media);
    }
  }

  /// -----------------------------------------
  /// ✅ 다운로드
  /// -----------------------------------------

  /// appDataFolder에 있는 백업 zip을 내려받아 savePath에 저장.
  /// 반환: 저장된 File
  Future<File> downloadBackupZip({
    required Directory saveDir,
    String fileName = defaultBackupFileName,
  }) async {
    final api = await ensureDriveApi();

    final existing = await _findFileByName(api: api, fileName: fileName);
    if (existing?.id == null) {
      throw Exception('Drive에 백업 파일이 없습니다.');
    }

    if (!await saveDir.exists()) {
      await saveDir.create(recursive: true);
    }

    final outFile = File('${saveDir.path}/$fileName');

    final media = await api.files.get(
      existing!.id!,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final sink = outFile.openWrite();
    try {
      await media.stream.pipe(sink);
    } finally {
      await sink.flush();
      await sink.close();
    }

    return outFile;
  }

  /// -----------------------------------------
  /// ✅ 메타 조회(선택)
  /// -----------------------------------------

  /// 백업 파일이 존재하면 modifiedTime/size 등을 반환, 없으면 null
  Future<BackupDriveFileMeta?> getBackupMeta({
    String fileName = defaultBackupFileName,
  }) async {
    final api = await ensureDriveApi();
    final f = await _findFileByName(api: api, fileName: fileName);
    if (f?.id == null) return null;

    final modified = f!.modifiedTime;
    final sizeStr = f.size;
    final size = (sizeStr == null) ? null : int.tryParse(sizeStr);

    return BackupDriveFileMeta(
      id: f.id!,
      name: f.name ?? fileName,
      modifiedTime: modified,
      sizeBytes: size,
    );
  }
}

/// Drive 백업 파일 메타 정보
class BackupDriveFileMeta {
  final String id;
  final String name;
  final DateTime? modifiedTime;
  final int? sizeBytes;

  const BackupDriveFileMeta({
    required this.id,
    required this.name,
    required this.modifiedTime,
    required this.sizeBytes,
  });
}
