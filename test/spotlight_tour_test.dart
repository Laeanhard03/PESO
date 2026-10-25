import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_ui/Reusable_Designs/spotlight_tour.dart';

void main() {
  for (final width in [320.0, 390.0, 1280.0]) {
    testWidgets('real clickable spotlight and replay at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final tour = GlobalKey<SpotlightTourState>();
      final anchor = GlobalKey();
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: SpotlightTour(
            key: tour,
            tourId: 'tap-${width.toInt()}',
            autoStart: false,
            steps: [
              SpotlightStep(
                target: anchor,
                title: 'Actual control',
                description:
                    'Highlight the button without disabling its click.',
              ),
            ],
            child: Scaffold(
              body: Center(
                child: FilledButton(
                  key: anchor,
                  onPressed: () => taps++,
                  child: const Text('Real button'),
                ),
              ),
            ),
          ),
        ),
      );
      await tour.currentState!.start(replay: true);
      await tester.pumpAndSettle();
      expect(find.text('Actual control'), findsOneWidget);
      await tester.tapAt(tester.getCenter(find.byKey(anchor)));
      await tester.pump();
      expect(taps, 1);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(tour.currentState!.isShowing, isFalse);
      await tour.currentState!.start(replay: true);
      await tester.pumpAndSettle();
      expect(find.text('Actual control'), findsOneWidget);
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();
      expect(tour.currentState!.isShowing, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'active overlay survives parent rebuild without marking widgets dirty during build',
    (tester) async {
      final tour = GlobalKey<SpotlightTourState>();
      final target = GlobalKey();
      final counter = ValueNotifier<int>(0);
      addTearDown(counter.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<int>(
            valueListenable: counter,
            builder: (context, count, _) => SpotlightTour(
              key: tour,
              tourId: 'spotlight-live-rebuild',
              autoStart: false,
              steps: [
                SpotlightStep(
                  target: target,
                  title: 'Live target',
                  description: 'The page keeps updating.',
                ),
              ],
              child: Scaffold(
                body: Center(
                  child: TextButton(
                    key: target,
                    onPressed: () {},
                    child: Text('Updated $count'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tour.currentState!.start(replay: true);
      await tester.pumpAndSettle();
      counter.value++;
      await tester.pumpAndSettle();
      expect(find.text('Live target'), findsOneWidget);
      expect(find.text('Updated 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Skip remembers a completed tour and manual Replay still works', (
    tester,
  ) async {
    const id = 'spotlight-skip-persistence-unit';
    final target = GlobalKey();
    final state = GlobalKey<SpotlightTourState>();
    Widget testView({bool auto = true}) => MaterialApp(
      home: SpotlightTour(
        key: state,
        tourId: id,
        autoStart: auto,
        steps: [
          SpotlightStep(
            target: target,
            title: 'Memorized',
            description: 'Read once.',
          ),
        ],
        child: Scaffold(
          body: Center(
            child: TextButton(
              key: target,
              onPressed: () {},
              child: const Text('Anchor'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(testView(auto: false));
    await state.currentState!.start(replay: true);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(testView());
    await tester.pumpAndSettle();
    expect(find.text('Memorized'), findsNothing);
    await state.currentState!.start(replay: true);
    await tester.pumpAndSettle();
    expect(find.text('Memorized'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('next step scrolls to a target that began off-screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final tour = GlobalKey<SpotlightTourState>();
    final first = GlobalKey();
    final later = GlobalKey();
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SpotlightTour(
          key: tour,
          tourId: 'scroll-spotlight-test',
          autoStart: false,
          steps: [
            SpotlightStep(
              target: first,
              title: 'First',
              description: 'The first control.',
            ),
            SpotlightStep(
              target: later,
              title: 'Second',
              description: 'The scrolled control.',
            ),
          ],
          child: Scaffold(
            body: SingleChildScrollView(
              controller: controller,
              child: Column(
                children: [
                  const SizedBox(height: 120),
                  FilledButton(
                    key: first,
                    onPressed: () {},
                    child: const Text('First target'),
                  ),
                  const SizedBox(height: 980),
                  FilledButton(
                    key: later,
                    onPressed: () {},
                    child: const Text('Second target'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tour.currentState!.start(replay: true);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(400));
    expect(find.text('Second'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('First'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
