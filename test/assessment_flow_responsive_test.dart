import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_ui/exampage_ui.dart';

void main() {
  testWidgets('compact assessment moves into a responsive visual-match grid',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: AIExamPage(
          jobTitle: 'Senior Application Support Specialist',
          company: 'Montalban Technology Partners',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));

    final answer = find.text('BLoC / Clean Architecture');
    await tester.ensureVisible(answer);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(answer);
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Next Question'));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.textContaining('Analyze the visual schemas below'), findsOneWidget);
    expect(find.byType(GridView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
