import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_ui/Reusable_Designs/peso_green_texture.dart';

void main() {
  testWidgets('green texture remains decorative and preserves button taps', (
    WidgetTester tester,
  ) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              height: 140,
              child: DecoratedBox(
                decoration: const BoxDecoration(color: Color(0xFF174B37)),
                child: PesoGreenTextureLayer(
                  tone: PesoGreenTextureTone.dark,
                  child: Center(
                    child: ElevatedButton(
                      onPressed: () => taps++,
                      child: const Text('Continue'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(PesoGreenTextureOverlay), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all texture tones render and disabled layers stay untouched', (
    WidgetTester tester,
  ) async {
    for (final tone in PesoGreenTextureTone.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 240,
              height: 120,
              child: PesoGreenTextureLayer(
                tone: tone,
                child: const Center(child: Text('Branded surface')),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(PesoGreenTextureOverlay), findsOneWidget);
      expect(find.text('Branded surface'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 240,
            height: 120,
            child: PesoGreenTextureLayer(
              enabled: false,
              child: Center(child: Text('Untouched surface')),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(PesoGreenTextureOverlay), findsNothing);
    expect(find.text('Untouched surface'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
