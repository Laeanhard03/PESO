import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_ui/exampage_ui.dart';

void main() {
  for (final size in <Size>[
    const Size(360, 800),
    const Size(768, 1024),
    const Size(1366, 900),
  ]) {
    testWidgets('AI assessment fits ${size.width.toInt()}px viewport',
        (WidgetTester tester) async {
      tester.view.physicalSize = size;
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

      expect(find.text('Live AI Assessment Engine'), findsOneWidget);
      expect(find.textContaining('Which architectural pattern'), findsOneWidget);
      expect(find.text('Next Question'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
