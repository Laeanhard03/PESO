import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_ui/Admin/admin_user_management_section.dart';

void main() {
  for (final size in <Size>[
    const Size(360, 800),
    const Size(768, 1024),
    const Size(1366, 900),
  ]) {
    testWidgets('admin user-management controls fit ${size.width.toInt()}px viewport',
        (WidgetTester tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AdminUserManagementSection()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 450));

      expect(find.text('Search registered users'), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
