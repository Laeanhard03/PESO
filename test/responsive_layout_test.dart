import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_ui/Reusable_Designs/responsive_layout.dart';

void main() {
  group('classifyPesoWidth', () {
    test('uses compact layout below 600 logical pixels', () {
      expect(classifyPesoWidth(359), PesoLayoutClass.compact);
      expect(classifyPesoWidth(599), PesoLayoutClass.compact);
    });

    test('uses medium layout from 600 through 1023 logical pixels', () {
      expect(classifyPesoWidth(600), PesoLayoutClass.medium);
      expect(classifyPesoWidth(768), PesoLayoutClass.medium);
      expect(classifyPesoWidth(1023), PesoLayoutClass.medium);
    });

    test('uses expanded layout at 1024 logical pixels and above', () {
      expect(classifyPesoWidth(1024), PesoLayoutClass.expanded);
      expect(classifyPesoWidth(1440), PesoLayoutClass.expanded);
    });
  });

  testWidgets('ResponsiveContent centers and constrains wide content',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ResponsiveContent(
            maxWidth: 1200,
            padding: EdgeInsets.zero,
            child: SizedBox(
              key: Key('responsive-child'),
              width: double.infinity,
              height: 80,
            ),
          ),
        ),
      ),
    );

    final child = tester.getRect(find.byKey(const Key('responsive-child')));
    expect(child.width, 1200);
    expect(child.center.dx, 800);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ResponsiveContent stays within compact viewport',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ResponsiveContent(
            child: SizedBox(
              key: Key('compact-responsive-child'),
              width: double.infinity,
              height: 80,
            ),
          ),
        ),
      ),
    );

    final child = tester.getRect(
      find.byKey(const Key('compact-responsive-child')),
    );
    expect(child.left, greaterThanOrEqualTo(0));
    expect(child.right, lessThanOrEqualTo(360));
    expect(tester.takeException(), isNull);
  });
}
