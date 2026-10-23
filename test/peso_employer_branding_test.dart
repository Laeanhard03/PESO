import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_ui/Reusable_Designs/peso_employer_branding.dart';

void main() {
  group('PesoEmployerBranding', () {
    test('recognizes JCRCC aliases without depending on punctuation or case', () {
      expect(
        PesoEmployerBranding.logoAssetForCompany(
          'JCRCC (J. C. RODRIGUEZ CONSTRUCTION CORPORATION)',
        ),
        PesoEmployerBranding.jcrccLogoAsset,
      );
      expect(
        PesoEmployerBranding.logoAssetForCompany(
          'J. C. Rodriguez Construction Corporation',
        ),
        PesoEmployerBranding.jcrccLogoAsset,
      );
    });

    test('recognizes Puregold Price Club and Puregold branch names', () {
      expect(
        PesoEmployerBranding.logoAssetForCompany('PUREGOLD PRICE CLUB, INC.'),
        PesoEmployerBranding.puregoldLogoAsset,
      );
      expect(
        PesoEmployerBranding.logoAssetForCompany('Puregold Montalban'),
        PesoEmployerBranding.puregoldLogoAsset,
      );
    });

    test('uses title only when the saved company name is empty', () {
      expect(
        PesoEmployerBranding.logoAssetForJob({
          'company': '',
          'title': 'NOW HIRING - JCRCC Construction',
        }),
        PesoEmployerBranding.jcrccLogoAsset,
      );
      expect(
        PesoEmployerBranding.logoAssetForJob({
          'company': 'Independent Employer',
          'title': 'Puregold cashier',
        }),
        isNull,
      );
    });

    test('does not assign an invented logo to an unknown employer', () {
      expect(PesoEmployerBranding.logoAssetForCompany('Independent Employer'), isNull);
      expect(PesoEmployerBranding.logoAssetForCompany(null), isNull);
    });

    test('official employer logo files are present in the bundled assets', () {
      expect(File(PesoEmployerBranding.jcrccLogoAsset).existsSync(), isTrue);
      expect(File(PesoEmployerBranding.puregoldLogoAsset).existsSync(), isTrue);
    });

    testWidgets('JCRCC logo widget resolves the official bundled asset', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: SizedBox(
          width: 64,
          height: 64,
          child: PesoEmployerLogo(company: 'JCRCC', size: 24),
        ),
      ));
      await tester.pumpAndSettle();
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<AssetImage>());
      expect((image.image as AssetImage).assetName, PesoEmployerBranding.jcrccLogoAsset);
    });

    testWidgets('Puregold logo widget resolves the official bundled asset', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: SizedBox(
          width: 88,
          height: 50,
          child: PesoEmployerLogo(company: 'Puregold Price Club, Inc.', size: 24),
        ),
      ));
      await tester.pumpAndSettle();
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<AssetImage>());
      expect((image.image as AssetImage).assetName, PesoEmployerBranding.puregoldLogoAsset);
    });
  });
}
