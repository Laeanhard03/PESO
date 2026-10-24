import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_ui/Login_register_pages/privacy_notice.dart';
import 'package:peso_prototype/peso_ui/Login_register_pages/register_ui.dart';

void main() {
  test('prototype privacy notice covers required processing disclosures', () {
    expect(pesoPrivacyNoticeVersion, 'prototype-2026-10-23');
    expect(pesoPrivacyNoticeText, contains('PRIVACY NOTICE (PROTOTYPE)'));
    expect(pesoPrivacyNoticeText, contains('Municipality of Rodriguez'));
    expect(pesoPrivacyNoticeText, contains('Data Protection Officer'));
    expect(pesoPrivacyNoticeText, contains('sensitive personal information'));
    expect(pesoPrivacyNoticeText, contains('Google Gemini'));
    expect(pesoPrivacyNoticeText, contains('WHO MAY RECEIVE'));
    expect(pesoPrivacyNoticeText, contains('records-retention'));
    expect(pesoPrivacyNoticeText, contains('YOUR RIGHTS'));
    expect(pesoPrivacyNoticeText, contains('National Privacy Commission'));
    expect(
      pesoPrivacyNoticeText,
      contains('Do not enter real applicant information'),
    );
  });

  test('terms clearly separate advisory matching from official decisions', () {
    expect(pesoTermsAndConditionsText, contains('do not guarantee'));
    expect(
      pesoTermsAndConditionsText,
      contains('not a substitute for the Municipality'),
    );
  });

  testWidgets(
    'Terms and Privacy Notice are independently accessible without accepting consent',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RegisterForm(
                pesoGreen: const Color(0xFF236349),
                isLight: false,
                onSwitchToLogin: () {},
                onProceedToOnboarding: (_) {},
                onEmailVerificationRequired: (_) {},
              ),
            ),
          ),
        ),
      );
      final termsLink = find.byKey(const Key('registration-terms-link'));
      final privacyLink = find.byKey(const Key('registration-privacy-link'));
      expect(termsLink, findsOneWidget);
      expect(privacyLink, findsOneWidget);
      final checkboxes = find.byType(CheckboxListTile);
      expect(checkboxes, findsNWidgets(2));

      await tester.ensureVisible(termsLink);
      await tester.pumpAndSettle();
      await tester.tap(termsLink);
      await tester.pumpAndSettle();
      expect(find.text('Terms and Conditions'), findsOneWidget);
      expect(tester.widget<CheckboxListTile>(checkboxes.first).value, false);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(privacyLink);
      await tester.pumpAndSettle();
      await tester.tap(privacyLink);
      await tester.pumpAndSettle();
      expect(find.text('Privacy Notice'), findsOneWidget);
      expect(find.textContaining('PRIVACY NOTICE (PROTOTYPE)'), findsWidgets);
      expect(tester.widget<CheckboxListTile>(checkboxes.at(0)).value, false);
      expect(tester.widget<CheckboxListTile>(checkboxes.at(1)).value, false);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
