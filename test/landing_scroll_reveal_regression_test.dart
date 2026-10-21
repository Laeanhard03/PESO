import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_ui/Landingpage/landingpage_ui.dart';
import 'package:peso_prototype/peso_ui/Reusable_Designs/adaptive_nav_bar.dart';

void main() {
  testWidgets(
    'landing reveals offscreen programs and reverses nav color near top',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: LandingPage()));
      await tester.pump(const Duration(milliseconds: 650));
      final nav = find.byType(AdaptiveNavBar);
      expect(tester.widget<AdaptiveNavBar>(nav).isScrolled, isFalse);

      final programs = find.byKey(
        const ValueKey<String>('home-programs-scroll-reveal'),
      );
      final fades = find.descendant(
        of: programs,
        matching: find.byType(FadeTransition),
      );
      expect(programs, findsOneWidget);
      expect(fades, findsWidgets);
      expect(
        tester.widget<FadeTransition>(fades.first).opacity.value,
        closeTo(0, 0.001),
      );

      // Session 5 replaced the old static copy with the source-backed
      // government services catalog; scroll to the section's stable key.
      await tester.ensureVisible(programs);
      await tester.pumpAndSettle();
      expect(tester.widget<AdaptiveNavBar>(nav).isScrolled, isTrue);
      expect(
        tester.widget<FadeTransition>(fades.first).opacity.value,
        closeTo(1, 0.001),
      );

      // Return fully to the top (one mobile-sized drag need not cover the
      // entire long landing page).
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      scrollable.position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(tester.widget<AdaptiveNavBar>(nav).isScrolled, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
