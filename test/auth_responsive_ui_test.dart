import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_ui/Login_register_pages/auth_ui.dart';

void main() {
  for (final size in <Size>[
    const Size(360, 800),
    const Size(768, 1024),
    const Size(1366, 900),
  ]) {
    testWidgets('authentication card fits ${size.width.toInt()}px viewport',
        (WidgetTester tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: AuthPage(initialIsLogin: true)),
      );
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Your Gateway to\nLocal Opportunities.'), findsOneWidget);
      final googleButton = find.ancestor(
        of: find.text('Google'),
        matching: find.byType(OutlinedButton),
      );
      expect(googleButton, findsOneWidget);
      final fieldSize = tester.getSize(find.byType(TextField).first);
      final googleButtonSize = tester.getSize(googleButton);
      expect(
        (googleButtonSize.width - fieldSize.width).abs(),
        lessThan(1.5),
        reason: 'Google sign-in should align to the full login-field width',
      );
      final googleContent = find.byKey(
        const ValueKey<String>('google-sign-in-content'),
      );
      expect(googleContent, findsOneWidget);
      expect(
        (tester.getCenter(googleContent).dx -
                tester.getCenter(googleButton).dx)
            .abs(),
        lessThan(2),
        reason: 'Google icon and label should be centered inside the button',
      );
      expect(tester.takeException(), isNull);
    });
  }
}
