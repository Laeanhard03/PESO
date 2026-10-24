import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_ui/Admin/admin_ui.dart';
import 'package:peso_prototype/peso_ui/User/user_ai_profile_tab.dart';
import 'package:peso_prototype/peso_ui/User/user_job_feed_tab.dart';
import 'package:peso_prototype/peso_ui/User/user_ui.dart';

void main() {
  testWidgets('Jobseeker Back returns to job feed rather than signing out',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: UserProfile()));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.byTooltip('Open dashboard navigation'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));
    final profileItem = find.byWidgetPredicate(
      (widget) => widget is PopupMenuItem<int> && widget.value == 1,
    );
    expect(profileItem, findsOneWidget);
    await tester.tap(profileItem);
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(UserAiProfileTab), findsOneWidget);

    // The widget-test root route has no browser history. Dispatch the same
    // cancelled PopScope event that the real browser Back delivers instead.
    final popScope = tester.widget<PopScope<Object?>>(
      find.descendant(
        of: find.byType(UserProfile),
        matching: find.byType(PopScope<Object?>),
      ),
    );
    expect(popScope.canPop, isFalse);
    popScope.onPopInvokedWithResult!(false, null);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(UserJobFeedTab), findsOneWidget);
    // AnimatedSwitcher briefly retains the outgoing AI profile; finish exit.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(UserProfile), findsOneWidget);
    expect(find.byType(UserAiProfileTab), findsNothing);

    final homeScope = tester.widget<PopScope<Object?>>(
      find.descendant(
        of: find.byType(UserProfile),
        matching: find.byType(PopScope<Object?>),
      ),
    );
    homeScope.onPopInvokedWithResult!(false, null);
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byType(UserProfile), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Admin verification Back never signs out or exits the gate',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AdminDashboard()));
    expect(find.text('Protected Admin Area'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('Protected Admin Area'), findsOneWidget);
    expect(find.byType(AdminDashboard), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}