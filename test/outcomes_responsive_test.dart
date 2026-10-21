import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_ui/User/user_outcomes_tab.dart';

void main() {
  final outcomes = <Map<String, dynamic>>[
    <String, dynamic>{
      'status': 'passed',
      'job': 'Senior Application Support Specialist',
      'company': 'Montalban Technology Partners',
      'score': 96,
      'message': 'Your background meets the requirements for this role.',
    },
    <String, dynamic>{
      'status': 'action_plan',
      'job': 'Business Data Analyst',
      'company': 'Rizal Operations Group',
      'score': 52,
      'failed_skills': <String>['Data visualization', 'Advanced spreadsheet modeling', 'Business intelligence reporting'],
      'alt_jobs': <String>['Data Encoder', 'Operations Assistant'],
      'training': 'Data analytics fundamentals',
    },
  ];

  for (final size in <Size>[
    const Size(360, 800),
    const Size(768, 1024),
    const Size(1366, 900),
  ]) {
    testWidgets('outcome cards fit ${size.width.toInt()}px viewport',
        (WidgetTester tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserOutcomesTab(
              assessmentOutcomes: outcomes,
              translate: (value) => value,
              primary: Colors.green,
              textDark: Colors.black87,
              textLight: Colors.black54,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.text('Outcomes & Action Plans'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
