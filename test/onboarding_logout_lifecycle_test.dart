import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_services/onboarding_prompt_lifecycle.dart';

void main() {
  test(
    'unfinished onboarding is shown only to the original signed-in applicant',
    () {
      bool canPrompt({
        bool mounted = true,
        bool loggingOut = false,
        String? dashboardUid = 'jobseeker-a',
        String? currentUid = 'jobseeker-a',
        bool currentRoute = true,
        bool welcomeFinished = true,
        bool alreadyShown = false,
        bool documentsLoaded = true,
      }) {
        return OnboardingPromptGuard.canPrompt(
          mounted: mounted,
          loggingOut: loggingOut,
          dashboardUid: dashboardUid,
          currentUid: currentUid,
          dashboardRouteIsCurrent: currentRoute,
          welcomeFinished: welcomeFinished,
          alreadyShown: alreadyShown,
          documentsLoaded: documentsLoaded,
        );
      }

      expect(canPrompt(), isTrue);
      expect(
        canPrompt(currentUid: null),
        isFalse,
        reason: 'No reminder may appear after logout',
      );
      expect(
        canPrompt(loggingOut: true),
        isFalse,
        reason: 'Do not open a reminder while logout is still pending',
      );
      expect(
        canPrompt(currentUid: 'different-applicant'),
        isFalse,
        reason: 'Old document status must not appear for another account',
      );
      expect(canPrompt(dashboardUid: null), isFalse);
      expect(
        canPrompt(currentRoute: false),
        isFalse,
        reason:
            'A background dashboard must not show dialogs on the landing page',
      );
      expect(canPrompt(mounted: false), isFalse);
      expect(canPrompt(welcomeFinished: false), isFalse);
      expect(canPrompt(alreadyShown: true), isFalse);
      expect(canPrompt(documentsLoaded: false), isFalse);
    },
  );

  testWidgets(
    'Logout dismisses the exact onboarding dialog without leaving it behind',
    (tester) async {
      final handle = OnboardingDialogHandle<String>();
      BuildContext? home;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              home = context;
              return const Scaffold(
                body: Center(child: Text('Jobseeker home')),
              );
            },
          ),
        ),
      );
      final pending = handle.show(
        context: home!,
        builder: (_) => const AlertDialog(
          title: Text('Finish your PESO JobKonek onboarding'),
          actions: [
            TextButton(onPressed: null, child: Text('Continue onboarding')),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(handle.isOpen, isTrue);
      expect(find.text('Continue onboarding'), findsOneWidget);

      handle.dismiss(); // Same call used immediately when a user signs out.
      await tester.pumpAndSettle();
      expect(handle.isOpen, isFalse);
      expect(find.text('Continue onboarding'), findsNothing);
      expect(find.text('Jobseeker home'), findsOneWidget);
      expect(await pending, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'A late logout removes only the onboarding dialog, not the new landing route',
    (tester) async {
      final handle = OnboardingDialogHandle<String>();
      BuildContext? home;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              home = context;
              return const Scaffold(body: Center(child: Text('Old dashboard')));
            },
          ),
        ),
      );
      final pending = handle.show(
        context: home!,
        builder: (_) => const AlertDialog(
          title: Text('Finish your PESO JobKonek onboarding'),
          actions: [
            TextButton(onPressed: null, child: Text('Continue onboarding')),
          ],
        ),
      );
      await tester.pumpAndSettle();
      Navigator.of(home!).push<void>(
        MaterialPageRoute<void>(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('Signed-out landing'))),
        ),
      );
      await tester.pumpAndSettle();

      handle.dismiss();
      await tester.pumpAndSettle();
      expect(find.text('Signed-out landing'), findsOneWidget);
      expect(find.text('Continue onboarding'), findsNothing);
      expect(await pending, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
