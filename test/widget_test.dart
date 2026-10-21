import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/main.dart';
import 'package:peso_prototype/peso_ui/Admin/admin_ui.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PesoApp());
    expect(find.text('JobKonek'), findsOneWidget);

    // Dispose before the entrance delay elapses to verify the delayed start is cancellable.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Admin dashboard gate explains MongoDB-backed Admin authorization',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: AdminDashboard()));
      expect(find.text('Protected Admin Area'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(
        find.textContaining('MongoDB user profile has role=admin'),
        findsOneWidget,
      );
      expect(find.text('Open Google Cloud Shell'), findsNothing);
      expect(find.text('Copy admin-access setup command'), findsNothing);
      expect(find.text('Firebase administrator email'), findsOneWidget);
      expect(find.text('Verify and unlock Admin'), findsOneWidget);
      expect(
        find.text('Verify current Firebase session instead'),
        findsOneWidget,
      );
      expect(find.text('Applicant Analytics'), findsNothing);
      expect(find.textContaining('DEVELOPMENT PREVIEW'), findsNothing);
    },
  );
}
