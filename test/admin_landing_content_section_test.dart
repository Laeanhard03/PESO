import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_ui/Admin/admin_landing_content_section.dart';

void main() {
  testWidgets('Admin gallery and partners editor supports add and validation', (tester) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AdminLandingContentSection(
          loadContent: () async => <String, dynamic>{
            'gallery': <dynamic>[],
            'partners': <dynamic>[],
          },
        ),
      ),
    ));
    // Supply an immediate empty API response rather than relying on a local
    // server/network timeout in this isolated widget test.
    await tester.pumpAndSettle();

    expect(find.text('Landing Page Content'), findsOneWidget);
    expect(find.text('Gallery photos'), findsOneWidget);
    expect(find.text('Employer partners'), findsOneWidget);

    await tester.tap(find.byKey(const Key('landing-gallery-add')));
    await tester.pump();
    expect(find.byKey(const Key('landing-gallery-select-26')), findsOneWidget);
    await tester.tap(find.byKey(const Key('landing-gallery-select-0')));
    await tester.pump();
    expect(find.byKey(const Key('landing-gallery-image-url')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('landing-partner-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('landing-partner-add')));
    await tester.pump();
    expect(find.text('Partner 1'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('landing-content-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('landing-content-save')));
    await tester.pump();
    expect(find.textContaining('Each gallery photo needs a title'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
