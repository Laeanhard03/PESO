import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Firebase verification sends use a persisted device-level throttle', () {
    final source = File('lib/peso_services/auth_service.dart')
        .readAsStringSync();
    final start = source.indexOf(
      'static Future<void> sendEmailVerification() async {',
    );
    final end = source.indexOf(
      'static Future<bool> reloadCurrentUserVerification()',
      start,
    );
    expect(start, isNonNegative);
    expect(end, greaterThan(start));
    final method = source.substring(start, end);
    final throttle = File('lib/peso_logic/email_verification_throttle.dart')
        .readAsStringSync();

    expect(method, contains('_verificationEmailThrottle.send('));
    expect(method, contains("error.code == 'too-many-requests'"));
    expect(method, isNot(contains('await user.sendEmailVerification();')));
    expect(source, contains('SharedPreferencesAsync'));
    expect(source, contains('peso_auth_email_verification_device_cooldown'));
    expect(throttle, contains('Duration(minutes: 15)'));
  });

  test('resend UI is single-flight, cooldown-aware and does not show raw Firebase errors', () {
    final source = File('lib/peso_ui/Login_register_pages/auth_ui.dart')
        .readAsStringSync();
    final start = source.indexOf(
      'Future<void> _resendVerificationEmail() async {',
    );
    final end = source.indexOf('Future<void> _checkEmailVerification()', start);
    expect(start, isNonNegative);
    expect(end, greaterThan(start));
    final method = source.substring(start, end);

    expect(
      method,
      contains(
        '_verificationBusy || _verificationCooldownRemaining > Duration.zero',
      ),
    );
    expect(
      method.indexOf('setState(() => _verificationBusy = true)'),
      lessThan(method.indexOf('await AuthService.sendEmailVerification()')),
    );
    expect(method, contains('AuthService.verificationErrorMessage(error)'));
    expect(method, contains('_refreshVerificationCooldown()'));
    expect(
      source,
      contains(r"'Resend available in ${_verificationCooldownLabel()}'"),
    );
    expect(source, contains('_verificationCooldownRemaining > Duration.zero'));
  });

  test('registration preserves the account and displays a safe rate-limit explanation', () {
    final source = File('lib/peso_ui/Login_register_pages/register_ui.dart')
        .readAsStringSync();
    expect(source, contains("case 'too-many-requests':"));
    expect(
      source,
      contains(
        'verificationError = AuthService.verificationErrorMessage(error);',
      ),
    );
    expect(
      source,
      contains(r'verification email could not be sent: $verificationError'),
    );
    expect(source, contains('widget.onEmailVerificationRequired('));
  });
}
