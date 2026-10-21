import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/peso_ui/Admin/admin_applicant_document_viewer.dart';
import '../lib/peso_ui/User/profile_document_dialog.dart';

void main() {
  test('selects private documents by UID and type, not by applicant name', () {
    final first = <String, dynamic>{
      'uid': 'applicant-a',
      'artifacts': <Map<String, dynamic>>[
        {'id': 'a-nsrp', 'category': 'nsrp_form', 'fileName': 'Form 1.pdf'},
        {'id': 'a-resume', 'category': 'resume_upload', 'fileName': 'Resume.pdf'},
      ],
    };
    final second = <String, dynamic>{
      'uid': 'applicant-b',
      'artifacts': <Map<String, dynamic>>[
        {'id': 'b-resume', 'category': 'resume_builder', 'fileName': 'Resume.pdf'},
      ],
    };
    expect(AdminApplicantDocumentViewer.findArtifact(
      first, uid: 'applicant-a', kind: 'resume')?['id'], 'a-resume');
    expect(AdminApplicantDocumentViewer.findArtifact(
      first, uid: 'applicant-a', kind: 'nsrp')?['id'], 'a-nsrp');
    expect(AdminApplicantDocumentViewer.findArtifact(
      first, uid: 'applicant-b', kind: 'resume'), isNull);
    expect(AdminApplicantDocumentViewer.findArtifact(
      second, uid: 'applicant-b', kind: 'nsrp'), isNull);
    expect(AdminApplicantDocumentViewer.findArtifact(
      second, uid: 'applicant-b', kind: 'resume')?['id'], 'b-resume');
  });

  testWidgets('admin PDF reuses read-only AI Profile preview with download and print',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(820, 660));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    var reads = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (context) =>
        TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => ProfileDocumentDialog(
              artifact: const <String, dynamic>{
                'id': 'private-nsrp', 'fileName': 'NSRP_Form1.pdf',
                'category': 'nsrp_form', 'mimeType': 'application/pdf',
              },
              fetchBytes: (id) async {
                expect(id, 'private-nsrp');
                reads++;
                return Uint8List.fromList(<int>[37, 80, 68, 70, 45, 49, 46, 52]);
              },
            ),
          ),
          child: const Text('Preview'),
        ),
      )),
    ));
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    expect(reads, 1);
    expect(find.text('Private document preview'), findsOneWidget);
    expect(find.text('NSRP_Form1.pdf'), findsOneWidget);
    expect(find.text('Download PDF'), findsOneWidget);
    expect(find.text('Print PDF'), findsOneWidget);
    expect(find.text('Upload revised PDF'), findsNothing);
    expect(find.text('Edit in Canva'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
