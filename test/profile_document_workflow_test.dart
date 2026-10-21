import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_ui/User/nsrp_entries_editor.dart';
import 'package:peso_prototype/peso_ui/User/profile_document_dialog.dart';

void main() {
  testWidgets(
    'NSRP entry editor saves edits without exposing identifiers to AI text',
    (tester) async {
      Map<String, dynamic>? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => NsrpEntriesEditor(
                    formData: const <String, dynamic>{
                      'documentType': 'NSRP Form 1',
                      'entries': [
                        {
                          'index': 1,
                          'label': 'First Name',
                          'type': 'text',
                          'value': 'Ari',
                        },
                        {
                          'index': 2,
                          'label': 'TIN',
                          'type': 'text',
                          'value': '123',
                        },
                        {
                          'index': 4,
                          'label': 'Education',
                          'type': 'text',
                          'value': 'BS Information Systems',
                        },
                        {
                          'index': 3,
                          'label': 'Work available',
                          'type': 'checkbox',
                          'checked': true,
                          'value': 'Selected',
                        },
                      ],
                    },
                    onSave: (data) async {
                      saved = data;
                    },
                  ),
                ),
                child: const Text('Open form'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open form'));
      await tester.pumpAndSettle();
      expect(find.text('Edit NSRP Form 1 details'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('nsrp-field-0')),
        'Ari Updated',
      );
      await tester.tap(find.text('Save NSRP changes'));
      await tester.pumpAndSettle();
      expect(saved, isNotNull);
      final entries = saved!['entries'] as List<dynamic>;
      expect(entries.first['value'], 'Ari Updated');
      expect(entries[1]['value'], '123');
      expect(saved!['aiText'], isNot(contains('First Name:')));
      expect(saved!['aiText'], contains('Education: BS Information Systems'));
      expect(saved!['aiText'], isNot(contains('TIN:')));
    },
  );

  testWidgets('PDF preview loads authenticated bytes and offers replacement', (
    tester,
  ) async {
    var replaced = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => ProfileDocumentDialog(
                  artifact: const <String, dynamic>{
                    'id': 'test-pdf',
                    'category': 'resume_upload',
                    'mimeType': 'application/pdf',
                    'fileName': 'resume.pdf',
                  },
                  fetchBytes: (_) async =>
                      Uint8List.fromList('%PDF-1.7 mock'.codeUnits),
                  onReplacePdf: () async {
                    replaced = true;
                    return true;
                  },
                ),
              ),
              child: const Text('Preview PDF'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Preview PDF'));
    await tester.pumpAndSettle();
    expect(find.text('Private document preview'), findsOneWidget);
    expect(find.text('Edit in Canva'), findsOneWidget);
    expect(find.text('Upload revised PDF'), findsOneWidget);
    await tester.tap(find.text('Upload revised PDF'));
    await tester.pumpAndSettle();
    expect(replaced, true);
    expect(find.text('Private document preview'), findsNothing);
  });
}
