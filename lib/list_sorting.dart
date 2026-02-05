// lib/list_sorting.dart
import 'package:flutter/material.dart';

/// ✅ 공용 리스트 정렬 타입 (다른 리스트에서도 재사용)
enum ListSort {
  numberAsc,
  numberDesc,
  nameAsc,
  nameDesc,
}

/// ✅ 드롭다운에 표시할 라벨
String listSortLabel(ListSort s) {
  switch (s) {
    case ListSort.numberAsc:
      return '번호 ↑';
    case ListSort.numberDesc:
      return '번호 ↓';
    case ListSort.nameAsc:
      return '이름 A→Z';
    case ListSort.nameDesc:
      return '이름 Z→A';
  }
}

/// ✅ 아이콘(요청한 “화살표+가나다/ABC” 느낌을 최대한 머터리얼로)
IconData listSortIcon(ListSort s) {
  switch (s) {
    case ListSort.nameAsc:
      return Icons.sort_by_alpha; // A→Z 느낌
    case ListSort.nameDesc:
      return Icons.sort_by_alpha; // 동일 아이콘 + 라벨로 구분(깔끔)
    case ListSort.numberAsc:
      return Icons.format_list_numbered; // 1,2,3 느낌
    case ListSort.numberDesc:
      return Icons.format_list_numbered; // 동일 아이콘 + 라벨로 구분
  }
}

/// ✅ 정렬 비교 함수 (어떤 리스트든 id/title만 주면 됨)
int compareListSort(
    ListSort sort, {
      required int idA,
      required int idB,
      required String titleA,
      required String titleB,
    }) {
  switch (sort) {
    case ListSort.numberAsc:
      return idA.compareTo(idB);
    case ListSort.numberDesc:
      return idB.compareTo(idA);
    case ListSort.nameAsc:
      return titleA.compareTo(titleB);
    case ListSort.nameDesc:
      return titleB.compareTo(titleA);
  }
}
