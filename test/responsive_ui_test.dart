import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_ui/Landingpage/landingpage_ui.dart';

void main() {
  for (final size in <Size>[
    const Size(360, 800),
    const Size(768, 1024),
    const Size(1366, 900),
  ]) {
    testWidgets('landing page fits ${size.width.toInt()}px viewport',
        (WidgetTester tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: LandingPage()),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('Your next opportunity\nstarts here.'),
          findsOneWidget);
      expect(find.text('Explore Job Openings'), findsOneWidget);
      final pesoLogos = find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'lib/assets/peso_app_icon.png',
      );
      expect(pesoLogos, findsNWidgets(3),
          reason: 'Landing navigation, hero, and footer should each show the PESO logo');
      expect(
        find.ancestor(of: pesoLogos, matching: find.byType(ClipOval)),
        findsNWidgets(3),
        reason: 'All three landing PESO marks should use circular image clipping',
      );
      expect(tester.takeException(), isNull);
    });
  }
}
