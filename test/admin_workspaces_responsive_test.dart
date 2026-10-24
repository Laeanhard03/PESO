import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_ui/Admin/admin_excel_live_preview.dart';
import 'package:peso_prototype/peso_ui/Admin/admin_pdf_link_ingestion.dart';

void main() {
  for (final width in <double>[320, 390, 768]) {
    testWidgets(
      'Live Excel preview fits a ${width.toInt()}px screen without horizontal overflow',
      (tester) async {
        tester.view.physicalSize = Size(width, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: AdminExcelLivePreview())),
        );
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.text('Live Applicant Register'), findsOneWidget);
        expect(find.text('Successful'), findsWidgets);
        expect(find.text('All barangays'), findsOneWidget);
        expect(find.textContaining('registered jobseekers'), findsOneWidget);
        final layoutException = tester.takeException();
        if (layoutException is FlutterError) {
          debugPrint(layoutException.toString());
          for (final diagnostic in layoutException.diagnostics) {
            debugPrint(diagnostic.toString());
          }
        }
        expect(layoutException, isNull);
      },
    );

    testWidgets('Online PDF source form fits a ${width.toInt()}px screen', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AdminPdfLinkIngestionSection())),
      );
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Online PDF Job Sources'), findsOneWidget);
      expect(find.text('Verify and attach PDF'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
