import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_ui/User/job_evaluation_result_dialog.dart';
import 'package:peso_prototype/peso_ui/User/readiness_report_card.dart';

Map<String, dynamic> report({
  bool gaps = false,
  bool related = true,
  bool explicit = true,
}) => <String, dynamic>{
  'status': 'readiness',
  'job': gaps ? 'Forklift Driver' : 'Office Clerk',
  'company': 'QA Employer',
  'jobId': 'qa-job',
  'aiMatchingStatus': 'ready',
  'modelMatch': <String, dynamic>{
    'score': related ? 87 : 5,
    'confidence': explicit ? 'moderate' : 'low',
    'assessmentBasis': explicit
        ? 'role_attributed_requirements'
        : 'occupation_category_clues_only',
    'roleCriteriaCount': explicit ? 3 : 0,
    'matchedOccupationFields': related
        ? <String>['office_administration']
        : <String>[],
    'occupationFieldsToExplore': related
        ? <String>[]
        : <String>['driving_transport'],
    'missingMandatory': gaps
        ? <String>['Employer-listed professional driver license']
        : <String>[],
  },
};
void main() {
  testWidgets('congratulates on supported career match before Outcomes', (
    tester,
  ) async {
    final data = report();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: JobEvaluationResultDialog(report: data)),
      ),
    );
    expect(find.textContaining('Congratulations!'), findsOneWidget);
    expect(find.textContaining('PESO and the employer'), findsOneWidget);
    expect(find.text('View full results'), findsOneWidget);
    expect(find.text('Continue application to PESO'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a missing employer criterion prevents any congratulations', (
    tester,
  ) async {
    final data = report(gaps: true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: JobEvaluationResultDialog(report: data)),
      ),
    );
    expect(find.text('Not a Match Yet'), findsOneWidget);
    expect(find.text('What to improve before applying'), findsOneWidget);
    expect(find.textContaining('update your profile with accurate details'), findsOneWidget);
    expect(
      find.textContaining('Employer-listed professional driver license'),
      findsWidgets,
    );
    expect(find.textContaining('Congratulations'), findsNothing);
    expect(find.text('Continue application to PESO'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('alternative jobs come from saved Go evidence, not MRQ', (
    tester,
  ) async {
    final data = report(related: false, explicit: false);
    final completion = Completer<Map<String, dynamic>>();
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                selected = await showDialog<String>(
                  context: context,
                  builder: (_) => JobEvaluationResultDialog(
                    report: data,
                    loadFeedback: () => completion.future,
                  ),
                );
              },
              child: const Text('Evaluate now'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Evaluate now'));
    await tester.pump();
    expect(find.byKey(const Key('job-evaluation-popup')), findsOneWidget);
    expect(find.text('Not a Match Yet'), findsOneWidget);
    completion.complete(<String, dynamic>{
      'ok': true,
      'feedback': <String, dynamic>{
        'status': 'no_match',
        'headline': 'Other paths may fit your experience',
        'explanation': 'This occupational area differs from your existing profile. Explore these other jobs or apply through PESO.',
        'explanationSource': 'gemini',
      },
      'recommendations': [
        <String, dynamic>{
          'jobId': 'office123',
          'title': 'Office Assistant',
          'company': 'QA Employer',
        },
      ],
    });
    await tester.pumpAndSettle();
    expect(find.text('Office Assistant'), findsOneWidget);
    expect(find.textContaining('explanation by Gemini'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('recommended-role-office123')),
    );
    await tester.tap(find.byKey(const Key('recommended-role-office123')));
    await tester.pumpAndSettle();
    expect(selected, 'job:office123');
    expect((data['jobFeedback'] as Map)['recommendations'], isNotEmpty);
  });

  testWidgets(
    'report preserves Gemini explanation in Outcomes and is responsive',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final data = report(related: false, explicit: false);
      data['jobFeedback'] = <String, dynamic>{
        'feedback': <String, dynamic>{
          'headline': 'Career options to consider',
          'explanation':
              'Your current profile has limited overlap with this job.',
          'explanationSource': 'gemini',
        },
        'recommendations': [
          <String, dynamic>{'title': 'Data Encoder', 'company': 'QA Employer'},
        ],
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: ReadinessReportCard(data: data)),
          ),
        ),
      );
      expect(
        find.byKey(const Key('saved-gemini-job-explanation')),
        findsOneWidget,
      );
      expect(find.textContaining('Data Encoder'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
