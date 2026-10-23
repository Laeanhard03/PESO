import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_ui/Login_register_pages/login_ui.dart';
import 'package:peso_prototype/peso_ui/Login_register_pages/register_ui.dart';

Future<void> acceptRegistrationConsent(WidgetTester tester) async {
  final consentCheckboxes = find.byType(CheckboxListTile);
  expect(consentCheckboxes, findsNWidgets(2));
  for (var i = 0; i < 2; i++) {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final tile = consentCheckboxes.at(i);
    final checkbox = find.descendant(of: tile, matching: find.byType(Checkbox));
    expect(checkbox, findsOneWidget);
    await tester.ensureVisible(checkbox);
    await tester.pumpAndSettle();
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(tile).value, isTrue);
  }
}

void main() {
  const green = Color(0xFF236349);

  testWidgets('cancelled Google sign-in immediately unlocks login actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final pending = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LoginForm(
              pesoGreen: green,
              isLight: false,
              onSwitchToRegister: () {},
              googleSignIn: () => pending.future,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Google'));
    await tester.pump();
    expect(find.text('Cancel Google sign-in / unlock form'), findsOneWidget);
    await tester.tap(find.text('Cancel Google sign-in / unlock form'));
    await tester.pump();
    final loginButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Secure Login'),
    );
    expect(loginButton.onPressed, isNotNull);
    pending.complete();
    await tester.pump();
    expect(find.text('Secure Login'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelled Google registration never advances onboarding', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var startedOnboarding = false;
    final pending = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RegisterForm(
              pesoGreen: green,
              isLight: false,
              onSwitchToLogin: () {},
              onProceedToOnboarding: (_) => startedOnboarding = true,
              onEmailVerificationRequired: (_) {},
              googleSignIn: () => pending.future,
            ),
          ),
        ),
      ),
    );
    // Residency is mandatory before OAuth; fill real required fields first.
    await tester.enterText(
      find.byType(TextField).at(4),
      'Block 3 Lot 5, Montalban',
    );
    await tester.ensureVisible(find.byKey(const Key('registration-barangay')));
    await tester.tap(find.byKey(const Key('registration-barangay')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Balite').last);
    await tester.pumpAndSettle();
    await acceptRegistrationConsent(tester);
    await tester.ensureVisible(find.text('Continue with Google'));
    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    await tester.ensureVisible(
      find.text('Cancel Google sign-in / unlock form'),
    );
    await tester.tap(find.text('Cancel Google sign-in / unlock form'));
    await tester.pump();
    final registerButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Continue to profile photo'),
    );
    expect(registerButton.onPressed, isNotNull);
    pending.complete();
    await tester.pump();
    expect(startedOnboarding, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing the Google login popup unlocks the form automatically', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final popup = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LoginForm(
              pesoGreen: green,
              isLight: false,
              onSwitchToRegister: () {},
              googleSignIn: () => popup.future,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Google'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 40));
    expect(find.text('Cancel Google sign-in / unlock form'), findsOneWidget);

    popup.completeError(FirebaseAuthException(code: 'popup-closed-by-user'));
    await tester.pumpAndSettle();
    final googleButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Google'),
    );
    expect(googleButton.onPressed, isNotNull);
    expect(find.text('Cancel Google sign-in / unlock form'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('registration avatar is a separate step after account details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RegisterForm(
              pesoGreen: green,
              isLight: false,
              onSwitchToLogin: () {},
              onProceedToOnboarding: (_) {},
              onEmailVerificationRequired: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField).at(0), 'Mina');
    await tester.enterText(find.byType(TextField).at(1), 'Santos');
    await tester.enterText(find.byType(TextField).at(2), 'mina@example.test');
    await tester.enterText(
      find.byType(TextField).at(4),
      'Block 3 Lot 5, Montalban',
    );
    await tester.enterText(
      find.byKey(const Key('registration-password-field')),
      'PastedPassword1',
    );
    await tester.ensureVisible(find.byKey(const Key('registration-barangay')));
    await tester.tap(find.byKey(const Key('registration-barangay')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Balite').last);
    await tester.pumpAndSettle();
    await acceptRegistrationConsent(tester);
    await tester.ensureVisible(find.text('Continue to profile photo'));
    await tester.tap(find.text('Continue to profile photo'));
    await tester.pumpAndSettle();

    expect(find.text('Step 2 of 2: Choose your profile image'), findsOneWidget);
    expect(
      find.text('Choose an avatar or add a profile photo'),
      findsOneWidget,
    );
    expect(find.text('Create account and verify email'), findsOneWidget);

    await tester.tap(find.text('Back to account details'));
    await tester.pumpAndSettle();
    final passwordField = tester.widget<TextField>(
      find.byKey(const Key('registration-password-field')),
    );
    expect(passwordField.controller?.text, 'PastedPassword1');
    expect(passwordField.enableInteractiveSelection, isTrue);
    expect(tester.takeException(), isNull);
  });
}
