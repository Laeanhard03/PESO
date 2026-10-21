import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_models/job_posting.dart';
import 'package:peso_prototype/peso_ui/Landingpage/landingpage_ui.dart';
import 'package:peso_prototype/peso_ui/Reusable_Designs/adaptive_nav_bar.dart';
import 'package:peso_prototype/peso_ui/User/user_job_feed_tab.dart';
import 'package:peso_prototype/peso_ui/Reusable_Designs/peso_images.dart';

void main() {
  testWidgets(
    'landing hero uses a bundled asset instead of a remote-only provider',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: LandingPage()));
      await tester.pump(const Duration(milliseconds: 700));

      final headline = find.text('Your next opportunity\nstarts here.');
      expect(headline, findsOneWidget);

      final ancestors = tester.widgetList<Container>(
        find.ancestor(of: headline, matching: find.byType(Container)),
      );
      final heroUsesAsset = ancestors.any((container) {
        final decoration = container.decoration;
        return decoration is BoxDecoration &&
            decoration.image?.image is AssetImage;
      });
      expect(heroUsesAsset, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'landing preview cards describe features instead of usage claims',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: LandingPage()));
      await tester.pump(const Duration(milliseconds: 700));

      for (final claim in <String>[
        '5,000+',
        'Active job postings',
        '50+',
        'TESDA programs',
        '10,000+',
        'Registered jobseekers',
      ]) {
        expect(
          find.text(claim),
          findsNothing,
          reason: '$claim is an unverified usage claim.',
        );
      }

      for (final feature in <String>[
        'Find Jobs',
        'Explore Programs',
        'Get Started',
      ]) {
        expect(find.text(feature), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('landing hero logo background container is circular', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: LandingPage()));
    await tester.pump(const Duration(milliseconds: 700));

    final heroLogoImage = find.descendant(
      of: find.byType(Transform),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.width == 120 &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'lib/assets/peso_app_icon.png',
      ),
    );
    expect(heroLogoImage, findsOneWidget);
    final imageTransforms = tester.widgetList<Transform>(
      find.ancestor(of: heroLogoImage, matching: find.byType(Transform)),
    );
    expect(
      imageTransforms.any((item) => item.transform.getMaxScaleOnAxis() >= 1.29),
      isTrue,
      reason:
          'The hero logo asset should be enlarged to crop its white perimeter.',
    );
    final heroLogoContainers = tester.widgetList<Container>(
      find.ancestor(of: heroLogoImage, matching: find.byType(Container)),
    );
    expect(heroLogoContainers, isNotEmpty);
    final decoration = heroLogoContainers.first.decoration as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);
    expect(tester.takeException(), isNull);
  });
  testWidgets('landing layout adapts without overflow across viewport sizes', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final width in <double>[390, 600, 768, 1024, 1280, 1440]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpWidget(const MaterialApp(home: LandingPage()));
      await tester.pump(const Duration(milliseconds: 700));

      if (width == 390) {
        final navFinder = find.byType(NavigationBar);
        expect(navFinder, findsOneWidget);
        final nav = tester.widget<NavigationBar>(navFinder);
        expect(nav.destinations.length, 5);
        for (final label in <String>[
          'Home',
          'Jobs',
          'Gallery',
          'History',
          'About',
        ]) {
          expect(
            find.descendant(of: navFinder, matching: find.text(label)),
            findsOneWidget,
            reason: 'The mobile navigation should show $label at 390 dp.',
          );
        }
      }

      expect(
        tester.takeException(),
        isNull,
        reason: 'Landing page should fit a viewport width of $width dp.',
      );
    }
  });
  testWidgets('landing Jobs and History tabs include complete content', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: LandingPage()));
    await tester.pump(const Duration(milliseconds: 700));

    final navigation = find.byType(NavigationBar);
    await tester.tap(
      find.descendant(of: navigation, matching: find.text('Jobs')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Find work that moves you forward.'), findsOneWidget);
    expect(find.text('5 roles to explore'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Internship'));
    await tester.pumpAndSettle();
    expect(find.text('1 role to explore'), findsOneWidget);
    expect(find.text('IT Support Intern'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'All roles'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Prime BPO');
    await tester.pumpAndSettle();
    expect(find.text('1 role to explore'), findsOneWidget);
    expect(find.text('Data Encoder'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'no matching role');
    await tester.pumpAndSettle();
    expect(find.text('No roles match your search'), findsOneWidget);

    await tester.tap(
      find.descendant(of: navigation, matching: find.text('History')),
    );
    await tester.pumpAndSettle();
    expect(find.text('A bridge to opportunity.'), findsOneWidget);
    expect(find.text('Milestones along the way'), findsOneWidget);
    expect(find.text('The work continues.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'landing header darkens on scroll and home search opens results',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: LandingPage()));
      await tester.pump(const Duration(milliseconds: 700));

      final navFinder = find.byType(AdaptiveNavBar);
      expect(tester.widget<AdaptiveNavBar>(navFinder).isScrolled, isFalse);
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -450),
      );
      await tester.pump();
      expect(tester.widget<AdaptiveNavBar>(navFinder).isScrolled, isTrue);

      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, 900),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<AdaptiveNavBar>(navFinder).isScrolled, isFalse);

      await tester.ensureVisible(find.byType(TextField).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Data Encoder');
      await tester.ensureVisible(find.text('Search jobs'));
      await tester.tap(find.text('Search jobs'));
      await tester.pumpAndSettle();
      expect(find.text('1 role to explore'), findsOneWidget);
      expect(find.text('Data Encoder'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'user job cards use a local image when an API job has no image URL',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final job = <String, dynamic>{
        'id': 'missing-image',
        'title': 'Office Assistant',
        'company': 'PESO Demo Employer',
        'location': 'Montalban',
        'salary': 'Salary not provided',
        'type': 'Full-time',
        'vacancies': '1',
        'match': 0,
        'image': '',
        'description': 'Support daily office operations.',
        'reqs': <String>['Communication skills'],
        'category': PesoJobCategories.walkInApplication,
        'isPublicPdfListing': false,
        'sourcePageStart': 1,
        'sourcePageEnd': 1,
        'logoColor': Colors.green,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserJobFeedTab(
              userName: 'Test User',
              availableJobs: <Map<String, dynamic>>[job],
              selectedJob: job,
              onSelectJob: (_) {},
              onEvaluateJob: (_) {},
              translate: (value) => value,
              primary: const Color(0xFF2E7D32),
              textDark: Colors.black87,
              textLight: Colors.grey,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final hasBundledFallback = find.byWidgetPredicate((widget) {
        if (widget is! Image || widget.image is! AssetImage) return false;
        return (widget.image as AssetImage).assetName ==
            PesoImageAssets.jobFallbackFor(job);
      });
      expect(hasBundledFallback, findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
