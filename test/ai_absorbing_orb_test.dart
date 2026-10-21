import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_ui/Reusable_Designs/ai_processing_ui.dart';

void main() {
  testWidgets('AI absorbing orb animates and fits a compact viewport', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const vsync = TestVSync();
    final pulse = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    final orbit = AnimationController(
      vsync: vsync,
      duration: const Duration(seconds: 10),
    )..repeat();
    addTearDown(pulse.dispose);
    addTearDown(orbit.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AIAbsorbingOrb(
              pulseAnimation: pulse,
              orbitAnimation: orbit,
              primary: const Color(0xFF2E7D32),
              compact: true,
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('ai-absorbing-orb')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.psychology_alt_rounded), findsOneWidget);
    final before = tester
        .widget<RotationTransition>(
          find.byKey(const ValueKey<String>('ai-orbiting-particles')),
        )
        .turns
        .value;

    await tester.pump(const Duration(milliseconds: 850));

    final after = tester
        .widget<RotationTransition>(
          find.byKey(const ValueKey<String>('ai-orbiting-particles')),
        )
        .turns
        .value;
    expect(after, isNot(before));
    pulse.stop();
    orbit.stop();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
