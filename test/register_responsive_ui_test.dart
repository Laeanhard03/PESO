import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_ui/Login_register_pages/auth_ui.dart';

void main() {
  for (final size in <Size>[
    const Size(360, 800),
    const Size(768, 1024),
    const Size(1366, 900),
  ]) {
    testWidgets('registration card fits ${size.width.toInt()}px viewport',
        (WidgetTester tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: AuthPage(initialIsLogin: false)),
      );
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Create Account'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
