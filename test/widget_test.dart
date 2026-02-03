import 'package:flutter_test/flutter_test.dart';
import 'package:tarot_diary/main.dart';

void main() {
  testWidgets('Hello World 화면이 표시된다', (WidgetTester tester) async {
    await tester.pumpWidget(const TarotDiaryApp());

    expect(find.text('Hello World'), findsOneWidget);
  });
}
