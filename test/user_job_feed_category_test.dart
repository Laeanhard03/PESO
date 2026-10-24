import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_models/job_posting.dart';
import 'package:peso_prototype/peso_ui/User/user_job_feed_tab.dart';

void main() {
  testWidgets('job feed category chips filter the correct job postings',
      (WidgetTester tester) async {
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
            final visibleJobs = jobs.where((job) =>
                (selectedCategory == PesoJobCategories.all ||
                    job['category'] == selectedCategory) &&
                (selectedCompany.isEmpty || job['company'] == selectedCompany)).toList();
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
    expect(find.widgetWithText(ChoiceChip, 'Government Internship Program (GIP)'), findsOneWidget);

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

    await tester.tap(find.widgetWithText(ChoiceChip, 'Government Internship Program (GIP)'));
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
}
