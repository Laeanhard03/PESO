import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_ui/Admin/admin_development_notes_section.dart';

void main() {
  for (final width in <double>[320, 390, 768, 1366]) {
    testWidgets(
      'Development Notepad layout fits ' +
          width.toInt().toString() +
          'px width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: EdgeInsets.all(16),
                child: AdminDevelopmentNotesSection(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Development Notepad'), findsOneWidget);
        expect(find.text('New item'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
