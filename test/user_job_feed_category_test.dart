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
    final jobs = <Map<String, dynamic>>[walkIn, lra];

    var selectedCategory = PesoJobCategories.all;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            final visibleJobs = jobs.where((job) =>
                selectedCategory == PesoJobCategories.all ||
                job['category'] == selectedCategory).toList();
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

    await tester.tap(find.byType(ChoiceChip).at(2));
    await tester.pump(const Duration(milliseconds: 550));
    expect(find.text('LRA Data Encoder'), findsOneWidget);
    expect(find.text('Walk-in Office Assistant'), findsNothing);
    expect(selectedCategory, PesoJobCategories.localRecruitmentActivity);

    await tester.tap(find.byType(ChoiceChip).at(1));
    await tester.pump(const Duration(milliseconds: 550));
    expect(find.text('Walk-in Office Assistant'), findsOneWidget);
    expect(find.text('LRA Data Encoder'), findsNothing);
    expect(selectedCategory, PesoJobCategories.walkInApplication);
    expect(tester.takeException(), isNull);
  });
}
