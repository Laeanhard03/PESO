import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_ui/Login_register_pages/register_ui.dart';
import 'package:peso_prototype/peso_ui/User/user_account_tab.dart';

void main() {
  for (final width in [390.0, 1200.0]) {
    testWidgets('Registration Montalban barangays width ' + width.toString(),
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MaterialApp(home: Scaffold(
          body: SingleChildScrollView(child: RegisterForm(
            pesoGreen: Colors.green, isLight: true,
            onSwitchToLogin: () {},
            onProceedToOnboarding: (_) {},
            onEmailVerificationRequired: (_) {},
          )),
        )));
        expect(find.byKey(const Key('registration-barangay')), findsOneWidget);
        expect(find.textContaining('Montalban, Rizal (required)'), findsOneWidget);
        expect(find.textContaining('Selecting a barangay does not verify residency'),
          findsOneWidget);
        expect(tester.takeException(), isNull);
      });
  }

  testWidgets('My Account saved documents and actions', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: UserAccountTab(
        profile: const <String, dynamic>{
          'firstName': 'Example', 'lastName': 'Applicant',
          'email': 'example@example.test', 'displayName': 'Example Applicant',
          'role': 'job_seeker',
          'barangay': 'San Jose', 'address': 'Example Street',
          'residency': {'status': 'pending'},
        },
        documents: const <String, dynamic>{
          'resumeSubmitted': true, 'formSubmitted': false,
        },
        primary: Colors.green, textDark: Colors.black,
        textLight: Colors.grey, onSave: (_) async {},
        onCreateResume: () {}, onEditNsrp: () {},
        onReviewAi: () {}, onReplaceResume: () async => true,
      ),
    )));
    await tester.pump();
    expect(find.text('Applicant documents'), findsOneWidget);
    expect(find.textContaining('Resume: Submitted'), findsOneWidget);
    expect(find.text('Complete / edit NSRP'), findsOneWidget);
    expect(find.text('Change password'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
