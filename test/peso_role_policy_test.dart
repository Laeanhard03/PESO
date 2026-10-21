import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_services/peso_role_policy.dart';

void main() {
  group('PESO role policy', () {
    test('server-resolved MongoDB admin role is recognized for routing', () {
      expect(normalizePesoRole('admin'), 'admin');
      expect(shouldOpenAdminArea('admin'), isTrue);
    });

    test('regular roles remain regular and unknown roles fail closed', () {
      for (final role in <String>['job_seeker', 'employer', 'staff']) {
        expect(normalizePesoRole(role), role);
        expect(shouldOpenAdminArea(role), isFalse);
      }
      expect(normalizePesoRole('superuser'), 'job_seeker');
      expect(normalizePesoRole(null), 'job_seeker');
      expect(shouldOpenAdminArea('superuser'), isFalse);
    });

    test('admin routing is exact and case-sensitive', () {
      expect(shouldOpenAdminArea('Admin'), isFalse);
      expect(shouldOpenAdminArea(' admin '), isFalse);
      expect(shouldOpenAdminArea(''), isFalse);
    });
  });
}
