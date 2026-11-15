import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:peso_prototype/peso_ui/Reusable_Designs/design_tokens.dart';
import 'package:peso_prototype/peso_ui/Reusable_Designs/responsive_layout.dart';

void main() {
  group('pesoListingGrid keeps the featured listing cards responsive', () {
    test('desktop lays out three cards per row without overflow', () {
      const available = 1280 - (PesoTokens.spacing2XL * 2);
      final grid = pesoListingGrid(
        availableWidth: available,
        spacing: PesoTokens.spacingLG,
      );

      expect(grid.columns, 3);
      expect(
        (grid.cardWidth * 3) + (PesoTokens.spacingLG * 2),
        lessThanOrEqualTo(available + 0.01),
      );
      expect(grid.cardWidth, greaterThanOrEqualTo(280));
    });

    test('tablet lays out two cards per row', () {
      const available = 800 - (PesoTokens.spacing2XL * 2);
      final grid = pesoListingGrid(
        availableWidth: available,
        spacing: PesoTokens.spacingLG,
      );

      expect(grid.columns, 2);
      expect(
        (grid.cardWidth * 2) + PesoTokens.spacingLG,
        lessThanOrEqualTo(available + 0.01),
      );
    });

    test('mobile lays out one card per row', () {
      const available = 390 - (PesoTokens.spacingMD * 2);
      final grid = pesoListingGrid(
        availableWidth: available,
        spacing: PesoTokens.spacingLG,
      );

      expect(grid.columns, 1);
      expect(grid.cardWidth, closeTo(available, 0.01));
    });

    test('never returns a negative width on a tiny surface', () {
      final grid = pesoListingGrid(
        availableWidth: 0,
        spacing: PesoTokens.spacingLG,
      );

      expect(grid.columns, 1);
      expect(grid.cardWidth, 0);
    });
  });

  testWidgets(
    'equal-height card rows stretch shorter cards and align their actions',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Widget card(String id, double contentHeight) {
        return Container(
          key: ValueKey('$id-card'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFDCE5E0)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(height: contentHeight),
              SizedBox(key: ValueKey('$id-action'), width: 100, height: 24),
            ],
          ),
        );
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: EqualHeightCardGrid(
                columns: 2,
                spacing: 16,
                children: [
                  card('short', 100),
                  card('tall', 220),
                  card('next-row', 80),
                ],
              ),
            ),
          ),
        ),
      );

      final shortCard = tester.getRect(
        find.byKey(const ValueKey('short-card')),
      );
      final tallCard = tester.getRect(find.byKey(const ValueKey('tall-card')));
      final nextRowCard = tester.getRect(
        find.byKey(const ValueKey('next-row-card')),
      );
      final shortAction = tester.getRect(
        find.byKey(const ValueKey('short-action')),
      );
      final tallAction = tester.getRect(
        find.byKey(const ValueKey('tall-action')),
      );

      expect(shortCard.height, closeTo(tallCard.height, 0.01));
      expect(shortCard.width, closeTo(tallCard.width, 0.01));
      expect(shortAction.bottom, closeTo(tallAction.bottom, 0.01));
      expect(nextRowCard.height, lessThan(shortCard.height));
      expect(tester.takeException(), isNull);
    },
  );
}
