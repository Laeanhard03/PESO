import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'login exposes no admin keyword and uses authenticated role routing',
    () {
      final loginSource = File('lib/peso_ui/Login_register_pages/login_ui.dart')
          .readAsStringSync();

      expect(loginSource, isNot(contains('Admin Keyword')));
      expect(loginSource, isNot(contains('shouldOpenAdminAuthenticationGate')));
      expect(loginSource, contains('AuthService.signInWithEmail'));
      expect(loginSource, contains('AuthService.getCurrentUserRole'));
      expect(loginSource, contains('shouldOpenAdminArea(role)'));
    },
  );

  test('email/password sign-in cannot continue before email verification', () {
    final loginSource = File('lib/peso_ui/Login_register_pages/login_ui.dart')
        .readAsStringSync();
    final loginStart = loginSource.indexOf('Future<void> _loginUser() async {');
    final googleStart = loginSource.indexOf(
      'Future<void> _loginWithGoogle() async {',
    );
    expect(loginStart, isNonNegative);
    expect(googleStart, greaterThan(loginStart));

    final emailLogin = loginSource.substring(loginStart, googleStart);
    expect(emailLogin, contains('!credential.user!.emailVerified'));
    expect(emailLogin, contains('onEmailVerificationRequired'));
    expect(
      emailLogin.indexOf('!credential.user!.emailVerified'),
      lessThan(emailLogin.indexOf('await _openUserArea()')),
    );
    expect(loginSource, contains('AuthService.getCurrentUserRole'));
  });
}
