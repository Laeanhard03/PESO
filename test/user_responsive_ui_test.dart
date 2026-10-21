import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_ui/User/user_ui.dart';

void main() {
  for (final size in <Size>[
    const Size(360, 800),
    const Size(768, 1024),
    const Size(1366, 900),
  ]) {
    testWidgets('user dashboard fits ${size.width.toInt()}px viewport',
        (WidgetTester tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: UserProfile()));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('JobKonek'), findsOneWidget);
      final pesoLogo = find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'lib/assets/peso_app_icon.png',
      );
      expect(pesoLogo, findsOneWidget);
      expect(tester.getSize(pesoLogo).width, greaterThanOrEqualTo(40));
      expect(
        find.ancestor(of: pesoLogo, matching: find.byType(ClipOval)),
        findsOneWidget,
        reason: 'Dashboard app logo should be large and circular',
      );
      expect(tester.takeException(), isNull);
    });
  }
}
