// lib/ui/arcana_labels.dart

class ArcanaLabels {
  ArcanaLabels._();

  /// ✅ 78장 파일명 (0~77)
  static const List<String> kTarotFileNames = [
    "00-TheFool.png",
    "01-TheMagician.png",
    "02-TheHighPriestess.png",
    "03-TheEmpress.png",
    "04-TheEmperor.png",
    "05-TheHierophant.png",
    "06-TheLovers.png",
    "07-TheChariot.png",
    "08-Strength.png",
    "09-TheHermit.png",
    "10-WheelOfFortune.png",
    "11-Justice.png",
    "12-TheHangedMan.png",
    "13-Death.png",
    "14-Temperance.png",
    "15-TheDevil.png",
    "16-TheTower.png",
    "17-TheStar.png",
    "18-TheMoon.png",
    "19-TheSun.png",
    "20-Judgement.png",
    "21-TheWorld.png",
    "22-AceOfWands.png",
    "23-TwoOfWands.png",
    "24-ThreeOfWands.png",
    "25-FourOfWands.png",
    "26-FiveOfWands.png",
    "27-SixOfWands.png",
    "28-SevenOfWands.png",
    "29-EightOfWands.png",
    "30-NineOfWands.png",
    "31-TenOfWands.png",
    "32-PageOfWands.png",
    "33-KnightOfWands.png",
    "34-QueenOfWands.png",
    "35-KingOfWands.png",
    "36-AceOfCups.png",
    "37-TwoOfCups.png",
    "38-ThreeOfCups.png",
    "39-FourOfCups.png",
    "40-FiveOfCups.png",
    "41-SixOfCups.png",
    "42-SevenOfCups.png",
    "43-EightOfCups.png",
    "44-NineOfCups.png",
    "45-TenOfCups.png",
    "46-PageOfCups.png",
    "47-KnightOfCups.png",
    "48-QueenOfCups.png",
    "49-KingOfCups.png",
    "50-AceOfSwords.png",
    "51-TwoOfSwords.png",
    "52-ThreeOfSwords.png",
    "53-FourOfSwords.png",
    "54-FiveOfSwords.png",
    "55-SixOfSwords.png",
    "56-SevenOfSwords.png",
    "57-EightOfSwords.png",
    "58-NineOfSwords.png",
    "59-TenOfSwords.png",
    "60-PageOfSwords.png",
    "61-KnightOfSwords.png",
    "62-QueenOfSwords.png",
    "63-KingOfSwords.png",
    "64-AceOfPentacles.png",
    "65-TwoOfPentacles.png",
    "66-ThreeOfPentacles.png",
    "67-FourOfPentacles.png",
    "68-FiveOfPentacles.png",
    "69-SixOfPentacles.png",
    "70-SevenOfPentacles.png",
    "71-EightOfPentacles.png",
    "72-NineOfPentacles.png",
    "73-TenOfPentacles.png",
    "74-PageOfPentacles.png",
    "75-KnightOfPentacles.png",
    "76-QueenOfPentacles.png",
    "77-KingOfPentacles.png",
  ];

  // =========================
  // ✅ 메이저 한글 이름 (0~21)
  // =========================
  static const List<String> majorKo = [
    '바보', '마법사', '고위 여사제', '여황제', '황제', '교황', '연인',
    '전차', '힘', '은둔자', '운명의 수레바퀴', '정의', '매달린 사람',
    '죽음', '절제', '악마', '탑', '별', '달', '태양', '심판', '세계',
  ];

  static String? majorKoName(int id) {
    if (id < 0 || id >= majorKo.length) return null;
    return majorKo[id];
  }

  // =========================
  // ✅ 파일명 -> 영문 표시용 타이틀 ("00-TheFool.png" => "The Fool")
  // =========================
  static String prettyEnTitleFromFilename(String filename) {
    var s = filename.replaceAll('.png', '');

    final dash = s.indexOf('-');
    if (dash >= 0 && dash + 1 < s.length) s = s.substring(dash + 1);

    s = s.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}');
    return s;
  }

  // =========================
  // ✅ 마이너: 파일명에서 (한글) 만들기
  // 규칙:
  // - Ace: "에이스 완즈"
  // - 2~10: "완즈 2" ... "완즈 10"
  // - Page/Knight/Queen/King: "완즈 시종/기사/여왕/왕"
  // =========================
  static String? minorKoFromFilename(String filename) {
    final base = filename.replaceAll('.png', '');

    // suit
    String suit;
    if (base.contains('Wands')) suit = '완즈';
    else if (base.contains('Cups')) suit = '컵';
    else if (base.contains('Swords')) suit = '소드';
    else if (base.contains('Pentacles') || base.contains('Coins')) suit = '펜타클';
    else return null;

    // rank + formatting rule
    if (base.contains('AceOf')) {
      return '에이스 $suit'; // ✅ 에이스만 앞에
    }

    // numbers
    if (base.contains('TwoOf')) return '$suit 2';
    if (base.contains('ThreeOf')) return '$suit 3';
    if (base.contains('FourOf')) return '$suit 4';
    if (base.contains('FiveOf')) return '$suit 5';
    if (base.contains('SixOf')) return '$suit 6';
    if (base.contains('SevenOf')) return '$suit 7';
    if (base.contains('EightOf')) return '$suit 8';
    if (base.contains('NineOf')) return '$suit 9';
    if (base.contains('TenOf')) return '$suit 10';

    // courts
    if (base.contains('PageOf')) return '$suit 페이지';
    if (base.contains('KnightOf')) return '$suit 나이트';
    if (base.contains('QueenOf')) return '$suit 퀸';
    if (base.contains('KingOf')) return '$suit 킹';

    return null;
  }

  // =========================
  // ✅ 리스트 타이틀: "0. The Fool (바보)" / "22. Ace Of Wands (에이스 완즈)"
  // =========================
  static String listTitle({
    required int id,
    required String enTitle,
    String? filename,
  }) {
    final koMajor = majorKoName(id);
    if (koMajor != null) return '$id. $enTitle ($koMajor)';

    final koMinor = (filename == null) ? null : minorKoFromFilename(filename);
    if (koMinor != null && koMinor.isNotEmpty) return '$id. $enTitle ($koMinor)';

    return '$id. $enTitle';
  }
}

