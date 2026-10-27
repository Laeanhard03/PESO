import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:peso_prototype/peso_ui/Landingpage/peso_public_services.dart';
import 'package:peso_prototype/peso_ui/Landingpage/landingpage_ui.dart';
import 'package:peso_prototype/peso_ui/Landingpage/jobkonek_tutorial.dart';
import 'package:peso_prototype/peso_ui/Reusable_Designs/peso_images.dart';
import 'package:peso_prototype/peso_ui/Reusable_Designs/reusable_ui.dart';

void main() {
  void setSize(WidgetTester tester, double width, double height) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, height);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Widget servicesApp() => const MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: PesoPublicServices())),
  );

  test(
    'Service catalog has sources, unique identifiers, and requested programs',
    () {
      final services = PesoPublicServices.catalog;
      expect(services.length, greaterThanOrEqualTo(18));
      expect(services.map((s) => s.code).toSet().length, services.length);
      for (final service in services) {
        final uri = Uri.parse(service.sourceUrl);
        expect(uri.scheme, 'https');
        expect(uri.host, isNotEmpty);
        expect(uri.host.endsWith('.phx'), isFalse);
        expect(service.details, isNotEmpty);
        expect(service.group, isNotEmpty);
      }
      expect(services.any((s) => s.code == 'SEAP'), isTrue);
      expect(services.any((s) => s.code == 'GIP'), isTrue);
      expect(services.any((s) => s.code == 'SPES'), isTrue);
      expect(services.any((s) => s.code == 'ofw-reintegration'), isFalse);
      expect(
        services.any((s) => s.title.toLowerCase().contains('returning ofw')),
        isFalse,
      );
    },
  );

  testWidgets('Services are searchable and GIP details open on mobile', (
    tester,
  ) async {
    setSize(tester, 390, 850);
    await tester.pumpWidget(servicesApp());
    expect(find.byKey(const Key('service-card-SEAP')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('peso-service-search')), 'GIP');
    await tester.pump();
    expect(find.byKey(const Key('service-card-GIP')), findsOneWidget);
    expect(find.byKey(const Key('service-card-SPES')), findsNothing);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('service-card-GIP')),
        matching: find.text('View details'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('service-detail-GIP')), findsOneWidget);
    expect(find.text('Availability in Montalban'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('service-detail-GIP')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Desktop service categories filter correctly', (tester) async {
    setSize(tester, 1280, 900);
    await tester.pumpWidget(servicesApp());
    expect(find.byKey(const Key('service-card-job-matching')), findsOneWidget);
    await tester.tap(find.text('Programs & benefits'));
    await tester.pump();
    expect(find.byKey(const Key('service-card-job-matching')), findsNothing);
    expect(find.byKey(const Key('service-card-GIP')), findsOneWidget);
    expect(find.byKey(const Key('service-card-SEAP')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Footer SEAP and GIP shortcuts work on narrow mobile', (
    tester,
  ) async {
    setSize(tester, 320, 760);
    String? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: GlobalFooter(
              pesoGreen: Colors.green,
              onTabSelected: (_) {},
              onScrollToTop: () {},
              onServiceRequested: (value) => opened = value,
            ),
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.text('SEAP'));
    await tester.tap(find.text('SEAP'));
    await tester.pump();
    expect(opened, 'SEAP');
    await tester.ensureVisible(find.text('GIP'));
    await tester.tap(find.text('GIP'));
    await tester.pump();
    expect(opened, 'GIP');
    expect(find.text('Official Montalban LGU Website ?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Footer email is clickable and layout survives zoom-sized widths',
    (tester) async {
      for (final width in <double>[1920, 1280, 1024, 768, 560, 520, 390, 320]) {
        setSize(tester, width, 900);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: GlobalFooter(
                  pesoGreen: Colors.green,
                  onTabSelected: (_) {},
                  onScrollToTop: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final email = find.byKey(const Key('footer-email-link'));
        expect(
          email,
          findsOneWidget,
          reason: 'Footer email should be linked at width $width',
        );
        expect(tester.widget<InkWell>(email).onTap, isNotNull);
        expect(
          tester.takeException(),
          isNull,
          reason: 'Footer overflow at width $width',
        );
      }
    },
  );
  testWidgets('Footer email launches the expected mailto address', (
    tester,
  ) async {
    setSize(tester, 1280, 900);
    String? launchedUrl;
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'launch') {
            launchedUrl =
                (call.arguments as Map<dynamic, dynamic>)['url'] as String?;
            return true;
          }
          return false;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: GlobalFooter(
              pesoGreen: Colors.green,
              onTabSelected: (_) {},
              onScrollToTop: () {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('footer-email-link')));
    await tester.pumpAndSettle();
    expect(launchedUrl, 'mailto:peso.rod@gmail.com');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Footer quick links use three columns on mobile and preserve the main sections',
    (tester) async {
      setSize(tester, 390, 850);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GlobalFooter(
                pesoGreen: Colors.green,
                onTabSelected: (_) {},
                onScrollToTop: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final quickLinks = tester.getTopLeft(find.text('Quick Links'));
      final contact = tester.getTopLeft(find.text('Contact Us'));
      expect(quickLinks.dx, closeTo(contact.dx, 1));

      final home = tester.getTopLeft(find.text('Home'));
      final jobs = tester.getTopLeft(find.text('Jobs'));
      final gallery = tester.getTopLeft(find.text('Gallery'));
      final about = tester.getTopLeft(find.text('About'));
      final seap = tester.getTopLeft(find.text('SEAP'));
      final gip = tester.getTopLeft(find.text('GIP'));

      expect(home.dx, lessThan(jobs.dx));
      expect(jobs.dx, lessThan(gallery.dx));
      expect(home.dx, closeTo(about.dx, 1));
      expect(jobs.dx, closeTo(seap.dx, 1));
      expect(gallery.dx, closeTo(gip.dx, 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('PESO photographs are valid bundled image assets', (
    tester,
  ) async {
    await tester.pumpWidget(servicesApp());
    expect(PesoImageAssets.gallery.length, greaterThanOrEqualTo(20));
    expect(
      PesoImageAssets.gallery.toSet().length,
      PesoImageAssets.gallery.length,
    );
    expect(PesoImageAssets.partnerLogos.length, 15);
    for (final path in [
      ...PesoImageAssets.gallery,
      PesoImageAssets.aboutBanner,
    ]) {
      final bytes = await rootBundle.load(path);
      expect(bytes.lengthInBytes, greaterThan(20000));
      expect(bytes.getUint8(0), 0xff);
      expect(bytes.getUint8(1), 0xd8);
    }
    for (final partner in PesoImageAssets.partnerLogos) {
      final bytes = await rootBundle.load(partner.asset);
      expect(bytes.lengthInBytes, greaterThan(1024), reason: partner.asset);
    }
  });

  testWidgets('Home explains the real workflow and has practical FAQs', (
    tester,
  ) async {
    setSize(tester, 390, 850);
    await tester.pumpWidget(const MaterialApp(home: LandingPage()));
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.byKey(const Key('jobkonek-how-it-works')), findsOneWidget);
    expect(find.text('STEP 1 OF 4'), findsOneWidget);
    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Next step'), findsOneWidget);
    await Scrollable.ensureVisible(
      tester.element(find.text('Next step')),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next step'));
    await tester.pumpAndSettle();
    expect(find.text('STEP 2 OF 4'), findsOneWidget);
    expect(find.text('Complete your profile and documents'), findsOneWidget);
    expect(
      find.textContaining(
        'Only green-highlighted labels in NSRP Form 1 are required',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('jobkonek-tutorial-screenshot-1')),
      findsOneWidget,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('3. Find a suitable opportunity')),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('3. Find a suitable opportunity'));
    await tester.pumpAndSettle();
    expect(find.text('STEP 3 OF 4'), findsOneWidget);
    expect(find.text('Find a suitable opportunity'), findsOneWidget);
    expect(
      find.textContaining(
        'does not guarantee eligibility, referral, interview, or hiring',
      ),
      findsOneWidget,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('4. Apply and track your progress')),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('4. Apply and track your progress'));
    await tester.pumpAndSettle();
    expect(find.text('STEP 4 OF 4'), findsOneWidget);
    expect(find.text('Finish & explore jobs'), findsOneWidget);
    expect(find.byKey(const Key('jobkonek-faq')), findsOneWidget);
    expect(find.text('Frequently Asked Questions'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Four real walkthrough screenshots are bundled and can be enlarged on mobile',
    (tester) async {
      setSize(tester, 320, 760);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: JobKonekTutorial(onExploreJobs: () {}),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      const paths = [
        'lib/assets/jobkonek_guide_account.jpg',
        'lib/assets/jobkonek_guide_nsrp.jpg',
        'lib/assets/jobkonek_guide_jobs.jpg',
        'lib/assets/jobkonek_guide_outcomes.jpg',
      ];
      for (final path in paths) {
        final image = await rootBundle.load(path);
        expect(image.lengthInBytes, greaterThan(10000), reason: path);
        expect(image.getUint8(0), 0xff);
        expect(image.getUint8(1), 0xd8);
      }
      expect(
        find.byKey(const ValueKey<String>('jobkonek-tutorial-screenshot-0')),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const Key('jobkonek-tutorial-enlarge')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('jobkonek-tutorial-enlarge')));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Close screen preview'), findsOneWidget);
      await tester.tap(find.byTooltip('Close screen preview'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Gallery and About navigation render on desktop', (tester) async {
    setSize(tester, 1280, 900);
    await tester.pumpWidget(const MaterialApp(home: LandingPage()));
    await tester.pump(const Duration(milliseconds: 800));
    tester.widget<AdaptiveNavBar>(find.byType(AdaptiveNavBar)).onTabSelected(2);
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('PESO Montalban in Action'), findsOneWidget);
    tester.widget<AdaptiveNavBar>(find.byType(AdaptiveNavBar)).onTabSelected(4);
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('About JobKonek'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Gallery and About navigation render on mobile', (tester) async {
    setSize(tester, 375, 810);
    await tester.pumpWidget(const MaterialApp(home: LandingPage()));
    await tester.pump(const Duration(milliseconds: 800));
    tester
        .widget<MobileBottomNavBar>(find.byType(MobileBottomNavBar))
        .onTabSelected(2);
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('PESO Montalban in Action'), findsOneWidget);
    tester
        .widget<MobileBottomNavBar>(find.byType(MobileBottomNavBar))
        .onTabSelected(4);
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('About JobKonek'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
