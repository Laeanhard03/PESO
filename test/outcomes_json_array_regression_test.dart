import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_ui/User/user_outcomes_tab.dart';

void main() {
  Widget outcomesPage(Map<String, dynamic> outcome) {
    return MaterialApp(
      home: Scaffold(
        body: UserOutcomesTab(
          assessmentOutcomes: [outcome],
          translate: (value) => value,
          primary: const Color(0xFF236349),
          textDark: const Color(0xFF17352B),
          textLight: const Color(0xFF52675D),
        ),
      ),
    );
  }

  for (final width in <double>[360, 768, 1366]) {
    testWidgets('JSON-decoded action plan renders at ${width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // jsonDecode deliberately produces List<dynamic>, like saved API data.
      final outcome = Map<String, dynamic>.from(
        jsonDecode('''
        {
          "status": "action_plan",
          "job": "Business Data Analyst",
          "company": "Rizal Operations Group",
          "score": 52,
          "failed_skills": ["Data visualization", "Advanced spreadsheets"],
          "alt_jobs": ["Data Encoder", "Operations Assistant"],
          "training": "Data analytics fundamentals"
        }
      ''') as Map,
      );

      expect(outcome['failed_skills'], isA<List<dynamic>>());
      expect(outcome['alt_jobs'], isA<List<dynamic>>());

      await tester.pumpWidget(outcomesPage(outcome));
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('Identified Skill Gaps'), findsOneWidget);
      expect(find.text('Data visualization'), findsOneWidget);
      expect(find.text('Alternative Local Jobs'), findsOneWidget);
      expect(find.text('Data Encoder'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('missing or malformed saved lists fail gracefully', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final outcome = <String, dynamic>{
      'status': 'action_plan',
      'job': 'Assistant',
      'company': 'Local office',
      'score': 54,
      'failed_skills': <dynamic>['', null, {}, 'Digital skills'],
      'alt_jobs': 'Not an array',
      'training': null,
    };
    await tester.pumpWidget(outcomesPage(outcome));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Digital skills'), findsOneWidget);
    expect(find.text('No training recommendation recorded.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
