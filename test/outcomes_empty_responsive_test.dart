import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_ui/User/user_outcomes_tab.dart';

void main() {
  for (final size in <Size>[
    const Size(360, 800),
    const Size(390, 844),
    const Size(768, 1024),
  ]) {
    testWidgets('empty Outcomes state fits responsive viewport',
        (WidgetTester tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserOutcomesTab(
              assessmentOutcomes: const <Map<String, dynamic>>[],
              translate: (value) => value,
              primary: Colors.green,
              textDark: Colors.black87,
              textLight: Colors.black54,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('No Assessments Evaluated Yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
