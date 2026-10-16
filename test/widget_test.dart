import 'dart:ui' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PesoApp());
    expect(find.text('JobKonek'), findsOneWidget);
  });
}