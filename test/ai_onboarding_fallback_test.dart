import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_ui/Reusable_Designs/ai_processing_ui.dart';
import 'package:peso_prototype/peso_logic/onboarding_ai_evidence.dart';
import 'package:peso_prototype/peso_services/profile_artifact_service.dart';

void main() {
  const nsrp = <String, dynamic>{
    'entries': [
      {'label': 'Other skills acquired', 'value': 'Cash handling'},
      {'label': 'SSS number', 'value': '1234567890'},
      {'label': 'Sex', 'value': 'Female'},
      {'label': 'Work experience', 'value': 'Retail cashier'},
    ],
  };
  const resume = <String, dynamic>{
    'fields': [
      {
        'section': 'Education',
        'label': 'College course',
        'value': 'Business Administration',
      },
    ],
  };

  test('sends NSRP and resume job evidence, never identifiers', () {
    final text = buildOnboardingAiEvidence(
      resumeData: resume,
      pesoFormData: nsrp,
      onboardingText:
          'SSS number: 1234567890\nEducation: Business Administration',
    );
    expect(text, contains('Cash handling'));
    expect(text, contains('Business Administration'));
    expect(text, isNot(contains('1234567890')));
    expect(text, isNot(contains('Female')));
  });

  testWidgets('source save failure still navigates but never claims saved', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AIProcessingOutcome? outcome;
    final actions = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: AIProcessingScreen(
          resumeData: resume,
          pesoFormData: nsrp,
          services: AIProcessingServices(
            saveSources: ({resumeData, pesoFormData, onboardingText}) async {
              actions.add('source-attempt');
              throw StateError('offline');
            },
            saveDocuments: (_) async {
              actions.add('documents');
              return const ProfileArtifactSaveResult(records: [], warnings: []);
            },
            extractProfile:
                ({required artifacts, rawText, persist = true}) async {
                  actions.add('extract');
                  throw StateError('offline');
                },
          ),
          profilePageBuilder: (context, value) {
            outcome = value;
            return const Scaffold(body: Text('SOURCE_NOT_SAVED'));
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('SOURCE_NOT_SAVED'), findsOneWidget);
    expect(actions, ['source-attempt', 'documents'], reason: 'Gemini must not run before source persistence succeeds.');
    expect(outcome!.sourceSaved, isFalse);
    expect(outcome!.aiProfile, isNull);
    expect(outcome!.extractionUnavailable, isTrue);
    expect(outcome!.warnings, isNotEmpty);
  });

  for (final fails in [false, true]) {
    testWidgets(
      fails
          ? 'Gemini outage still navigates with source-only unavailable status'
          : 'Gemini success navigates with extracted profile',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final actions = <String>[];
        AIProcessingOutcome? result;
        final services = AIProcessingServices(
          saveSources: ({resumeData, pesoFormData, onboardingText}) async {
            actions.add('sources');
            expect(resumeData, resume);
            expect(pesoFormData, nsrp);
          },
          saveDocuments: (_) async {
            actions.add('documents');
            return const ProfileArtifactSaveResult(records: [], warnings: []);
          },
          extractProfile:
              ({required artifacts, rawText, persist = true}) async {
                actions.add('extract');
                expect(rawText, contains('Cash handling'));
                expect(rawText, isNot(contains('1234567890')));
                if (fails) throw StateError('offline');
                return {
                  'fullName': 'Verified Test Person',
                  'skills': ['Cash handling'],
                };
              },
        );
        await tester.pumpWidget(
          MaterialApp(
            home: AIProcessingScreen(
              services: services,
              resumeData: resume,
              pesoFormData: nsrp,
              profilePageBuilder: (context, outcome) {
                result = outcome;
                return const Scaffold(body: Text('PROFILE_DESTINATION'));
              },
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(seconds: 2));
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('PROFILE_DESTINATION'), findsOneWidget);
        expect(actions.take(3).toList(), ['sources', 'documents', 'extract']);
        if (fails) {
          expect(result!.aiProfile, isNull);
          expect(result!.extractionUnavailable, isTrue);
          expect(result!.sourceSaved, isTrue);
        } else {
          expect(actions, ['sources', 'documents', 'extract']);
          expect(result!.aiProfile!['skills'], ['Cash handling']);
          expect(result!.extractionUnavailable, isFalse);
        }
      },
    );
  }
}
