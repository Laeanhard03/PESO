import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_ui/Reusable_Designs/peso_images.dart';

void main() {
  const fallback = PesoImageAssets.jobDefault;

  testWidgets('blank URL immediately renders the bundled fallback', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          height: 180,
          child: PesoNetworkImage(imageUrl: '  ', fallbackAsset: fallback),
        ),
      ),
    ));

    expect(_findAsset(fallback), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed remote image displays the bundled fallback', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          height: 180,
          child: PesoNetworkImage(
            imageUrl: 'https://missing-image.invalid/job-banner.jpg',
            fallbackAsset: fallback,
          ),
        ),
      ),
    ));

    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(_findAsset(fallback), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Finder _findAsset(String path) => find.byWidgetPredicate((widget) {
      if (widget is! Image || widget.image is! AssetImage) return false;
      return (widget.image as AssetImage).assetName == path;
    });
