import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'verified email must force a fresh Firebase ID token before onboarding',
    () {
      final source = File('lib/peso_services/auth_service.dart')
          .readAsStringSync();
      final method = source
          .split(
            'static Future<bool> reloadCurrentUserVerification() async {',
          )[1]
          .split('static Future<UserCredential> signInWithGoogle()')[0];
      expect(method, contains('await user.reload();'));
      expect(
        method,
        contains('if (refreshedUser?.emailVerified != true) return false;'),
      );
      expect(method, contains('await refreshedUser!.getIdToken(true);'));
      expect(
        method.indexOf('getIdToken(true)'),
        greaterThan(method.indexOf('user.reload()')),
      );
    },
  );
}
