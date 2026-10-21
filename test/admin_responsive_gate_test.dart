import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_ui/Admin/admin_ui.dart';

void main() {
  for (final size in <Size>[
    const Size(360, 800),
    const Size(768, 1024),
    const Size(1366, 900),
  ]) {
    testWidgets('Admin verification gate fits ${size.width.toInt()}px viewport',
        (WidgetTester tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: AdminDashboard()),
      );
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Protected Admin Area'), findsOneWidget);
      expect(find.text('Verify and unlock Admin'), findsOneWidget);
      expect(
        find.textContaining(
          'Admin access is based on the MongoDB user profile role.',
        ),
        findsOneWidget,
      );
      expect(find.text('Applicant Analytics'), findsNothing);
      expect(find.textContaining('DEVELOPMENT PREVIEW'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
