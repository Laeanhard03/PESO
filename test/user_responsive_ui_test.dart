import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_ui/User/user_ai_profile_tab.dart';
import 'package:peso_prototype/peso_ui/User/user_ui.dart';

void main() {
  for (final size in <Size>[
    const Size(360, 800),
    const Size(768, 1024),
    const Size(1366, 900),
  ]) {
    testWidgets('user dashboard fits ${size.width.toInt()}px viewport', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: UserProfile()));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('JobKonek'), findsOneWidget);
      final pesoLogo = find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'lib/assets/peso_app_icon.png',
      );
      expect(pesoLogo, findsOneWidget);
      expect(tester.getSize(pesoLogo).width, greaterThanOrEqualTo(40));
      expect(
        find.ancestor(of: pesoLogo, matching: find.byType(ClipOval)),
        findsOneWidget,
        reason: 'Dashboard app logo should be large and circular',
      );
      expect(tester.takeException(), isNull);
    });
  }

  const fileName = '905738300_4659557807666728_1939042886800889990_n.jpg';
  for (final size in <Size>[
    const Size(320, 760),
    const Size(360, 800),
    const Size(390, 844),
    const Size(560, 900),
    const Size(768, 1024),
    const Size(1366, 900),
  ]) {
    testWidgets(
      'saved document card stays readable at ${size.width.toInt()}px',
      (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final name = TextEditingController(text: 'Ana Santos');
        final title = TextEditingController(text: 'Office Assistant');
        final bio = TextEditingController(text: 'Applicant profile');
        addTearDown(name.dispose);
        addTearDown(title.dispose);
        addTearDown(bio.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: UserAiProfileTab(
                nameController: name,
                titleController: title,
                bioController: bio,
                userSkills: const <String>[],
                aiProfileData: const <String, dynamic>{},
                aiExtractionUnavailable: true,
                resumeData: const <String, dynamic>{},
                pesoFormData: const <String, dynamic>{},
                artifacts: const <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'responsive-nsrp-document',
                    'category': 'nsrp_form',
                    'fileName': fileName,
                    'sizeBytes': 5495,
                  },
                ],
                onRebuildNsrp: () {},
                onSaveNsrp: (_) async {},
                translate: (value) => value,
                primary: const Color(0xFF236349),
                textDark: const Color(0xFF17352B),
                textLight: const Color(0xFF52675D),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 800));

        final card = find.byKey(
          const ValueKey('saved-document-card-responsive-nsrp-document'),
        );
        await tester.ensureVisible(card);
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('NSRP Form 1 PDF'), findsOneWidget);
        expect(find.textContaining(fileName), findsOneWidget);
        expect(
          find.byTooltip('Edit full NSRP Form 1 and regenerate PDF'),
          findsOneWidget,
        );
        expect(find.byTooltip('Edit NSRP form details'), findsOneWidget);
        final preview = find.byTooltip('Preview document');
        expect(preview, findsOneWidget);

        final cardRect = tester.getRect(card);
        final fileRect = tester.getRect(find.textContaining(fileName));
        final previewRect = tester.getRect(preview);
        expect(cardRect.width, lessThanOrEqualTo(size.width + 0.5));
        if (cardRect.width < 560) {
          expect(
            previewRect.top,
            greaterThanOrEqualTo(fileRect.bottom - 1),
            reason: 'Mobile document actions must sit below the file details.',
          );
        } else {
          expect(
            previewRect.left,
            greaterThanOrEqualTo(fileRect.right - 1),
            reason: 'Wide document actions must sit beside the file details.',
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
