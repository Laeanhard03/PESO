import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_services/app_toast.dart';

Future<BuildContext> mountHost(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  late BuildContext hostContext;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            hostContext = context;
            return const Center(child: Text('PESO dashboard'));
          },
        ),
      ),
    ),
  );
  return hostContext;
}

void main() {
  tearDown(AppToast.dismiss);

  testWidgets('desktop success notification is compact, branded, dismissible', (
    tester,
  ) async {
    final context = await mountHost(tester, const Size(1366, 900));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AppToast.success(context, 'Your changes have been saved.');
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('All set'), findsOneWidget);
    expect(find.text('Your changes have been saved.'), findsOneWidget);
    expect(find.byTooltip('Dismiss notification'), findsOneWidget);
    expect(tester.getRect(find.text('All set')).left, greaterThan(750));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Dismiss notification'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 210));
    expect(find.text('Your changes have been saved.'), findsNothing);
  });

  testWidgets('mobile long warning remains readable without overflow', (
    tester,
  ) async {
    final context = await mountHost(tester, const Size(320, 600));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AppToast.warning(
      context,
      'Your resume is ready, but some documents could not be saved. '
      'Review your profile and try saving again before sending an application.',
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Heads up'), findsOneWidget);
    expect(find.byTooltip('Dismiss notification'), findsOneWidget);
    final rect = tester.getRect(find.text('Heads up'));
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Dismiss notification'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 210));
    expect(find.text('Heads up'), findsNothing);
  });

  testWidgets('new error replaces success and disappears after its timeout', (
    tester,
  ) async {
    final context = await mountHost(tester, const Size(390, 844));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AppToast.success(context, 'Saved first');
    await tester.pump(const Duration(milliseconds: 300));
    AppToast.error(context, 'Check your internet connection.');
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Saved first'), findsNothing);
    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Check your internet connection.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 8));
    await tester.pump(const Duration(milliseconds: 210));
    expect(find.text('Check your internet connection.'), findsNothing);
  });
}
