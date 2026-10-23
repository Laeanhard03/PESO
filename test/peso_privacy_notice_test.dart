import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_ui/Login_register_pages/privacy_notice.dart';

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
}
