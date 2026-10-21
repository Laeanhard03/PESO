import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SMS login and SMS password-reset methods are removed; forgot password is email-only', () {
    final login = File('lib/peso_ui/Login_register_pages/login_ui.dart').readAsStringSync();
    final auth = File('lib/peso_services/auth_service.dart').readAsStringSync();
    final api = File('lib/peso_services/peso_api_client.dart').readAsStringSync();
    final server = File('backend/server.js').readAsStringSync();

    expect(login, isNot(contains('_loginWithSms')));
    expect(login, isNot(contains('SMS Code')));
    expect(login, isNot(contains('Sign in with SMS')));
    expect(login, contains('_loginWithGoogle'));
    expect(login, contains('Forgot Password?'));
    expect(auth, contains('sendPasswordResetEmail('));
    expect(auth, isNot(contains('sendPhoneCode')));
    expect(auth, isNot(contains('confirmPhoneCode')));
    expect(auth, isNot(contains('verifyPhoneNumber(')));
    expect(auth, isNot(contains('signInWithPhoneNumber(')));
    expect(api, isNot(contains('/api/auth/sms/')));
    expect(api, isNot(contains('/api/auth/password-reset/sms/')));
    expect(server, isNot(contains('installSmsAuthRoutes')));
    expect(server, isNot(contains('loadSmsSession')));
    expect(server, isNot(contains('peso_sms_')));
  });

  test('email/password and Google auth remain available, and registration phone is profile-only', () {
    final auth = File('lib/peso_services/auth_service.dart').readAsStringSync();
    final register = File('lib/peso_ui/Login_register_pages/register_ui.dart').readAsStringSync();

    expect(auth, contains('_auth.createUserWithEmailAndPassword('));
    expect(auth, contains('_auth.signInWithEmailAndPassword('));
    expect(auth, contains('_auth.signInWithPopup(provider)'));
    expect(auth, contains('_auth.signInWithProvider(provider)'));
    expect(auth, contains('sendPasswordResetEmail('));
    expect(register, contains('Phone Number (optional)'));
    expect(register, contains('AuthService.registerWithEmail('));
    expect(register, isNot(contains('sendPhoneCode')));
  });
}
