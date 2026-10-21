import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_ui/User/user_qualifications_editor.dart';

void main() {
  test('only applicant-owned NSRP entries are updated, never assessor or ID fields', () {
    final initial = <String, dynamic>{
      'documentType': 'NSRP Form 1',
      'entries': [
        {'label': 'TIN', 'value': 'private-test-placeholder'},
        {'label': 'PESO assessor signature', 'value': 'reserved for staff'},
        {
          'fieldKey': 'applicant.skills',
          'label': 'Other skills acquired',
          'value': 'Old outdated skill',
        },
      ],
      'aiText': 'Old outdated skill',
    };
    final updated = updateApplicantNsrpCareerDetails(initial, {
      'education': 'Senior High School',
      'experience': 'No previous work experience',
      'skillsStage': 'New entrant / still learning',
      'skills': 'Old outdated skill',
      'preferredOccupation': 'Construction trainee',
    });
    final entries = (updated['entries'] as List).whereType<Map>().toList();
    expect(
      entries.any(
        (e) => e['label'] == 'TIN' && e['value'] == 'private-test-placeholder',
      ),
      true,
    );
    expect(
      entries.any(
        (e) =>
            e['label'] == 'PESO assessor signature' &&
            e['value'] == 'reserved for staff',
      ),
      true,
    );
    expect(entries.any((e) => e['fieldKey'] == 'applicant.skills'), false);
    expect(
      entries.any(
        (e) =>
            e['fieldKey'] == 'applicant.highestEducation' &&
            e['value'] == 'Senior High School',
      ),
      true,
    );
    expect(updated['aiText'], '');
    expect(initial['aiText'], 'Old outdated skill');
  });

  test('explicit, truly listed applicant skills can replace their previous editable entry', () {
    final updated = updateApplicantNsrpCareerDetails(
      {
        'entries': [
          {
            'fieldKey': 'applicant.skills',
            'label': 'Other skills acquired',
            'value': 'Old skill',
          },
          {'label': 'Other document entry', 'value': 'preserved'},
        ],
      },
      {
        'education': 'College Graduate',
        'experience': 'Has work experience',
        'skillsStage': 'Has skills or training to list',
        'skills': 'Construction safety, MS Excel',
      },
    );
    final entries = (updated['entries'] as List).whereType<Map>().toList();
    expect(entries.where((e) => e['fieldKey'] == 'applicant.skills').length, 1);
    expect(
      entries.singleWhere((e) => e['fieldKey'] == 'applicant.skills')['value'],
      'Construction safety, MS Excel',
    );
    expect(entries.any((e) => e['value'] == 'Old skill'), false);
    expect(entries.any((e) => e['value'] == 'preserved'), true);
  });

  test('a corrected education or NSRP profile invalidates the old AI result but preserves the PESO application', () {
    final report = <String, dynamic>{
      'status': 'readiness',
      'jobId': 'example-role',
      'applicationSubmitted': true,
      'applicationId': 'existing-application',
      'answers': {'experience': 'Just starting'},
      'modelMatch': {'score': 70},
      'modelVersion': 'peso-mini-ai-v1',
      'modelReviewNotes': ['Employer evidence needs checking'],
      'nextSteps': [
        'Bring supporting documents',
        'Employer evidence needs checking',
      ],
      'strengths': [
        'Relevant skill: Welding',
        'Attended readiness orientation',
      ],
      'improvements': ['Requirement to review: License', 'Consider training'],
    };
    final other = <String, dynamic>{
      'status': 'recommended',
      'modelMatch': {'score': 45},
    };
    markReadinessReportsForRecheck([
      report,
      other,
    ], reason: 'Your education was updated.');
    expect(report['aiMatchingStatus'], 'needs_recheck');
    expect(report.containsKey('modelMatch'), false);
    expect(report.containsKey('modelVersion'), false);
    expect(report['applicationSubmitted'], true);
    expect(report['applicationId'], 'existing-application');
    expect(report['answers'], {'experience': 'Just starting'});
    expect(report['nextSteps'], ['Bring supporting documents']);
    expect(report['strengths'], ['Attended readiness orientation']);
    expect(report['improvements'], ['Consider training']);
    expect(other['modelMatch'], {'score': 45});
  });

  testWidgets(
    'applicant editor requires own basics and saves without touching IDs',
    (tester) async {
      tester.view.physicalSize = const Size(390, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic>? saved;
      final form = <String, dynamic>{
        'entries': [
          {'label': 'TIN', 'value': 'kept-private'},
        ],
        'applicantEssentials': {
          'education': 'Senior High School',
          'experience': 'No previous work experience',
          'skillsStage': 'New entrant / still learning',
        },
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => FilledButton(
                  onPressed: () => showDialog<bool>(
                    context: context,
                    builder: (_) => UserQualificationsEditor(
                      pesoFormData: form,
                      resumeData: const {},
                      accountProfile: const {},
                      onSave: (updated) async {
                        saved = updated;
                      },
                    ),
                  ),
                  child: const Text('Edit qualification evidence'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit qualification evidence'));
      await tester.pumpAndSettle();
      expect(find.text('Update your NSRP career details'), findsOneWidget);
      expect(
        find.textContaining('no experience or still learning'),
        findsWidgets,
      );
      final save = find.byKey(const Key('save_nsrp_career_details'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(saved, isNotNull);
      expect(
        (saved!['entries'] as List).any(
          (item) =>
              item is Map &&
              item['label'] == 'TIN' &&
              item['value'] == 'kept-private',
        ),
        true,
      );
      expect(find.text('Update your NSRP career details'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
