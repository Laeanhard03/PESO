import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_ui/User/user_job_feed_tab.dart';

void main() {
  Widget screen({
    required bool loading,
    String? error,
    VoidCallback? retry,
  }) => MaterialApp(
    home: Scaffold(
      body: UserJobFeedTab(
        userName: 'Test applicant',
        availableJobs: const [],
        jobsLoading: loading,
        jobLoadError: error,
        onRetryJobs: retry,
        selectedJob: null,
        onSelectJob: (_) {},
        onEvaluateJob: (_) {},
        translate: (text) => text,
        primary: const Color(0xFF236349),
        textDark: const Color(0xFF17352B),
        textLight: const Color(0xFF52675D),
      ),
    ),
  );

  testWidgets('initial loading is not misrepresented as zero vacancies', (tester) async {
    tester.view.physicalSize = const Size(1200, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(screen(loading: true));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Loading published PESO vacancies...'), findsOneWidget);
    expect(find.byKey(const ValueKey('retry-peso-jobs')), findsNothing);
  });

  testWidgets('API failures remain visible and allow retry', (tester) async {
    tester.view.physicalSize = const Size(1200, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var attempts = 0;
    await tester.pumpWidget(screen(
      loading: false,
      error: 'Could not connect to the PESO job service.',
      retry: () => attempts++,
    ));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Could not connect to the PESO job service.'), findsOneWidget);
    final control = find.byKey(const ValueKey('retry-peso-jobs'));
    expect(control, findsOneWidget);
    await tester.ensureVisible(control);
    await tester.tap(control);
    expect(attempts, 1);
  });
}
