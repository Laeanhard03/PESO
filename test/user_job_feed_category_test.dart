import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_logic/job_interest_recommendations.dart';
import 'package:peso_prototype/peso_models/job_posting.dart';
import 'package:peso_prototype/peso_ui/User/user_job_feed_tab.dart';

void main() {
  testWidgets('job feed category chips filter the correct job postings', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const walkIn = <String, dynamic>{
      'id': 'walk-in-id',
      'title': 'Walk-in Office Assistant',
      'company': 'Local Employer',
      'location': 'Rodriguez, Rizal',
      'salary': 'PHP 16,000',
      'type': 'Full-time',
      'vacancies': '2',
      'match': 0,
      'image': 'https://example.invalid/walk-in.jpg',
      'description': 'Walk-in role.',
      'reqs': <String>[],
      'category': PesoJobCategories.walkInApplication,
      'status': 'active',
    };
    const lra = <String, dynamic>{
      'id': 'lra-id',
      'title': 'LRA Data Encoder',
      'company': 'PESO Recruitment',
      'location': 'Rodriguez, Rizal',
      'salary': 'PHP 18,000',
      'type': 'Contract',
      'vacancies': '1',
      'match': 0,
      'image': 'https://example.invalid/lra.jpg',
      'description': 'Short-term local recruitment role.',
      'reqs': <String>[],
      'category': PesoJobCategories.localRecruitmentActivity,
      'status': 'active',
      'createdAt': '2026-10-17T06:00:00.000Z',
      'expiresAt': '2026-10-18T06:00:00.000Z',
    };
    const seap = <String, dynamic>{
      'id': 'seap-id',
      'title': 'SEAP Trainee',
      'company': 'SEAP Partner',
      'location': 'Rodriguez, Rizal',
      'salary': 'Program allowance varies',
      'type': 'Internship',
      'vacancies': '2',
      'match': 0,
      'image': 'https://example.invalid/seap.jpg',
      'description': 'SEAP program opportunity.',
      'reqs': <String>[],
      'category': PesoJobCategories.seap,
      'status': 'active',
    };
    const gip = <String, dynamic>{
      'id': 'gip-id',
      'title': 'GIP Intern',
      'company': 'GIP Partner',
      'location': 'Rodriguez, Rizal',
      'salary': 'Program allowance varies',
      'type': 'Internship',
      'vacancies': '3',
      'match': 0,
      'image': 'https://example.invalid/gip.jpg',
      'description': 'Government Internship Program opportunity.',
      'reqs': <String>[],
      'category': PesoJobCategories.gip,
      'status': 'active',
    };
    final jobs = <Map<String, dynamic>>[walkIn, lra, seap, gip];

    var selectedCategory = PesoJobCategories.all;
    var selectedCompany = '';
    const companies = ['Local Employer', 'PESO Recruitment'];
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            final visibleJobs = jobs
                .where(
                  (job) =>
                      (selectedCategory == PesoJobCategories.all ||
                          job['category'] == selectedCategory) &&
                      (selectedCompany.isEmpty ||
                          job['company'] == selectedCompany),
                )
                .toList();
            return Scaffold(
              body: UserJobFeedTab(
                userName: 'Test User',
                availableJobs: visibleJobs,
                selectedJob: null,
                onSelectJob: (_) {},
                onEvaluateJob: (_) {},
                translate: (value) => value,
                primary: Colors.green,
                textDark: Colors.black,
                textLight: Colors.grey,
                selectedCategory: selectedCategory,
                onCategoryChanged: (category) {
                  setState(() => selectedCategory = category);
                },
                companyOptions: companies,
                selectedCompany: selectedCompany,
                onCompanyChanged: (company) {
                  setState(() => selectedCompany = company);
                },
              ),
            );
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump(const Duration(milliseconds: 550));

    expect(find.text('Walk-in Office Assistant'), findsOneWidget);
    expect(find.text('LRA Data Encoder'), findsOneWidget);
    expect(find.text('SEAP Trainee'), findsOneWidget);
    expect(find.text('GIP Intern'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'SEAP Program'), findsOneWidget);
    expect(
      find.widgetWithText(ChoiceChip, 'Government Internship Program (GIP)'),
      findsOneWidget,
    );

    await tester.tap(find.byType(ChoiceChip).at(2));
    await tester.pump(const Duration(milliseconds: 550));
    expect(find.text('LRA Data Encoder'), findsOneWidget);
    expect(find.text('Walk-in Office Assistant'), findsNothing);
    expect(find.text('SEAP Trainee'), findsNothing);
    expect(find.text('GIP Intern'), findsNothing);
    expect(selectedCategory, PesoJobCategories.localRecruitmentActivity);

    await tester.tap(find.byType(ChoiceChip).at(1));
    await tester.pump(const Duration(milliseconds: 550));
    expect(find.text('Walk-in Office Assistant'), findsOneWidget);
    expect(find.text('LRA Data Encoder'), findsNothing);
    expect(find.text('SEAP Trainee'), findsNothing);
    expect(find.text('GIP Intern'), findsNothing);
    expect(selectedCategory, PesoJobCategories.walkInApplication);

    await tester.tap(find.widgetWithText(ChoiceChip, 'SEAP Program'));
    await tester.pump(const Duration(milliseconds: 550));
    expect(find.text('SEAP Trainee'), findsOneWidget);
    expect(find.text('GIP Intern'), findsNothing);
    expect(find.text('Walk-in Office Assistant'), findsNothing);

    await tester.tap(
      find.widgetWithText(ChoiceChip, 'Government Internship Program (GIP)'),
    );
    await tester.pump(const Duration(milliseconds: 550));
    expect(find.text('GIP Intern'), findsOneWidget);
    expect(find.text('SEAP Trainee'), findsNothing);
    expect(find.text('LRA Data Encoder'), findsNothing);

    await tester.tap(find.byType(ChoiceChip).first);
    await tester.pump(const Duration(milliseconds: 550));
    await tester.pump(const Duration(milliseconds: 550));
    await tester.tap(find.byKey(const Key('user-job-company-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PESO Recruitment').last);
    await tester.pump(const Duration(milliseconds: 550));
    expect(find.text('LRA Data Encoder'), findsOneWidget);
    expect(find.text('Walk-in Office Assistant'), findsNothing);
    expect(selectedCompany, 'PESO Recruitment');
    expect(tester.takeException(), isNull);
  });

  test('only validated role-attributed Go evidence exposes a field-similarity percentage', () {
    const jobs = <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'role-1',
        'title': 'Data Entry Clerk',
        'description': 'Enter and verify records.',
        'requirements': <String>[],
        'reqs': <String>[],
      },
    ];
    Map<String, dynamic> readyEvidence({
      num score = 87.6,
      String confidence = 'medium',
      List<String> missing = const <String>[],
      String assessmentBasis = 'role_attributed_requirements',
    }) => <String, dynamic>{
      'status': 'ready',
      'results': <Map<String, dynamic>>[
        <String, dynamic>{
          'jobId': 'role-1',
          'score': score,
          'assessmentBasis': assessmentBasis,
          'roleCriteriaCount': 4,
          'confidence': confidence,
          'missingMandatory': missing,
        },
      ],
    };

    final valid = rankJobOpportunities(
      jobs,
      preferredOccupations: 'Data Entry Clerk',
      goMatching: readyEvidence(),
    );
    expect(valid.single['fieldSimilarityScore'], 88);

    final mandatoryGap = rankJobOpportunities(
      jobs,
      preferredOccupations: 'Data Entry Clerk',
      goMatching: readyEvidence(missing: const <String>['required license']),
    );
    expect(mandatoryGap.single.containsKey('fieldSimilarityScore'), isFalse);

    final lowConfidence = rankJobOpportunities(
      jobs,
      preferredOccupations: 'Data Entry Clerk',
      goMatching: readyEvidence(confidence: 'low'),
    );
    expect(lowConfidence.single.containsKey('fieldSimilarityScore'), isFalse);

    final unsupportedBasis = rankJobOpportunities(
      jobs,
      preferredOccupations: 'Data Entry Clerk',
      goMatching: readyEvidence(assessmentBasis: 'title_similarity'),
    );
    expect(
      unsupportedBasis.single.containsKey('fieldSimilarityScore'),
      isFalse,
    );

    final pending = rankJobOpportunities(
      jobs,
      preferredOccupations: 'Data Entry Clerk',
      goMatching: <String, dynamic>{'status': 'pending', 'results': []},
    );
    expect(pending.single.containsKey('fieldSimilarityScore'), isFalse);

    final notice = rankJobOpportunities(
      const <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'role-1',
          'title': 'Data Entry Clerk',
          'aiListingKind': 'notice',
        },
      ],
      preferredOccupations: 'Data Entry Clerk',
      goMatching: readyEvidence(),
    );
    expect(notice.single.containsKey('fieldSimilarityScore'), isFalse);
  });

  testWidgets(
    'job vacancy cards display validated field similarity as a percentage',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const job = <String, dynamic>{
        'id': 'scored-role',
        'title': 'Data Entry Clerk',
        'company': 'PESO Partner',
        'location': 'Rodriguez, Rizal',
        'salary': 'PHP 18,000',
        'type': 'Full-time',
        'vacancies': '2',
        'fieldSimilarityScore': 88,
        'image': '',
        'description': 'Enter and verify records.',
        'reqs': <String>[],
        'category': PesoJobCategories.walkInApplication,
        'status': 'active',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserJobFeedTab(
              userName: 'Test User',
              availableJobs: const <Map<String, dynamic>>[job],
              selectedJob: null,
              onSelectJob: (_) {},
              onEvaluateJob: (_) {},
              translate: (value) => value,
              primary: Colors.green,
              textDark: Colors.black,
              textLight: Colors.grey,
              selectedCategory: PesoJobCategories.all,
              onCategoryChanged: (_) {},
              companyOptions: const <String>[],
              selectedCompany: '',
              onCompanyChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pump(const Duration(milliseconds: 550));

      expect(find.text('Field similarity 88%'), findsOneWidget);
      expect(find.text('Field similarity 88/100'), findsNothing);
      expect(
        find.byTooltip(
          'Field similarity is based on the Go Mini-AI role-attributed criteria. It is not a probability of being hired or proof that you meet every requirement.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
