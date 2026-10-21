import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_ui/Landingpage/landingpage_ui.dart';
import 'package:peso_prototype/peso_ui/Reusable_Designs/hero_section.dart';
import 'package:peso_prototype/peso_ui/Reusable_Designs/peso_theme.dart';

void main() {
  const capture = bool.fromEnvironment('PESO_CAPTURE_DESIGN');
  setUpAll(() async {
    if (capture && Platform.isWindows) {
      final file = File(r'C:\Windows\Fonts\segoeui.ttf');
      if (await file.exists()) {
        final loader = FontLoader('Roboto')
          ..addFont(
            Future.value(ByteData.sublistView(await file.readAsBytes())),
          );
        await loader.load();
      }
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    }
  });

  for (final width in [320.0, 768.0, 1440.0]) {
    testWidgets('refreshed landing fits $width with the application theme', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: capture
              ? PesoTheme.light.copyWith(
                  textTheme: PesoTheme.light.textTheme.apply(
                    fontFamily: 'Roboto',
                  ),
                )
              : PesoTheme.light,
          home: RepaintBoundary(key: key, child: const LandingPage()),
        ),
      );
      if (capture) {
        await tester.runAsync(() async {
          await precacheImage(
            const AssetImage('lib/assets/peso_hero_career.jpg'),
            key.currentContext!,
          );
          await precacheImage(
            const AssetImage('lib/assets/peso_app_icon.png'),
            key.currentContext!,
          );
        });
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Create an account'), findsOneWidget);
      if (capture) {
        // Replace the test-only Ahem face in the rendered preview, including
        // button styles. Production widgets and their styles remain untouched.
        InlineSpan realText(InlineSpan span) {
          if (span is! TextSpan) return span;
          final style = span.style ?? const TextStyle();
          return TextSpan(
            text: span.text,
            style: style.fontFamily == 'MaterialIcons'
                ? style
                : style.copyWith(fontFamily: 'Roboto'),
            children: span.children?.map(realText).toList(),
          );
        }

        void applyFonts(RenderObject object) {
          if (object is RenderParagraph) object.text = realText(object.text);
          object.visitChildren(applyFonts);
        }

        applyFonts(key.currentContext!.findRenderObject()!);
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
      if (capture) {
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final snapshot = await boundary.toImage();
          final bytes = await snapshot.toByteData(
            format: ui.ImageByteFormat.png,
          );
          final dir = Directory('build/design_review');
          await dir.create(recursive: true);
          await File('${dir.path}/landing_${width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          snapshot.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('hero actions remain usable with large text and reduced motion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var primary = 0;
    var secondary = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: PesoTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 1000),
            textScaler: TextScaler.linear(1.5),
            disableAnimations: true,
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: HeroSection(
                onPrimaryTap: () => primary++,
                onSecondaryTap: () => secondary++,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Explore Job Openings'));
    await tester.tap(find.text('Explore Job Openings'));
    await tester.ensureVisible(find.text('Create an account'));
    await tester.tap(find.text('Create an account'));
    expect(primary, 1);
    expect(secondary, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
