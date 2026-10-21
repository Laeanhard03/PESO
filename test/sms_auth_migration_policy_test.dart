import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the PESO bearer provider uses Firebase identity only', () {
    final session = File('lib/peso_services/peso_auth_session.dart').readAsStringSync();
    final api = File('lib/peso_services/peso_api_client.dart').readAsStringSync();
    expect(session, contains('FirebaseAuth.instance.currentUser'));
    expect(session, contains('user.getIdToken()'));
    expect(session, isNot(contains('saveSmsSession')));
    expect(session, isNot(contains('isSmsSession')));
    expect(session, isNot(contains('getRequiredSmsToken')));
    expect(session, isNot(contains('peso_sms_')));
    expect(api, contains('PesoAuthSession.getBearerToken()'));
    expect(api, isNot(contains('/api/auth/sms/')));
  });

  test('retired SMS backend modules and routes are absent from active backend source', () {
    expect(File('backend/server.js').readAsStringSync(), isNot(contains('sms-auth')));
    expect(File('backend/server.js').readAsStringSync(), isNot(contains('peso_sms_')));
    expect(File('backend/src/sms-auth.js').existsSync(), isFalse);
    expect(File('backend/src/sms-auth-routes.js').existsSync(), isFalse);
    expect(File('backend/src/sms-auth.test.js').existsSync(), isFalse);
  });

  test('Firebase Email/Password and Google sign-in and email reset remain intact', () {
    final auth = File('lib/peso_services/auth_service.dart').readAsStringSync();
    expect(auth, contains('_auth.createUserWithEmailAndPassword('));
    expect(auth, contains('_auth.signInWithEmailAndPassword('));
    expect(auth, contains('_auth.signInWithPopup(provider)'));
    expect(auth, contains('_auth.signInWithProvider(provider)'));
    expect(auth, contains('sendPasswordResetEmail('));
    expect(auth, isNot(contains('signInWithPhoneNumber(')));
    expect(auth, isNot(contains('verifyPhoneNumber(')));
  });
}
