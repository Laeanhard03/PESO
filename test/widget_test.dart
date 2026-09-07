import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PesoApp());
    expect(find.text('PESO Job Portal'), findsOneWidget);
  });
}
