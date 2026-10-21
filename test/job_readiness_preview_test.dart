import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_ui/User/job_readiness_dialog.dart';
import 'package:peso_prototype/peso_ui/User/job_readiness_model.dart';
import 'package:peso_prototype/peso_ui/User/readiness_report_card.dart';

void main() {
  const operator = <String, dynamic>{
    'title': 'Bulldozer Operator',
    'company': 'Local Works',
    'location': 'Rodriguez, Rizal',
    'reqs': <String>[
      'Professional driving license',
      'Equipment safety experience',
    ],
  };

  test('role questions are limited to 10 and include equipment license', () {
    final qs = questionsForJob(operator);
    expect(qs.length, lessThanOrEqualTo(10));
    expect(qs.length, greaterThanOrEqualTo(5));
    expect(
      qs.map((q) => q.id),
      containsAll(['experience', 'driverLicense', 'schedule']),
    );
    final office = questionsForJob(const <String, dynamic>{
      'title': 'Data Encoder',
    });
    expect(office.map((q) => q.id), contains('officeTools'));
    expect(office.map((q) => q.id), isNot(contains('driverLicense')));
  });

  test('the initial AI check needs no MRQ and every industry gets exactly 10 post-AI questions', () {
    final examples = <Map<String, dynamic>>[
      operator,
      {'title': 'Software Developer'},
      {'title': 'Mall Sales Associate'},
      {'title': 'Restaurant Cook'},
      {'title': 'Staff Nurse'},
      {'title': 'Bookkeeper'},
      {'title': 'Rare Specialist Unknown'},
    ];
    for (final job in examples) {
      final questions = questionsForJob(job);
      expect(
        questions.length,
        10,
        reason: 'All industries must get exactly 10 application questions',
      );
      expect(
        questions.map((q) => q.id).toSet().length,
        10,
        reason: 'No duplicate question IDs for ${job['title']}',
      );
      final initial = buildJobReadinessReport(job, const <String, String>{});
      expect(initial['answers'], isEmpty);
      expect(initial['previewOnly'], false);
      expect(
        initial['strengths'],
        isEmpty,
        reason: 'No self-reported applicant strengths before MRQ',
      );
      expect(initial['improvements'], isEmpty);
    }
  });

  test('readiness report never issues an automated fail or decision', () {
    final answers = <String, String>{
      'experience': 'Just starting',
      'skills': 'I would like to learn',
      'driverLicense': 'None yet',
      'availability': 'Within a month',
      'interview': 'I would like interview coaching',
      'workLocation': 'I prefer nearby opportunities',
      'support': 'Skills training',
    };
    final report = buildJobReadinessReport(operator, answers);
    expect(report['status'], 'readiness');
    expect(report['previewOnly'], true);
    expect(report.containsKey('passed'), false);
    expect(report['improvements'], isA<List>());
    expect(report['strengths'], isA<List>());
    expect(report['answers'], containsPair('driverLicense', 'None yet'));
  });

  testWidgets('mobile dialog launches and can be cancelled', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog<Map<String, dynamic>>(
                  context: context,
                  builder: (_) => const JobReadinessDialog(job: operator),
                ),
                child: const Text('Evaluate job qualification'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Evaluate job qualification'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Career Readiness Studio'), findsOneWidget);
    expect(find.text('Start questions'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Close career preview'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Career Readiness Studio'), findsNothing);
  });

  testWidgets('report card renders on compact screen without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final data = buildJobReadinessReport(operator, {
      'experience': 'Just starting',
      'skills': 'I would like to learn',
      'driverLicense': 'None yet',
      'workLocation': 'I prefer nearby opportunities',
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: ReadinessReportCard(data: data)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('No pass or fail'), findsOneWidget);
    expect(find.text('What you already bring'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('a real job application is always an explicit optional action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var submissionClicks = 0;
    final report = buildJobReadinessReport(operator, <String, String>{
      'experience': 'Just starting',
      'skills': 'I would like to learn',
    });
    Widget build() => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ReadinessReportCard(
            data: report,
            onSubmitApplication: () => submissionClicks++,
          ),
        ),
      ),
    );
    await tester.pumpWidget(build());
    expect(submissionClicks, 0);
    final button = find.text('Continue application: 10 PESO questions');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    expect(submissionClicks, 1);

    report['applicationSubmitted'] = true;
    await tester.pumpWidget(build());
    await tester.pump();
    expect(find.textContaining('Application received by PESO'), findsOneWidget);
    expect(button, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'visible PESO Mini-AI progress explains the active check on mobile',
    (tester) async {
      tester.view.physicalSize = const Size(360, 750);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: JobMatchProgressOverlay(jobTitle: 'Bulldozer Operator'),
          ),
        ),
      );
      expect(
        find.text('PESO Mini-AI is checking your qualifications'),
        findsOneWidget,
      );
      expect(find.text('Bulldozer Operator'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.textContaining('not an automatic hiring decision'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'trained model alignment and qualification gaps are clearly distinguished without a rejection',
    (tester) async {
      tester.view.physicalSize = const Size(390, 840);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var submissions = 0;
      final report = buildJobReadinessReport(operator, <String, String>{
        'experience': 'Just starting',
        'driverLicense': 'None yet',
      });
      report['aiMatchingStatus'] = 'ready';
      report['modelMatch'] = <String, dynamic>{
        'score': 77,
        'readiness': 'Strong qualification alignment to review',
        'confidence': 'medium',
        'missingMandatory': <String>[],
      };
      Widget page() => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReadinessReportCard(
              data: report,
              onSubmitApplication: () => submissions++,
            ),
          ),
        ),
      );
      await tester.pumpWidget(page());
      expect(find.text('Promising qualification alignment'), findsOneWidget);
      expect(find.textContaining('77/100'), findsOneWidget);
      expect(find.text('TRAINED MODEL CHECK COMPLETE'), findsOneWidget);
      expect(tester.takeException(), isNull);

      report['modelMatch'] = <String, dynamic>{
        'score': 21,
        'readiness': 'Some relevant experience or training to build on',
        'confidence': 'medium',
        'missingMandatory': <String>['Verify required license: Professional'],
      };
      await tester.pumpWidget(page());
      expect(
        find.text('Potential qualification gaps to review'),
        findsOneWidget,
      );
      expect(find.textContaining('This is not a rejection'), findsOneWidget);
      expect(find.textContaining('Requirement to review'), findsNothing);
      final apply = find.text('Continue application: 10 PESO questions');
      await tester.ensureVisible(apply);
      await tester.tap(apply);
      await tester.pump();
      expect(submissions, 1);
      expect(tester.takeException(), isNull);

      report['modelMatch'] = <String, dynamic>{
        'score': 32,
        'readiness': 'More information needed for a reliable review',
        'confidence': 'low',
        'missingMandatory': <String>[],
      };
      await tester.pumpWidget(page());
      expect(find.text('More information needed'), findsOneWidget);
      expect(
        find.text('Partial comparison completed — review available evidence'),
        findsOneWidget,
      );
      expect(
        find.textContaining('32/100'),
        findsNothing,
        reason: 'Low-confidence synthetic alignment should not look like a pass/fail score.',
      );
      expect(
        find.textContaining('This is not a failed qualification'),
        findsOneWidget,
      );
      expect(
        find.text('Continue application: 10 PESO questions'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unattributed roles still show job-specific title signals without a fake score',
    (tester) async {
      final report = buildJobReadinessReport(operator, <String, String>{
        'skills': 'I have performed them at work',
      });
      report['aiMatchingStatus'] = 'ready';
      report['modelMatch'] = <String, dynamic>{
        'score': 73,
        'confidence': 'low',
        'readiness': 'More information needed for a reliable review',
        'assessmentBasis': 'job_title_clues_only',
        'matchedTitleClues': <String>['driving'],
        'skillsToExplore': <String>['heavy_equipment'],
        'missingMandatory': <String>[],
      };
      Widget page() => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: ReadinessReportCard(data: report)),
        ),
      );
      await tester.pumpWidget(page());
      expect(
        find.text('Job-title skills comparison completed'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Skills in your profile related to this title'),
        findsOneWidget,
      );
      expect(find.textContaining('Possible skills to explore'), findsOneWidget);
      expect(find.textContaining('73/100'), findsNothing);
      expect(tester.takeException(), isNull);

      (report['modelMatch'] as Map)['assessmentBasis'] =
          'job_details_unverified';
      await tester.pumpWidget(page());
      expect(
        find.text('Job reviewed — employer details need confirmation'),
        findsOneWidget,
      );
      expect(find.textContaining('73/100'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ISCO occupation score is labeled similarity, not hiring eligibility',
    (tester) async {
      final report = buildJobReadinessReport(
        operator,
        const <String, String>{},
      );
      report['aiMatchingStatus'] = 'ready';
      report['modelMatch'] = <String, dynamic>{
        'score': 87,
        'readiness': 'Strong occupation-category similarity to review',
        'confidence': 'moderate',
        'occupationTaxonomy': 'ISCO-08',
        'matchedOccupationFields': <String>['driving_transport'],
        'missingMandatory': <String>[],
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReadinessReportCard(data: report),
            ),
          ),
        ),
      );
      expect(
        find.text('Relevant occupation-category similarity'),
        findsOneWidget,
      );
      expect(find.text('Promising qualification alignment'), findsNothing);
      expect(find.textContaining('87/100'), findsOneWidget);
      expect(find.textContaining('does not prove'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'notice and AI-unavailable previews never falsely claim model scoring',
    (tester) async {
      final report = buildJobReadinessReport(operator, <String, String>{
        'skills': 'I would like to learn',
      });
      report['aiMatchingStatus'] = 'notice';
      Widget page() => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReadinessReportCard(
              data: report,
              onSubmitApplication: () {},
            ),
          ),
        ),
      );
      await tester.pumpWidget(page());
      expect(
        find.text('Choose an individual role for AI matching'),
        findsOneWidget,
      );
      expect(find.text('READINESS PREVIEW ONLY'), findsOneWidget);
      expect(find.text('TRAINED MODEL CHECK COMPLETE'), findsNothing);
      expect(
        find.text('Continue application: 10 PESO questions'),
        findsOneWidget,
      );

      report['aiMatchingStatus'] = 'unavailable';
      await tester.pumpWidget(page());
      expect(
        find.text('AI check unavailable — you can still apply'),
        findsOneWidget,
      );
      expect(find.text('TRAINED MODEL CHECK COMPLETE'), findsNothing);

      report['aiMatchingProblem'] = 'api_unreachable';
      await tester.pumpWidget(page());
      expect(find.text('PESO Mini-AI could not be reached'), findsOneWidget);
      report['aiMatchingProblem'] = 'unauthenticated';
      await tester.pumpWidget(page());
      expect(find.text('Sign in again to use AI matching'), findsOneWidget);
      report.remove('aiMatchingProblem');
      report['aiMatchingStatus'] = 'incomplete';
      await tester.pumpWidget(page());
      expect(find.text('AI check returned no verified result'), findsOneWidget);
      expect(
        find.text('Continue application: 10 PESO questions'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'more information needed offers editable NSRP and personal profile with recheck',
    (tester) async {
      tester.view.physicalSize = const Size(390, 890);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final data = buildJobReadinessReport(operator, {
        'skills': 'I would like to learn',
        'experience': 'Just starting',
      });
      data['modelMatch'] = <String, dynamic>{
        'score': 70,
        'readiness': 'More information needed for a reliable review',
        'confidence': 'low',
        'missingMandatory': <String>[],
      };
      var nsrpEdits = 0;
      var accountEdits = 0;
      var rechecks = 0;
      Widget screen() => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReadinessReportCard(
              data: data,
              onSubmitApplication: () {},
              onEditQualifications: () => nsrpEdits++,
              onEditPersonalInfo: () => accountEdits++,
              onRecheck: () => rechecks++,
            ),
          ),
        ),
      );
      await tester.pumpWidget(screen());
      final edit = find.byKey(const Key('edit_nsrp_from_readiness'));
      expect(edit, findsOneWidget);
      expect(find.text('Edit personal information'), findsOneWidget);
      expect(find.byKey(const Key('recheck_saved_job')), findsOneWidget);
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await tester.pump();
      expect(nsrpEdits, 1);
      await tester.tap(find.text('Edit personal information'));
      await tester.pump();
      expect(accountEdits, 1);
      await tester.tap(find.byKey(const Key('recheck_saved_job')));
      await tester.pump();
      expect(rechecks, 1);
      expect(
        find.text('Continue application: 10 PESO questions'),
        findsOneWidget,
      );

      data.remove('modelMatch');
      data['aiMatchingStatus'] = 'needs_recheck';
      await tester.pumpWidget(screen());
      expect(find.text('Your qualifications were saved'), findsOneWidget);
      expect(
        find.textContaining('recheck this job when ready'),
        findsOneWidget,
      );
      expect(find.text('TRAINED MODEL CHECK COMPLETE'), findsNothing);
      expect(
        find.text('Continue application: 10 PESO questions'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
