import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_ui/Landingpage/site_entry_consent.dart';

void main() {
  testWidgets(
    'entry notice presents Privacy and Terms tabs and remembers only when requested',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Future<SiteNoticeDecision?>? decision;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () =>
                      decision = SiteEntryNoticeDialog.show(context),
                  child: const Text('Open notice'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open notice'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('site-entry-notice-dialog')), findsOneWidget);
      expect(find.text('PESO JOBKONEK • PROTOTYPE NOTICE'), findsOneWidget);
      expect(
        find.text(
          'Prototype status: the responsible LGU has not yet confirmed the official data controller, privacy contact, and retention schedule.',
        ),
        findsOneWidget,
      );
      final termsTab = find.byKey(const Key('site-notice-terms-tab'));
      await tester.tap(termsTab);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('TERMS AND CONDITIONS (PROTOTYPE)'),
        findsOneWidget,
      );

      await tester.tap(find.text("Don't show this again"));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('site-notice-accept')));
      await tester.pumpAndSettle();
      expect((await decision)?.remember, isTrue);
      expect(find.byKey(const Key('site-entry-notice-dialog')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'privacy settings preserve the saved checkbox state and allow clearing it',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Future<SiteNoticeDecision?>? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => result = SiteEntryNoticeDialog.show(
                    context,
                    initialRemember: true,
                  ),
                  child: const Text('Open privacy settings'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open privacy settings'));
      await tester.pumpAndSettle();
      final rememberFinder = find.byKey(
        const Key('site-notice-remember-checkbox'),
      );
      expect(tester.widget<CheckboxListTile>(rememberFinder).value, isTrue);
      await tester.tap(rememberFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('site-notice-accept')));
      await tester.pumpAndSettle();
      expect((await result)?.remember, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 390.0, 1280.0]) {
    testWidgets(
      'cookie consent is bottom-anchored, responsive and records choice at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        String? choice;
        var openedPrivacy = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: const SizedBox.expand(),
              bottomNavigationBar: CookieConsentBanner(
                onAcceptAll: () => choice = 'all-v1',
                onEssentialOnly: () => choice = 'essential-v1',
                onViewPrivacy: () => openedPrivacy = true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final banner = find.byKey(const Key('cookie-consent-banner'));
        expect(banner, findsOneWidget);
        expect(
          tester.getRect(banner).bottom,
          closeTo(844, 1),
          reason:
              'Consent choices should stay anchored to the viewport bottom.',
        );
        expect(
          tester.getRect(banner).height,
          lessThan(240),
          reason: 'The banner must shrink-wrap its content, not center it in the page.',
        );
        expect(find.text('Cookies & browser storage'), findsOneWidget);
        expect(
          find.textContaining(
            'Optional analytics and advertising cookies are off',
          ),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('cookie-learn-more')));
        await tester.pump();
        expect(openedPrivacy, isTrue);

        await tester.tap(find.byKey(const Key('cookie-essential-only')));
        await tester.pump();
        expect(choice, 'essential-v1');
        await tester.tap(find.byKey(const Key('cookie-accept-all')));
        await tester.pump();
        expect(choice, 'all-v1');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
