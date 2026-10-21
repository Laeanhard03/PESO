import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:peso_prototype/peso_ui/Landingpage/peso_public_services.dart';
import 'package:peso_prototype/peso_ui/Landingpage/landingpage_ui.dart';
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
    expect(find.text('Montalban Local Government'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PESO photographs are valid bundled image assets', (
    tester,
  ) async {
    await tester.pumpWidget(servicesApp());
    expect(PesoImageAssets.gallery.length, 6);
    for (final path in [
      ...PesoImageAssets.gallery,
      PesoImageAssets.aboutBanner,
    ]) {
      final bytes = await rootBundle.load(path);
      expect(bytes.lengthInBytes, greaterThan(20000));
      expect(bytes.getUint8(0), 0xff);
      expect(bytes.getUint8(1), 0xd8);
    }
  });

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
