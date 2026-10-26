import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_ui/Admin/admin_landing_content_section.dart';

Future<void> pumpEditor(
  WidgetTester tester, {
  Future<Map<String, dynamic>> Function(Map<String, dynamic>)? save,
  Size size = const Size(900, 1000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AdminLandingContentSection(
          loadContent: () async => {
            'gallery': <dynamic>[],
            'partners': <dynamic>[],
          },
          saveContent: save,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> showAndTap(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Only one page of thumbnails is built and each bundle can be selected',
    (tester) async {
      await pumpEditor(tester);

      expect(find.text('Gallery photos'), findsNWidgets(2));
      expect(find.text('Employer partners'), findsOneWidget);
      expect(find.byKey(const Key('landing-gallery-select-0')), findsOneWidget);
      expect(find.byKey(const Key('landing-gallery-select-7')), findsOneWidget);
      expect(find.byKey(const Key('landing-gallery-select-8')), findsNothing);
      expect(find.byType(Image), findsNWidgets(8));
      await showAndTap(tester, const Key('landing-gallery-next'));
      expect(find.byKey(const Key('landing-gallery-select-8')), findsOneWidget);
      expect(find.byKey(const Key('landing-gallery-select-0')), findsNothing);

      await showAndTap(tester, const Key('landing-partner-tab'));
      expect(find.byKey(const Key('landing-partner-select-0')), findsOneWidget);
      expect(find.byKey(const Key('landing-partner-select-8')), findsNothing);
      await showAndTap(tester, const Key('landing-partner-select-0'));
      expect(find.byKey(const Key('landing-partner-name')), findsOneWidget);
      expect(
        find.byKey(const Key('landing-partner-image-url')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('landing-partner-website')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Partner selection edit and replacement preserve gallery defaults',
    (tester) async {
      Map<String, dynamic>? saved;
      await pumpEditor(
        tester,
        save: (value) async {
          saved = Map<String, dynamic>.from(value);
          return {...value};
        },
      );
      await showAndTap(tester, const Key('landing-partner-tab'));
      await showAndTap(tester, const Key('landing-partner-select-0'));
      await tester.enterText(
        find.byKey(const Key('landing-partner-name')),
        'Jollibee Updated',
      );
      await tester.enterText(
        find.byKey(const Key('landing-partner-image-url')),
        'https://example.org/new-logo.png',
      );
      await tester.enterText(
        find.byKey(const Key('landing-partner-website')),
        'https://example.org/partner',
      );
      await showAndTap(tester, const Key('landing-content-save'));

      expect(saved, isNotNull);
      expect(saved!['galleryConfigured'], false);
      expect((saved!['gallery'] as List), isEmpty);
      expect(saved!['partnersConfigured'], true);
      final partners = (saved!['partners'] as List)
          .cast<Map<String, dynamic>>();
      expect(partners, hasLength(15));
      expect(partners.first['name'], 'Jollibee Updated');
      expect(partners.first['logoUrl'], 'https://example.org/new-logo.png');
      expect(partners.first['websiteUrl'], 'https://example.org/partner');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Admin can delete a selected bundled partner with confirmation', (
    tester,
  ) async {
    Map<String, dynamic>? saved;
    await pumpEditor(
      tester,
      save: (value) async {
        saved = Map<String, dynamic>.from(value);
        return {...value};
      },
    );
    await showAndTap(tester, const Key('landing-partner-tab'));
    await showAndTap(tester, const Key('landing-partner-select-0'));
    await showAndTap(tester, const Key('landing-partner-remove-0'));
    expect(find.text('Remove selected partner?'), findsOneWidget);
    await tester.tap(find.text('Remove partner'));
    await tester.pumpAndSettle();
    await showAndTap(tester, const Key('landing-content-save'));
    final partners = (saved!['partners'] as List).cast<Map<String, dynamic>>();
    expect(partners, hasLength(14));
    expect(partners.any((p) => p['name'] == 'Jollibee'), isFalse);
    expect(saved!['partnersConfigured'], true);
  });

  testWidgets(
    'Gallery editing retains bundled images and validates new photos',
    (tester) async {
      Map<String, dynamic>? saved;
      await pumpEditor(
        tester,
        save: (payload) async {
          saved = Map<String, dynamic>.from(payload);
          return {...payload};
        },
      );
      await showAndTap(tester, const Key('landing-gallery-select-0'));
      await tester.enterText(
        find.byKey(const Key('landing-gallery-caption')),
        'Updated recruitment photo',
      );
      await showAndTap(tester, const Key('landing-content-save'));
      final gallery = (saved!['gallery'] as List).cast<Map<String, dynamic>>();
      expect(gallery, hasLength(26));
      expect(gallery.first['caption'], 'Updated recruitment photo');
      expect(saved!['partnersConfigured'], false);
      expect((saved!['partners'] as List), isEmpty);

      await showAndTap(tester, const Key('landing-gallery-add'));
      expect(
        find.byKey(const Key('landing-gallery-select-26')),
        findsOneWidget,
      );
      await showAndTap(tester, const Key('landing-content-save'));
      expect(
        find.textContaining('Each gallery photo needs a title'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Editor remains usable on a compact phone', (tester) async {
    await pumpEditor(tester, size: const Size(375, 810));
    await showAndTap(tester, const Key('landing-partner-tab'));
    await showAndTap(tester, const Key('landing-partner-select-0'));
    expect(find.byKey(const Key('landing-partner-image-url')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
