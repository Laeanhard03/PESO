import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_ui/Admin/admin_account_pages.dart';

void main() {
  group('AdminProfileSection', () {
    testWidgets(
      'shows a destructive confirmation before deleting the account',
      (tester) async {
        var deleteCalls = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AdminProfileSection(
                displayName: 'PESO Administrator',
                email: 'admin@example.test',
                uid: 'admin-uid',
                emailVerified: true,
                signInProvider: 'google.com',
                onDeleteAccount: () async {
                  deleteCalls++;
                },
              ),
            ),
          ),
        );

        expect(find.text('My Administrator Profile'), findsOneWidget);
        expect(find.text('admin@example.test'), findsOneWidget);
        expect(find.text('Delete your account'), findsOneWidget);
        expect(deleteCalls, 0);

        await tester.ensureVisible(find.text('Delete your account'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete your account'));
        await tester.pumpAndSettle();

        expect(find.text('Delete your administrator account?'), findsOneWidget);
        expect(
          find.textContaining(
            'Firebase Authentication account and PESO profile',
          ),
          findsOneWidget,
        );
        expect(deleteCalls, 0);

        await tester.tap(find.text('Delete my account'));
        await tester.pumpAndSettle();

        expect(deleteCalls, 1);
        expect(find.text('Delete your administrator account?'), findsNothing);
      },
    );

    testWidgets('canceling the confirmation does not delete the account', (
      tester,
    ) async {
      var deleteCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminProfileSection(
              displayName: 'PESO Administrator',
              email: 'admin@example.test',
              uid: 'admin-uid',
              emailVerified: true,
              signInProvider: 'google.com',
              onDeleteAccount: () async {
                deleteCalls++;
              },
            ),
          ),
        ),
      );

      await tester.ensureVisible(find.text('Delete your account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete your account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(deleteCalls, 0);
      expect(find.text('My Administrator Profile'), findsOneWidget);
    });
  });

  group('AdminSettingsSection', () {
    testWidgets('opens the profile page through its account action', (
      tester,
    ) async {
      var profileOpens = 0;
      var signOutCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminSettingsSection(
              email: 'admin@example.test',
              emailVerified: true,
              signInProvider: 'google.com',
              onOpenProfile: () => profileOpens++,
              onSignOut: () async {
                signOutCalls++;
              },
            ),
          ),
        ),
      );

      expect(find.text('Admin Settings'), findsOneWidget);
      expect(find.text('Security and session'), findsOneWidget);
      await tester.tap(find.text('Open my profile'));
      await tester.pumpAndSettle();

      expect(profileOpens, 1);
      expect(signOutCalls, 0);
    });

    testWidgets('sign-out control invokes the supplied session action', (
      tester,
    ) async {
      var signOutCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminSettingsSection(
              email: 'admin@example.test',
              emailVerified: true,
              signInProvider: 'google.com',
              onOpenProfile: () {},
              onSignOut: () async {
                signOutCalls++;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(signOutCalls, 1);
    });
  });
}
