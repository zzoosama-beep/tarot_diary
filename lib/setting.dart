import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

import 'backend/auth_service.dart';
import 'backup/drive_backup_service.dart';
import 'theme/app_theme.dart';
import 'ui/layout_tokens.dart';
import 'ui/app_buttons.dart';
import 'error/error_reporter.dart';

import 'backend/arcana_repo.dart';
import 'backend/diary_repo.dart';

import 'diary/calander_diary.dart';
import 'backend/account_delete_service.dart';

Color _a(Color c, double o) => c.withAlpha((o * 255).round());

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage>
    with SingleTickerProviderStateMixin {
  bool _busy = false;
  String _busyTitle = '';
  String _busyMessage = '';
  bool _loadingBackupState = false;

  int? _lastBackup;
  String? _backupEmail;

  String? _remoteCreatedAt;
  int? _remoteDiaryCount;
  int? _remoteArcanaCount;
  bool _hasRemoteBackup = false;

  int _localDiaryCount = 0;
  int _localArcanaCount = 0;

  int _pendingDiaryCount = 0;
  int _pendingArcanaCount = 0;
  bool _hasPendingChanges = false;

  late final AnimationController _dotController;
  Future<void>? _loadingBackupFuture;
  StreamSubscription<User?>? _authSub;

  bool get _hasPendingBackup => _hasPendingChanges;

  User? get _currentUser => FirebaseAuth.instance.currentUser;
  bool get _isSignedIn => _currentUser != null;

  @override
  void initState() {
    super.initState();

    unawaited(
      ErrorReporter.I.record(
        source: 'auth.debug.setting_enter',
        error: 'auth_state_snapshot',
        extra: {
          'firebaseEmail': FirebaseAuth.instance.currentUser?.email,
          'firebaseUid': FirebaseAuth.instance.currentUser?.uid,
          'firebaseUserExists': FirebaseAuth.instance.currentUser != null,
        },
      ),
    );

    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();

    _loadBackupState();

    _authSub = FirebaseAuth.instance.idTokenChanges().listen((user) async {
      if (!mounted) return;
      await _loadBackupState();
      if (!mounted) return;
      setState(() {});
    });
  }


  @override
  void dispose() {
    _authSub?.cancel();
    _dotController.dispose();
    super.dispose();
  }

  Future<void> _recordError({
    required String source,
    required Object error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) async {
    await ErrorReporter.I.record(
      source: source,
      error: error,
      stackTrace: stackTrace,
      extra: extra,
    );
  }

  void _setBusy(
      bool value, {
        String? title,
        String? message,
      }) {
    if (!mounted) return;

    setState(() {
      _busy = value;
      _busyTitle = value ? (title ?? '') : '';
      _busyMessage = value ? (message ?? '') : '';
    });
  }

  Future<int> _loadLocalDiaryCount() async {
    try {
      final items = await DiaryRepo.I.exportAllForBackup();
      return items.length;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _loadLocalArcanaCount() async {
    try {
      final items = await ArcanaRepo.I.exportAllForBackup();
      return items.length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _loadBackupState() async {
    final future = _loadBackupStateInternal();
    _loadingBackupFuture = future;
    await future;
  }

  Future<void> _loadBackupStateInternal() async {
    if (mounted) {
      setState(() {
        _loadingBackupState = true;
      });
    }

    try {
      final last = await DriveBackupService.I.getLastBackupSuccessAt();
      final email = await DriveBackupService.I.getLastBackupEmail();
      final pending = await DriveBackupService.I.hasPendingBackup();

      final localDiaryCount = await _loadLocalDiaryCount();
      final localArcanaCount = await _loadLocalArcanaCount();

      final signedIn = _isSignedIn;

      if (!mounted) return;

      setState(() {
        _lastBackup = last;
        _backupEmail = email;
        _localDiaryCount = localDiaryCount;
        _localArcanaCount = localArcanaCount;
        _hasPendingChanges = pending;
      });

      if (!signedIn) {
        if (!mounted) return;

        setState(() {
          _hasRemoteBackup = false;
          _remoteCreatedAt = null;
          _remoteDiaryCount = null;
          _remoteArcanaCount = null;
          _pendingDiaryCount = 0;
          _pendingArcanaCount = 0;
        });

        return;
      }

      bool hasRemote = false;
      String? createdAt;
      int remoteDiaryCount = 0;
      int remoteArcanaCount = 0;

      try {
        final manifest = await DriveBackupService.I.loadRemoteManifest();
        if (manifest != null) {
          hasRemote = true;
          createdAt = manifest.createdAtIso;
          remoteDiaryCount = manifest.diaryCount;
          remoteArcanaCount = manifest.arcanaCount;
        }
      } catch (e, st) {
        await _recordError(
          source: 'setting.loadRemoteManifest',
          error: e,
          stackTrace: st,
        );
      }

      if (!mounted) return;

      setState(() {
        _hasRemoteBackup = hasRemote;
        _remoteCreatedAt = createdAt;
        _remoteDiaryCount = hasRemote ? remoteDiaryCount : null;
        _remoteArcanaCount = hasRemote ? remoteArcanaCount : null;

        _pendingDiaryCount =
            (localDiaryCount - remoteDiaryCount).clamp(0, 999999);
        _pendingArcanaCount =
            (localArcanaCount - remoteArcanaCount).clamp(0, 999999);
      });
    } catch (e, st) {
      await _recordError(
        source: 'setting.loadBackupState',
        error: e,
        stackTrace: st,
      );

      if (!mounted) return;
      _showMessage('백업 상태를 불러오는 중 문제가 발생했습니다. 잠시 후 다시 시도해주세요.');
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingBackupState = false;
      });
    }
  }

  Future<void> _tryDeferredBackupIfNeeded() async {
    try {
      final result = await DriveBackupService.I.backupIfNeeded(
        interactiveIfNeeded: false,
      );

      if (!result.skipped) {
        await _loadBackupState();
      }
    } catch (e, st) {
      await _recordError(
        source: 'setting.tryDeferredBackupIfNeeded',
        error: e,
        stackTrace: st,
      );
    }
  }

  String _formatTime(int? ms) {
    if (ms == null) return "없음";
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return "${dt.year}.${dt.month}.${dt.day} "
        "${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
  }

  String _formatIso(String? iso) {
    if (iso == null || iso.isEmpty) return "없음";
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return "${dt.year}.${dt.month}.${dt.day} "
        "${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _a(const Color(0xFF2A1A3A), 0.94),
        behavior: SnackBarBehavior.floating,
        content: Text(
          text,
          style: AppTheme.body.copyWith(
            fontSize: 13,
            color: _a(AppTheme.homeCream, 0.96),
            height: 1.3,
          ),
        ),
      ),
    );
  }

  Future<void> _signIn() async {
    if (_busy) return;

    bool shouldRestore = false;

    _setBusy(
      true,
      title: '구글 로그인 중입니다',
      message: '구글 계정에 연결하고 있어요.\n잠시만 기다려주세요.',
    );

    try {
      await AuthService.ensureSignedIn(
        forceAccountChooser: true,
        hardDisconnect: true,
      );

      // (에러 리포팅 로직 생략...)

      await DriveBackupService.I.setEnabled(true);
      await _loadBackupState();

      if (_hasRemoteBackup) {
        // 1. 복원 여부를 먼저 묻습니다.
        shouldRestore = await _showAutoRestoreGuideDialog();

        // 2. 사용자가 '나중에'를 눌렀을 경우 (shouldRestore == false)
        if (!shouldRestore) {
          // 한 번 더 확인을 요청합니다. 여기서 '아니오'를 누르면 다시 복원 질문으로 돌아가거나 취소하게 합니다.
          final confirmProceedWithoutRestore = await _showUseCurrentDeviceDataConfirmDialog();

          if (!confirmProceedWithoutRestore) {
            // 사용자가 '아차' 싶어서 취소했다면, 다시 복원을 시도할 기회를 주거나 로그인을 유지하되 복원 로직을 타게 할 수 있습니다.
            // 여기서는 단순히 복원하기로 마음을 돌렸다고 가정하고 로직을 연결하거나, 안전하게 함수를 종료합니다.
            _showMessage('복원 여부를 다시 결정해주세요.');
            _setBusy(false);
            return;
          }
        }
      }

      await _tryDeferredBackupIfNeeded();
      await _loadBackupState();

      _showMessage('구글 로그인 되었습니다.');
    } catch (e, st) {
      // (에러 처리 로직 생략...)
      shouldRestore = false;
    } finally {
      _setBusy(false);
    }

    if (!mounted) return;

    if (shouldRestore) {
      await _restoreFromBackup(skipConfirm: true);
    }
  }

  // '나중에' 클릭 시 띄울 새로운 확인 다이얼로그 (Yes/No 형태)
  Future<bool> _showUseCurrentDeviceDataConfirmDialog() async {
    if (!mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _a(const Color(0xFF2A1A3A), 0.96),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            '주의: 데이터 덮어쓰기',
            style: AppTheme.body.copyWith(
              fontWeight: FontWeight.w900,
              color: _a(const Color(0xFFFFB3B3), 0.98), // 경고 의미로 붉은 계열
            ),
          ),
          content: Text(
            '지금 복원하지 않고 계속하시면,\n기존 Google Drive의 백업 데이터(${_remoteDiaryCount ?? 0}건)가\n'
                '현재 기기의 데이터로 대체되어 사라집니다.\n\n'
                '정말 현재 데이터 기준으로 계속할까요?',
            style: AppTheme.body.copyWith(
              fontSize: 13,
              height: 1.5,
              color: _a(AppTheme.homeCream, 0.92),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false), // 아니오 (다시 생각할래)
              child: Text(
                '아니오',
                style: AppTheme.uiSmallLabel.copyWith(
                  color: _a(AppTheme.homeCream, 0.72),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true), // 예 (그냥 진행해)
              child: Text(
                '예, 진행합니다',
                style: AppTheme.uiSmallLabel.copyWith(
                  color: _a(const Color(0xFFFFD7A8), 0.96),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<void> _showUseCurrentDeviceDataDialog() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _a(const Color(0xFF2A1A3A), 0.96),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            '현재 기기 데이터 기준으로 진행',
            style: AppTheme.body.copyWith(
              fontWeight: FontWeight.w900,
              color: _a(AppTheme.homeCream, 0.96),
            ),
          ),
          content: Text(
            '지금부터는 현재 기기의 데이터가 기준이 됩니다.\n\n'
                '기존 Google Drive에 저장된\n'
                '아르카나 ${_remoteArcanaCount ?? 0}건, 타로 일기 ${_remoteDiaryCount ?? 0}건은\n'
                '이후 자동백업 시 현재 데이터로 갱신됩니다.\n\n'
                '이후 저장되는 내용은 지금 기기 기준으로 새롭게 적용됩니다.',
            style: AppTheme.body.copyWith(
              fontSize: 13,
              height: 1.5,
              color: _a(AppTheme.homeCream, 0.92),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                '확인',
                style: AppTheme.uiSmallLabel.copyWith(
                  color: _a(const Color(0xFFFFD7A8), 0.96),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _showAutoRestoreGuideDialog() async {
    if (!mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _a(const Color(0xFF2A1A3A), 0.96),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            '백업 데이터 발견',
            style: AppTheme.body.copyWith(
              fontWeight: FontWeight.w900,
              color: _a(AppTheme.homeCream, 0.96),
            ),
          ),
          content: Text(
            '이 계정에 저장된 데이터가 있습니다.\n\n'
                '마지막 백업: ${_formatIso(_remoteCreatedAt)}\n'
                '일기 ${_remoteDiaryCount ?? 0}건\n'
                '아르카나 ${_remoteArcanaCount ?? 0}건\n\n'
                '복원하시겠습니까?',
            style: AppTheme.body.copyWith(
              fontSize: 13,
              height: 1.45,
              color: _a(AppTheme.homeCream, 0.92),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                '나중에',
                style: AppTheme.uiSmallLabel.copyWith(
                  color: _a(AppTheme.homeCream, 0.72),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                '복원하기',
                style: AppTheme.uiSmallLabel.copyWith(
                  color: _a(const Color(0xFFFFD7A8), 0.96),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<void> _restoreFromBackup({bool skipConfirm = false}) async {
    if (_busy) return;

    if (_loadingBackupState) {
      await _loadingBackupFuture;
    }

    if (!mounted) return;

    if (!_isSignedIn) {
      _showMessage('복원하려면 먼저 구글 로그인이 필요합니다.');
      return;
    }

    _setBusy(
      true,
      title: '백업 확인 중입니다',
      message: 'Google Drive에 저장된 백업 데이터를 다시 확인하고 있어요.\n잠시만 기다려주세요.',
    );

    try {
      final manifest = await DriveBackupService.I.loadRemoteManifest();

      if (!mounted) return;

      if (manifest == null) {
        _showMessage('Google Drive에 복원할 백업 데이터가 없습니다.');
        return;
      }

      setState(() {
        _hasRemoteBackup = true;
        _remoteCreatedAt = manifest.createdAtIso;
        _remoteDiaryCount = manifest.diaryCount;
        _remoteArcanaCount = manifest.arcanaCount;
      });
    } catch (e, st) {
      await _recordError(
        source: 'setting.restoreFromBackup.precheck',
        error: e,
        stackTrace: st,
      );
      _showMessage('백업 상태를 다시 확인하는 중 문제가 발생했습니다. 잠시 후 다시 시도해주세요.');
      return;
    } finally {
      _setBusy(false);
    }

    if (!skipConfirm) {
      final confirm = await _showRestoreConfirmDialog();
      if (confirm != true) return;
    }

    _setBusy(
      true,
      title: '복원 중입니다',
      message: '기록을 다시 불러오고 있어요.\n잠시만 기다려주세요.',
    );

    try {
      final result = await DriveBackupService.I.restoreFromRemoteBackup(
        replaceExisting: true,
      );

      await _loadBackupState();

      if (!mounted) return;

      _showMessage(
        '${result.message} '
            '(일기 ${result.restoredDiaryCount}건, 아르카나 ${result.restoredArcanaCount}건)',
      );

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const CalanderDiaryPage(
            initialViewMode: DiaryViewMode.calendar,
          ),
        ),
      );
    } catch (e, st) {
      await _recordError(
        source: 'setting.restoreFromBackup',
        error: e,
        stackTrace: st,
      );
      _showMessage(
        e is Exception
            ? e.toString()
            : '복원 중 문제가 발생했습니다. 잠시 후 다시 시도해주세요.',
      );
    } finally {
      _setBusy(false);
    }
  }

  Future<bool?> _showRestoreConfirmDialog() async {
    final hasLocalDiary = await DiaryRepo.I.hasAnyData();
    final hasLocalArcana = await ArcanaRepo.I.hasAnyData();
    final hasLocalData = hasLocalDiary || hasLocalArcana;

    if (!_hasRemoteBackup) {
      _showMessage('Google Drive에 복원할 백업 데이터가 없습니다.');
      return false;
    }

    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _a(const Color(0xFF2A1A3A), 0.96),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            '기존 데이터 복원',
            style: AppTheme.body.copyWith(
              fontWeight: FontWeight.w900,
              color: _a(AppTheme.homeCream, 0.96),
            ),
          ),
          content: Text(
            hasLocalData
                ? 'Google Drive에 저장된 데이터를 현재 기기에 복원합니다.\n\n현재 기기에 있는 일기/아르카나 데이터는 덮어씌워질 수 있으며 되돌릴 수 없습니다.\n그래도 진행하시겠습니까?'
                : 'Google Drive에 저장된 데이터를 현재 기기에 복원합니다.\n\n복원을 진행하시겠습니까?',
            style: AppTheme.body.copyWith(
              fontSize: 13,
              height: 1.45,
              color: _a(AppTheme.homeCream, 0.92),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                '취소',
                style: AppTheme.uiSmallLabel.copyWith(
                  color: _a(AppTheme.homeCream, 0.72),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                '복원하기',
                style: AppTheme.uiSmallLabel.copyWith(
                  color: _a(const Color(0xFFFFD7A8), 0.96),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _backupNow() async {
    if (_busy) return;

    if (!_isSignedIn) {
      _showMessage('백업하려면 먼저 구글 로그인이 필요합니다.');
      return;
    }

    _setBusy(
      true,
      title: '백업 중입니다',
      message: '소중한 기록을 안전하게 저장하고 있어요.',
    );

    try {
      final result = await DriveBackupService.I.backupNow(
        interactiveIfNeeded: true,
      );
      await _loadBackupState();
      _showMessage(result.message);
    } catch (e, st) {
      await _recordError(
        source: 'setting.backupNow',
        error: e,
        stackTrace: st,
      );
      _showMessage(e.toString());
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _signOut() async {
    if (_busy) return;

    _setBusy(
      true,
      title: '로그아웃 중입니다',
      message: '계정을 정리하고 있어요.\n잠시만 기다려주세요.',
    );

    try {
      await AuthService.signOut(hardDisconnect: true);
      await DriveBackupService.I.disconnect();

      _showMessage('로그아웃되었습니다.');
    } catch (e, st) {
      await _recordError(
        source: 'setting.signOut',
        error: e,
        stackTrace: st,
      );
      _showMessage('로그아웃 중 문제가 발생했습니다. 잠시 후 다시 시도해주세요.');
    } finally {
      await _loadBackupState();
      _setBusy(false);
    }
  }

  Future<bool> _showDeleteAccountConfirmDialog() async {
    final signedIn = _isSignedIn;
    final hasLocalDiary = await DiaryRepo.I.hasAnyData();
    final hasLocalArcana = await ArcanaRepo.I.hasAnyData();

    final hasAnything = signedIn || hasLocalDiary || hasLocalArcana;

    if (!hasAnything) {
      _showMessage('삭제할 계정 또는 데이터가 없습니다.');
      return false;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _a(const Color(0xFF2A1A3A), 0.96),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            '계정 삭제',
            style: AppTheme.body.copyWith(
              fontWeight: FontWeight.w900,
              color: _a(AppTheme.homeCream, 0.96),
            ),
          ),
          content: Text(
            '계정을 삭제하면 현재 기기의 타로 일기, 아르카나 기록, 백업 관련 설정과 함께\n'
                'Google Drive에 저장된 백업 데이터도 모두 삭제됩니다.\n\n'
                '삭제 후에는 복구할 수 없으며, 다시 사용하려면 처음부터 새로 시작해야 합니다.\n\n'
                '정말 삭제하시겠습니까?',
            style: AppTheme.body.copyWith(
              fontSize: 13,
              height: 1.45,
              color: _a(AppTheme.homeCream, 0.92),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                '취소',
                style: AppTheme.uiSmallLabel.copyWith(
                  color: _a(AppTheme.homeCream, 0.72),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                '삭제하기',
                style: AppTheme.uiSmallLabel.copyWith(
                  color: _a(const Color(0xFFFFB3B3), 0.98),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<void> _deleteAccount() async {
    if (_busy) return;

    final confirm = await _showDeleteAccountConfirmDialog();
    if (confirm != true) return;

    _setBusy(
      true,
      title: '계정 삭제 중입니다',
      message: '현재 기기의 기록과 계정 연결 정보를 정리하고 있어요.\n잠시만 기다려주세요.',
    );

    try {
      final result = await AccountDeleteService.I.deleteAccountAndLocalData();

      if (!mounted) return;

      await _loadBackupState();

      _showMessage(result.message);

      if (result.success) {
        await Navigator.of(context)
            .pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e, st) {
      await _recordError(
        source: 'setting.deleteAccount',
        error: e,
        stackTrace: st,
      );

      _showMessage('계정 삭제 중 문제가 발생했습니다. 잠시 후 다시 시도해주세요.');
    } finally {
      _setBusy(false);
    }
  }

  Widget _buildBusyOverlay() {
    return IgnorePointer(
      ignoring: !_busy,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: _busy ? 1 : 0,
        child: Container(
          color: _a(Colors.black, 0.28),
          alignment: Alignment.center,
          child: SafeArea(
            child: Center(
              child: Container(
                width: 248,
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                decoration: BoxDecoration(
                  color: _a(const Color(0xFF2A1A3A), 0.97),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _a(Colors.white, 0.08),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _a(Colors.black, 0.30),
                      blurRadius: 26,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.pets_rounded,
                      size: 34,
                      color: _a(const Color(0xFFFFD7A8), 0.96),
                    ),
                    const SizedBox(height: 14),
                    AnimatedBuilder(
                      animation: _dotController,
                      builder: (context, child) {
                        final t = _dotController.value;

                        double scaleFor(double start) {
                          final v = ((t - start) % 1.0);
                          final wave = (v < 0.5) ? v * 2 : (1 - v) * 2;
                          return 0.78 + (wave * 0.34);
                        }

                        Widget dot(double start) {
                          return Transform.scale(
                            scale: scaleFor(start),
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _a(const Color(0xFFFFD7A8), 0.95),
                                shape: BoxShape.circle,
                              ),
                            ),
                          );
                        }

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            dot(0.00),
                            const SizedBox(width: 8),
                            dot(0.18),
                            const SizedBox(width: 8),
                            dot(0.36),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _busyTitle,
                      textAlign: TextAlign.center,
                      style: AppTheme.body.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: _a(AppTheme.homeCream, 0.97),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _busyMessage,
                      textAlign: TextAlign.center,
                      style: AppTheme.body.copyWith(
                        fontSize: 12.8,
                        height: 1.45,
                        color: _a(AppTheme.homeCream, 0.86),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingBackupOverlay() {
    return IgnorePointer(
      ignoring: !_loadingBackupState,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: _loadingBackupState ? 1 : 0,
        child: Container(
          color: _a(Colors.black, 0.22),
          alignment: Alignment.center,
          child: SafeArea(
            child: Center(
              child: Container(
                width: 266,
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                decoration: BoxDecoration(
                  color: _a(const Color(0xFF2A1A3A), 0.97),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _a(Colors.white, 0.08),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _a(Colors.black, 0.28),
                      blurRadius: 24,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_sync_rounded,
                      size: 34,
                      color: _a(const Color(0xFFFFD7A8), 0.96),
                    ),
                    const SizedBox(height: 14),
                    AnimatedBuilder(
                      animation: _dotController,
                      builder: (context, child) {
                        final t = _dotController.value;

                        double scaleFor(double start) {
                          final v = ((t - start) % 1.0);
                          final wave = (v < 0.5) ? v * 2 : (1 - v) * 2;
                          return 0.78 + (wave * 0.34);
                        }

                        Widget dot(double start) {
                          return Transform.scale(
                            scale: scaleFor(start),
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _a(const Color(0xFFFFD7A8), 0.95),
                                shape: BoxShape.circle,
                              ),
                            ),
                          );
                        }

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            dot(0.00),
                            const SizedBox(width: 8),
                            dot(0.18),
                            const SizedBox(width: 8),
                            dot(0.36),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '백업 데이터 확인 중입니다',
                      textAlign: TextAlign.center,
                      style: AppTheme.body.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: _a(AppTheme.homeCream, 0.97),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '저장된 기록과 Google Drive 상태를\n차례로 불러오고 있어요.',
                      textAlign: TextAlign.center,
                      style: AppTheme.body.copyWith(
                        fontSize: 12.8,
                        height: 1.45,
                        color: _a(AppTheme.homeCream, 0.86),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackupActionButtons({
    required bool backupEnabled,
    required bool restoreEnabled,
    required bool isTablet,
  }) {
    Widget buildButton({
      required String label,
      required IconData icon,
      required bool enabled,
      required VoidCallback? onPressed,
    }) {
      return Expanded(
        child: SizedBox(
          height: isTablet ? 48 : 44,
          child: ElevatedButton(
            onPressed: enabled ? onPressed : null,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: enabled
                  ? const Color(0xFF866FBE)
                  : _a(const Color(0xFF866FBE), 0.30),
              foregroundColor: _a(AppTheme.homeCream, 0.96),
              disabledBackgroundColor: _a(const Color(0xFF866FBE), 0.30),
              disabledForegroundColor: _a(AppTheme.homeCream, 0.42),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isTablet ? 14 : 12),
                side: BorderSide(
                  color: _a(Colors.white, enabled ? 0.14 : 0.06),
                  width: 1,
                ),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 10 : 8,
                vertical: isTablet ? 10 : 9,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: isTablet ? 17 : 16),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.body.copyWith(
                      fontSize: isTablet ? 13.6 : 12.6,
                      fontWeight: FontWeight.w900,
                      color: _a(AppTheme.homeCream, enabled ? 0.96 : 0.48),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        buildButton(
          label: _hasPendingBackup ? '새 데이터 백업' : '지금 백업',
          icon: Icons.backup_rounded,
          enabled: backupEnabled,
          onPressed: backupEnabled ? () => _backupNow() : null,
        ),
        const SizedBox(width: 10),
        buildButton(
          label: '기존 데이터 복원',
          icon: Icons.restore_rounded,
          enabled: restoreEnabled,
          onPressed: restoreEnabled ? () => _restoreFromBackup() : null,
        ),
      ],
    );
  }

  Widget _buildActionButtons({
    required bool signedIn,
    required bool isNarrow,
  }) {
    final loginEnabled = !signedIn && !_busy;
    final logoutEnabled = signedIn && !_busy;

    final loginBtn = SizedBox(
      width: double.infinity,
      height: 42,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: signedIn
              ? _a(const Color(0xFF6A4FA3), 0.28)
              : loginEnabled
              ? _a(const Color(0xFF6A4FA3), 0.92)
              : _a(const Color(0xFF6A4FA3), 0.24),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: signedIn
                ? _a(AppTheme.headerInk, 0.08)
                : _a(AppTheme.headerInk, loginEnabled ? 0.14 : 0.08),
            width: 1.1,
          ),
          boxShadow: signedIn
              ? []
              : [
            BoxShadow(
              color: _a(Colors.white, 0.10),
              blurRadius: 8,
              offset: const Offset(0, -2),
              spreadRadius: -4,
            ),
            BoxShadow(
              color: _a(Colors.black, 0.10),
              blurRadius: 10,
              offset: const Offset(0, 4),
              spreadRadius: -6,
            ),
          ],
        ),
        child: TextButton(
          onPressed: loginEnabled ? _signIn : null,
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10),
            foregroundColor: _a(AppTheme.homeCream, 0.96),
          ),
          child: Text(
            signedIn ? '로그인 완료' : '구글 로그인',
            style: AppTheme.uiSmallLabel.copyWith(
              fontSize: 12.8,
              fontWeight: FontWeight.w900,
              color: signedIn
                  ? _a(AppTheme.homeCream, 0.50)
                  : loginEnabled
                  ? _a(AppTheme.homeCream, 0.96)
                  : _a(AppTheme.homeCream, 0.42),
            ),
          ),
        ),
      ),
    );

    final logoutBtn = SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: logoutEnabled ? _signOut : null,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: logoutEnabled
              ? _a(AppTheme.homeCream, 0.96)
              : _a(Colors.white, 0.24),
          foregroundColor: _a(const Color(0xFF3A2147), 0.92),
          disabledBackgroundColor: _a(Colors.white, 0.24),
          disabledForegroundColor: _a(const Color(0xFF3A2147), 0.36),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
            side: BorderSide(
              color: _a(AppTheme.headerInk, logoutEnabled ? 0.20 : 0.08),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10),
          minimumSize: const Size.fromHeight(42),
        ),
        child: Text(
          "로그아웃",
          style: AppTheme.uiSmallLabel.copyWith(
            fontSize: 12.8,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.1,
            color: logoutEnabled
                ? _a(const Color(0xFF3A2147), 0.92)
                : _a(const Color(0xFF3A2147), 0.38),
          ),
        ),
      ),
    );

    if (isNarrow) {
      return Column(
        children: [
          loginBtn,
          const SizedBox(height: 8),
          logoutBtn,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: loginBtn),
        const SizedBox(width: 10),
        Expanded(child: logoutBtn),
      ],
    );
  }

  Widget _buildInfoLine(
      String label,
      String value, {
        Color? valueColor,
        bool enabled = true,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: label,
              style: AppTheme.uiSmallLabel.copyWith(
                fontSize: 12.2,
                color: enabled
                    ? _a(const Color(0xFF4E355F), 0.74)
                    : _a(const Color(0xFF4E355F), 0.34),
                fontWeight: FontWeight.w900,
              ),
            ),
            TextSpan(
              text: value,
              style: AppTheme.body.copyWith(
                fontSize: 12.6,
                height: 1.25,
                color: enabled
                    ? (valueColor ?? _a(const Color(0xFF3A2147), 0.88))
                    : _a(const Color(0xFF3A2147), 0.36),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactCountLine({
    required String label,
    required int currentCount,
    required int addedCount,
    required Color labelColor,
    required Color valueColor,
    required Color addedColor,
    bool enabled = true,
  }) {
    final disabledLabelColor = _a(const Color(0xFF4E355F), 0.34);
    final disabledValueColor = _a(const Color(0xFF3A2147), 0.36);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label : ',
              style: AppTheme.uiSmallLabel.copyWith(
                fontSize: 12.2,
                color: enabled ? labelColor : disabledLabelColor,
                fontWeight: FontWeight.w900,
              ),
            ),
            TextSpan(
              text: '$currentCount',
              style: AppTheme.body.copyWith(
                fontSize: 12.6,
                height: 1.25,
                color: enabled ? valueColor : disabledValueColor,
                fontWeight: FontWeight.w800,
              ),
            ),
            TextSpan(
              text: ' / 추가 ',
              style: AppTheme.uiSmallLabel.copyWith(
                fontSize: 12.2,
                color: enabled ? labelColor : disabledLabelColor,
                fontWeight: FontWeight.w900,
              ),
            ),
            TextSpan(
              text: '$addedCount',
              style: AppTheme.body.copyWith(
                fontSize: 12.6,
                height: 1.25,
                color: enabled ? addedColor : disabledValueColor,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required Widget child,
    EdgeInsetsGeometry? padding,
  }) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: _a(AppTheme.homeCream, 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _a(AppTheme.headerInk, 0.22),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _a(Colors.black, 0.12),
            blurRadius: 18,
            offset: const Offset(0, 12),
            spreadRadius: -8,
          ),
          BoxShadow(
            color: _a(Colors.white, 0.18),
            blurRadius: 12,
            offset: const Offset(0, -6),
            spreadRadius: -8,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildDeleteAccountTextButton({
    required bool enabled,
    required bool isNarrow,
  }) {
    return TextButton(
      onPressed: enabled ? _deleteAccount : null,
      style: TextButton.styleFrom(
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: _a(const Color(0xFFB05A6A), enabled ? 0.94 : 0.42),
      ),
      child: Text(
        '계정삭제',
        style: AppTheme.uiSmallLabel.copyWith(
          fontSize: isNarrow ? 11.2 : 11.8,
          fontWeight: FontWeight.w900,
          color: _a(const Color(0xFFB05A6A), enabled ? 0.94 : 0.42),
        ),
      ),
    );
  }

  Widget _buildAccountCard({
    required User? user,
    required bool signedIn,
    required bool isNarrow,
  }) {
    return _buildSectionCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.pets_rounded,
                  size: isNarrow ? 38 : 42,
                  color: _a(const Color(0xFF6B4E86), 0.88),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: _buildDeleteAccountTextButton(
                    enabled: !_busy,
                    isNarrow: isNarrow,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            signedIn
                ? (user?.displayName?.trim().isNotEmpty == true
                ? user!.displayName!.trim()
                : '구글 계정 연결됨')
                : '구글 로그인으로 백업을 사용할 수 있어요',
            textAlign: TextAlign.center,
            style: AppTheme.body.copyWith(
              fontSize: isNarrow ? 15.2 : 16.0,
              fontWeight: FontWeight.w900,
              color: _a(const Color(0xFF3A2147), 0.92),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              signedIn ? (user?.email ?? "로그인 정보 없음") : "로그인이 필요합니다",
              textAlign: TextAlign.center,
              style: AppTheme.uiSmallLabel.copyWith(
                fontSize: isNarrow ? 12.0 : 12.6,
                color: _a(const Color(0xFF4E355F), 0.70),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _buildActionButtons(
              signedIn: signedIn,
              isNarrow: isNarrow,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupStatusCard({
    required bool signedIn,
    required bool isNarrow,
  }) {
    final backupUiEnabled = signedIn;
    final titleColor = backupUiEnabled
        ? _a(const Color(0xFF3A2147), 0.92)
        : _a(const Color(0xFF3A2147), 0.42);
    final subTitleColor = backupUiEnabled
        ? _a(const Color(0xFF3A2147), 0.92)
        : _a(const Color(0xFF3A2147), 0.42);
    final dividerColor = backupUiEnabled
        ? _a(const Color(0xFF6B4E86), 0.14)
        : _a(const Color(0xFF6B4E86), 0.07);

    final pendingColor = _hasPendingBackup
        ? _a(const Color(0xFF8C5B00), 0.92)
        : _a(const Color(0xFF4E355F), 0.72);

    return _buildSectionCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              "Google Drive 백업",
              textAlign: TextAlign.center,
              style: AppTheme.body.copyWith(
                fontSize: isNarrow ? 14 : 15,
                fontWeight: FontWeight.w900,
                color: titleColor,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoLine(
                  "마지막 백업 : ",
                  _formatTime(_lastBackup),
                  enabled: backupUiEnabled,
                ),
                _buildInfoLine(
                  "백업 계정 : ",
                  _backupEmail ?? "없음",
                  enabled: backupUiEnabled,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            color: dividerColor,
          ),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(
              "기존 백업 상태",
              style: AppTheme.uiSmallLabel.copyWith(
                fontSize: isNarrow ? 14.6 : 15,
                fontWeight: FontWeight.w900,
                color: subTitleColor,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoLine(
                  "백업 파일 존재 여부 : ",
                  _hasRemoteBackup ? '있음' : '없음',
                  valueColor: _hasRemoteBackup
                      ? _a(const Color(0xFF6B4E86), 0.90)
                      : _a(const Color(0xFF4E355F), 0.72),
                  enabled: backupUiEnabled,
                ),
                _buildInfoLine(
                  "생성 시각 : ",
                  _formatIso(_remoteCreatedAt),
                  enabled: backupUiEnabled,
                ),
                _buildInfoLine(
                  "일기 수 : ",
                  "${_remoteDiaryCount ?? 0}",
                  enabled: backupUiEnabled,
                ),
                _buildInfoLine(
                  "아르카나 수 : ",
                  "${_remoteArcanaCount ?? 0}",
                  enabled: backupUiEnabled,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            color: dividerColor,
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(
              "추가 데이터 상태",
              style: AppTheme.uiSmallLabel.copyWith(
                fontSize: isNarrow ? 14.6 : 15,
                fontWeight: FontWeight.w900,
                color: subTitleColor,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCompactCountLine(
                  label: '일기',
                  currentCount: _localDiaryCount,
                  addedCount: _pendingDiaryCount,
                  labelColor: _a(const Color(0xFF4E355F), 0.74),
                  valueColor: _a(const Color(0xFF3A2147), 0.88),
                  addedColor: pendingColor,
                  enabled: true,
                ),
                _buildCompactCountLine(
                  label: '아르카나',
                  currentCount: _localArcanaCount,
                  addedCount: _pendingArcanaCount,
                  labelColor: _a(const Color(0xFF4E355F), 0.74),
                  valueColor: _a(const Color(0xFF3A2147), 0.88),
                  addedColor: pendingColor,
                  enabled: true,
                ),
                _buildInfoLine(
                  "백업 대기 상태 : ",
                  _hasPendingChanges ? '변경된 데이터 있음' : '없음',
                  valueColor: pendingColor,
                  enabled: true,
                ),
                const SizedBox(height: 6),
                Text(
                  _hasPendingBackup
                      ? "변경된 데이터가 있어요. 지금 백업을 권장합니다."
                      : "현재 백업이 최신 상태예요.",
                  style: AppTheme.body.copyWith(
                    fontSize: 12.4,
                    fontWeight: FontWeight.w800,
                    color: pendingColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final width = mq.size.width;
    final height = mq.size.height;

    final isTablet = mq.size.shortestSide >= 600;
    final isNarrow = width < 360;
    final isShort = height < 700;

    final double sidePad = width < 360 ? 12 : (width < 430 ? 14 : 18);

    final contentW = LayoutTokens.contentW(context);
    final cardWidth = contentW;

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                sidePad,
                LayoutTokens.scrollTopPad,
                sidePad,
                isShort ? 24 : 28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 40,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Transform.translate(
                            offset: const Offset(LayoutTokens.backBtnNudgeX, 0),
                            child: AppPressButton(
                              onTap: () => Navigator.of(context).maybePop(),
                              borderRadius: BorderRadius.circular(12),
                              normalColor: Colors.transparent,
                              pressedColor: _a(Colors.white, 0.08),
                              scaleDown: 0.96,
                              animDuration:
                              const Duration(milliseconds: 110),
                              child: SizedBox(
                                width: 40,
                                height: 40,
                                child: Center(
                                  child: Icon(
                                    Icons.arrow_back_rounded,
                                    color: _a(AppTheme.homeInkWarm, 0.96),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Center(
                          child: Text(
                            '설정',
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.title.copyWith(
                              color: _a(AppTheme.homeInkWarm, 0.96),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: AppHeaderHomeIconButton(
                            onTap: () => Navigator.of(context)
                                .pushNamedAndRemoveUntil('/', (r) => false),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: cardWidth,
                      child: StreamBuilder<User?>(
                        stream: FirebaseAuth.instance.idTokenChanges(),
                        initialData: FirebaseAuth.instance.currentUser,
                        builder: (context, snap) {
                          final user = snap.data ?? FirebaseAuth.instance.currentUser;
                          final signedIn = user != null && !user.isAnonymous;

                          //debugPrint('SETTING BUILD / snap.data = ${snap.data}');
                          //debugPrint('SETTING BUILD / firebase currentUser = ${FirebaseAuth.instance.currentUser}');
                          //debugPrint('SETTING BUILD / signedIn = $signedIn');

                          final backupButtonEnabled = signedIn && !_busy;
                          final restoreButtonEnabled = signedIn &&
                              !_busy &&
                              !_loadingBackupState &&
                              _hasRemoteBackup;

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildAccountCard(
                                user: user,
                                signedIn: signedIn,
                                isNarrow: isNarrow,
                              ),
                              const SizedBox(height: 14),
                              _buildBackupStatusCard(
                                signedIn: signedIn,
                                isNarrow: isNarrow,
                              ),
                              SizedBox(height: isTablet ? 18 : 16),
                              _buildBackupActionButtons(
                                backupEnabled: backupButtonEnabled,
                                restoreEnabled: restoreButtonEnabled,
                                isTablet: isTablet,
                              ),
                              const SizedBox(height: 18),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildBusyOverlay(),
          _buildLoadingBackupOverlay(),
        ],
      ),
    );
  }
}