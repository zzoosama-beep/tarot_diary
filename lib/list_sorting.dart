import 'package:flutter/material.dart';

/// ✅ 공용 리스트 정렬 타입
enum ListSort {
  numberAsc,
  numberDesc,
  nameAsc,
  nameDesc,
}

/// ✅ 드롭다운 라벨
/// 너무 길면 작은 기기에서 UI를 망가뜨리므로 짧게 유지
String listSortLabel(ListSort s) {
  switch (s) {
    case ListSort.numberAsc:
      return '번호↑';
    case ListSort.numberDesc:
      return '번호↓';
    case ListSort.nameAsc:
      return '이름ㄱ↑';
    case ListSort.nameDesc:
      return '이름ㅎ↓';
  }
}

/// ✅ 아이콘
IconData listSortIcon(ListSort s) {
  switch (s) {
    case ListSort.nameAsc:
      return Icons.sort_by_alpha;
    case ListSort.nameDesc:
      return Icons.sort_by_alpha;
    case ListSort.numberAsc:
      return Icons.format_list_numbered;
    case ListSort.numberDesc:
      return Icons.format_list_numbered;
  }
}

String _normalizeSpaces(String text) {
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// 앞 숫자 prefix 제거
/// 예:
/// "0. 바보" -> "바보"
/// "22 완즈 2" -> "완즈 2"
/// "10-운명의 수레바퀴" -> "운명의 수레바퀴"
String _stripLeadingDeckNumber(String text) {
  return text.replaceFirst(RegExp(r'^\s*\d{1,2}\s*[-.:)]?\s*'), '').trim();
}

/// 정렬용 제목 정리
String _normalizeSortTitle(String text) {
  return _normalizeSpaces(_stripLeadingDeckNumber(text));
}

/// ✅ 정렬 비교 함수
/// - 번호 정렬: id 기준
/// - 이름 정렬: 앞 숫자 제거 후 title 기준
/// - 같은 이름이면 id로 보조 정렬
int compareListSort(
    ListSort sort, {
      required int idA,
      required int idB,
      required String titleA,
      required String titleB,
    }) {
  final normalizedA = _normalizeSortTitle(titleA);
  final normalizedB = _normalizeSortTitle(titleB);

  switch (sort) {
    case ListSort.numberAsc:
      return idA.compareTo(idB);

    case ListSort.numberDesc:
      return idB.compareTo(idA);

    case ListSort.nameAsc:
      final cmp = normalizedA.compareTo(normalizedB);
      if (cmp != 0) return cmp;
      return idA.compareTo(idB);

    case ListSort.nameDesc:
      final cmp = normalizedB.compareTo(normalizedA);
      if (cmp != 0) return cmp;
      return idB.compareTo(idA);
  }
}