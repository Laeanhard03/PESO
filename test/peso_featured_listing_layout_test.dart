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
}
