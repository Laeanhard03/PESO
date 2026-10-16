import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/main.dart';
import 'package:peso_prototype/peso_ui/Admin/admin_ui.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PesoApp());
    expect(find.text('JobKonek'), findsOneWidget);
  });

  testWidgets('Admin dashboard is blocked until Firebase admin verification', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: AdminDashboard(developmentPreview: true)));
    expect(find.text('Protected Admin Area'), findsOneWidget);
    expect(find.text('Firebase administrator email'), findsOneWidget);
    expect(find.text('Verify and unlock Admin'), findsOneWidget);
    expect(find.text('Verify current Firebase session'), findsOneWidget);
    expect(find.text('Applicant Analytics'), findsNothing);
  });
}