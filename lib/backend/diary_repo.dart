import 'diary_local.dart';

/// ✅ 앱에서 화면들이 바라볼 단일 진입점(Repository)
/// - 저장소: SQLite ONLY
/// - Firebase / Firestore 전혀 안 씀
class DiaryRepo {
  DiaryRepo._();
  static final DiaryRepo I = DiaryRepo._();

  final DiaryLocal _local = DiaryLocal.instance;

  /// 내부 uid (로컬 전용)
  static const String _uid = 'local';

  // ------------------------------
  // Helpers
  // ------------------------------
  String dateKeyOf(DateTime dt) => DiaryLocal.dateKeyOf(dt);
  DateTime dateOnly(DateTime dt) => DiaryLocal.dateOnly(dt);

  // ------------------------------
  // CRUD
  // ------------------------------
  Future<Map<String, dynamic>?> read({
    required DateTime date,
  }) {
    return _local.read(uid: _uid, date: date);
  }

  Future<bool> exists({
    required DateTime date,
  }) {
    return _local.exists(uid: _uid, date: date);
  }

  Future<void> save({
    required DateTime date,
    required int cardCount,
    required List<int> cards,
    required String beforeText,
    required String afterText,
  }) {
    return _local.save(
      uid: _uid,
      date: date,
      cardCount: cardCount,
      cards: cards,
      beforeText: beforeText,
      afterText: afterText,
    );
  }

  Future<void> delete({
    required DateTime date,
  }) {
    return _local.delete(uid: _uid, date: date);
  }

  // ------------------------------
  // Calendar helpers
  // ------------------------------
  Future<Set<int>> listMonthEntryKeys({
    required DateTime month,
  }) {
    return _local.listMonthEntryKeys(uid: _uid, month: month);
  }

  Future<List<Map<String, dynamic>>> listMonthDocs({
    required DateTime month,
  }) {
    return _local.listMonthDocs(uid: _uid, month: month);
  }
}
