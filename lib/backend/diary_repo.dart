import 'dart:async';

import 'diary_local.dart';

// ✅ legacy (기존 Firebase) 가져오기용 - 파일은 그대로 두기로 했지?
import 'auth_service.dart';
import 'diary_firestore.dart';

/// ✅ 앱에서 화면들이 바라볼 단일 진입점(Repository)
/// - 기본 저장소: SQLite (DiaryLocal)
/// - (선택) 기존 Firestore -> SQLite 마이그레이션 지원
///
/// 화면에서는 앞으로 이 Repo만 쓰면 됨:
/// DiaryRepo.I.read/save/listMonthEntryKeys ...
class DiaryRepo {
  DiaryRepo._();
  static final DiaryRepo I = DiaryRepo._();

  /// 기본 저장소: 로컬
  final DiaryLocal _local = DiaryLocal.instance;

  // -------------------------------------------------------
  // ✅ Public API (UI에서 사용하는 메서드들)
  // -------------------------------------------------------

  /// DateTime -> "yyyy-MM-dd" (공유 헬퍼)
  String dateKeyOf(DateTime dt) => DiaryLocal.dateKeyOf(dt);

  DateTime dateOnly(DateTime dt) => DiaryLocal.dateOnly(dt);

  /// ✅ 일기 1개 읽기 (없으면 null)
  /// 반환 포맷은 DiaryFirestore.read와 호환( cards: List<int> )
  Future<Map<String, dynamic>?> read({
    required DateTime date,
  }) async {
    return _local.read(uid: _localUid, date: date);
  }

  /// ✅ 존재 여부
  Future<bool> exists({
    required DateTime date,
  }) async {
    return _local.exists(uid: _localUid, date: date);
  }

  /// ✅ 저장
  Future<void> save({
    required DateTime date,
    required int cardCount,
    required List<int> cards,
    required String beforeText,
    required String afterText,
  }) async {
    await _local.save(
      uid: _localUid,
      date: date,
      cardCount: cardCount,
      cards: cards,
      beforeText: beforeText,
      afterText: afterText,
    );
  }

  /// ✅ 삭제
  Future<void> delete({
    required DateTime date,
  }) async {
    await _local.delete(uid: _localUid, date: date);
  }

  /// ✅ 월 dot 표시용 key set
  Future<Set<int>> listMonthEntryKeys({
    required DateTime month,
  }) async {
    return _local.listMonthEntryKeys(uid: _localUid, month: month);
  }

  /// ✅ 월의 모든 일기 가져오기
  Future<List<Map<String, dynamic>>> listMonthDocs({
    required DateTime month,
  }) async {
    return _local.listMonthDocs(uid: _localUid, month: month);
  }

  // -------------------------------------------------------
  // ✅ 마이그레이션 (Firestore -> SQLite)
  // -------------------------------------------------------
  // - "기존 데이터 가져오기" 버튼에서만 호출 추천
  // - 로컬에 이미 값이 있으면 기본적으로 SKIP 하고,
  //   옵션으로 overwrite 가능

  /// 현재 로컬 저장소는 uid를 쓰지 않지만 호환용 더미
  static const String _localUid = 'local';

  /// Firestore에서 month에 해당하는 모든 일기를 가져와 SQLite에 저장.
  /// 반환: { imported, skipped, failed } 카운트
  ///
  /// - overwrite=false: 로컬에 이미 해당 dateKey 있으면 skip
  /// - overwrite=true : 로컬이 있어도 덮어씀
  Future<MigrationResult> migrateMonthFromFirestore({
    required DateTime month,
    bool overwrite = false,
  }) async {
    // ✅ 구글 로그인(기존 AuthService 재사용)
    final user = await AuthService.ensureSignedIn();
    final uid = user.uid;

    final docs = await DiaryFirestore.listMonthDocs(uid: uid, month: month);

    int imported = 0;
    int skipped = 0;
    int failed = 0;

    for (final d in docs) {
      try {
        final dateKey = (d['dateKey'] ?? '').toString();
        if (dateKey.isEmpty) {
          failed++;
          continue;
        }

        // dateKey -> DateTime
        final parts = dateKey.split('-');
        if (parts.length != 3) {
          failed++;
          continue;
        }
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final dd = int.tryParse(parts[2]);
        if (y == null || m == null || dd == null) {
          failed++;
          continue;
        }
        final date = DateTime(y, m, dd);

        if (!overwrite) {
          final has = await _local.exists(uid: _localUid, date: date);
          if (has) {
            skipped++;
            continue;
          }
        }

        final cardCount = (d['cardCount'] is num)
            ? (d['cardCount'] as num).toInt()
            : int.tryParse((d['cardCount'] ?? '1').toString()) ?? 1;

        final cardsRaw = d['cards'];
        final cards = (cardsRaw is List)
            ? cardsRaw.map((e) => int.tryParse(e.toString()) ?? 0).toList()
            : <int>[];

        final beforeText = (d['beforeText'] ?? '').toString();
        final afterText = (d['afterText'] ?? '').toString();

        await _local.save(
          uid: _localUid,
          date: date,
          cardCount: cardCount,
          cards: cards,
          beforeText: beforeText,
          afterText: afterText,
        );

        imported++;
      } catch (_) {
        failed++;
      }
    }

    return MigrationResult(imported: imported, skipped: skipped, failed: failed);
  }

  /// Firestore에서 특정 날짜 1개를 가져와 SQLite에 저장.
  Future<bool> migrateOneFromFirestore({
    required DateTime date,
    bool overwrite = false,
  }) async {
    final user = await AuthService.ensureSignedIn();
    final uid = user.uid;

    final data = await DiaryFirestore.read(uid: uid, date: date);
    if (data == null) return false;

    if (!overwrite) {
      final has = await _local.exists(uid: _localUid, date: date);
      if (has) return false;
    }

    final cardCount = (data['cardCount'] is num)
        ? (data['cardCount'] as num).toInt()
        : int.tryParse((data['cardCount'] ?? '1').toString()) ?? 1;

    final cardsRaw = data['cards'];
    final cards = (cardsRaw is List)
        ? cardsRaw.map((e) => int.tryParse(e.toString()) ?? 0).toList()
        : <int>[];

    final beforeText = (data['beforeText'] ?? '').toString();
    final afterText = (data['afterText'] ?? '').toString();

    await _local.save(
      uid: _localUid,
      date: date,
      cardCount: cardCount,
      cards: cards,
      beforeText: beforeText,
      afterText: afterText,
    );

    return true;
  }
}

/// 마이그레이션 결과
class MigrationResult {
  final int imported;
  final int skipped;
  final int failed;

  const MigrationResult({
    required this.imported,
    required this.skipped,
    required this.failed,
  });

  @override
  String toString() =>
      'MigrationResult(imported: $imported, skipped: $skipped, failed: $failed)';
}
