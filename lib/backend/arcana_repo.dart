// lib/backend/arcana_repo.dart
import 'dart:async';
import 'arcana_local.dart';

/// ✅ 화면들은 앞으로 ArcanaRepo만 사용
/// - 저장소: SQLite(ArcanaLocal)
/// - uid는 호환용 더미(local)
class ArcanaRepo {
  ArcanaRepo._();
  static final ArcanaRepo I = ArcanaRepo._();

  final ArcanaLocal _local = ArcanaLocal.instance;

  /// 현재 로컬 저장소는 uid를 쓰지 않지만 호환용 더미
  static const String _localUid = 'local';

  // -------------------------------------------------------
  // ✅ Public API
  // -------------------------------------------------------

  Future<Map<String, dynamic>?> read({
    required int cardId,
  }) async {
    return _local.read(uid: _localUid, cardId: cardId);
  }

  Future<bool> exists({
    required int cardId,
  }) async {
    return _local.exists(uid: _localUid, cardId: cardId);
  }

  Future<void> save({
    required int cardId,
    String? title,
    required String meaning,
    required String myNote,
    required String tags,
  }) async {
    await _local.save(
      uid: _localUid,
      cardId: cardId,
      title: title,
      meaning: meaning,
      myNote: myNote,
      tags: tags,
    );
  }

  Future<void> delete({
    required int cardId,
  }) async {
    await _local.delete(uid: _localUid, cardId: cardId);
  }

  /// ✅ 저장된 row만 전체 리스트(최근 수정순)
  Future<List<Map<String, dynamic>>> listAll({
    bool newestFirst = true,
  }) async {
    final rows = await _local.listAll(uid: _localUid);

    // ✅ sqflite 결과(rows)는 read-only일 수 있으니 mutable 복사본으로 정렬
    final list = rows.map((e) => Map<String, dynamic>.from(e)).toList();

    list.sort((a, b) {
      final aT = _toInt(a['updatedAt']);
      final bT = _toInt(b['updatedAt']);

      if (aT != null && bT != null) {
        return newestFirst ? bT.compareTo(aT) : aT.compareTo(bT);
      }

      final aId = _toInt(a['cardId']) ?? 0;
      final bId = _toInt(b['cardId']) ?? 0;
      return newestFirst ? bId.compareTo(aId) : aId.compareTo(bId);
    });

    return list;
  }

  Future<Set<int>> listCardIdsHavingNotes() async {
    final rows = await _local.listAll(uid: _localUid);
    final set = <int>{};
    for (final r in rows) {
      final id = _toInt(r['cardId']);
      if (id != null) set.add(id);
    }
    return set;
  }

  // -------------------------------------------------------
  // ✅ DEBUG: DB 상태 출력
  // -------------------------------------------------------
  Future<void> debugDump() async {
    await _local.debugPrintAllRows(tag: 'ARCANA_REPO');
  }

  // -------------------------------------------------------
  // ✅ helpers
  // -------------------------------------------------------
  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }
}
