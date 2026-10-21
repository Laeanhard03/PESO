import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_models/job_posting.dart';

void main() {
  group('PESO job posting categories', () {
    test('labels both categories', () {
      expect(PesoJobCategories.label(PesoJobCategories.walkInApplication), 'Walk-in Application');
      expect(PesoJobCategories.label(PesoJobCategories.localRecruitmentActivity), 'Local Recruitment Activity');
    });

    test('walk-in applications never receive time-based expiration', () {
      final job = <String, dynamic>{
        'category': PesoJobCategories.walkInApplication,
        'status': 'active',
        'createdAt': '2020-01-01T00:00:00.000Z',
      };
      expect(PesoJobCategories.effectiveExpiryAt(job), isNull);
      expect(PesoJobCategories.isVisible(job, now: DateTime(2035, 1, 1)), isTrue);
      expect(PesoJobCategories.expiryText(job, now: DateTime(2035, 1, 1)), 'No automatic expiration');
    });

    test('legacy LRA expires at the end of its Philippine publication day', () {
      final createdAt = DateTime.utc(2026, 10, 17, 6);
      final job = <String, dynamic>{
        'category': PesoJobCategories.localRecruitmentActivity,
        'status': 'active',
        'createdAt': createdAt.toIso8601String(),
      };
      final expiry = PesoJobCategories.effectiveExpiryAt(job)!;
      expect(expiry.toUtc(), DateTime.utc(2026, 10, 17, 15, 59, 59, 999));
      expect(PesoJobCategories.isVisible(job, now: expiry.subtract(const Duration(milliseconds: 1))), isTrue);
      expect(PesoJobCategories.isVisible(job, now: expiry), isFalse);
    });

    test('scheduled multi-day LRA expires at end of final recruitment day in Manila', () {
      final job = <String, dynamic>{
        'category': PesoJobCategories.localRecruitmentActivity,
        'status': 'active',
        'createdAt': '2026-10-17T06:00:00Z',
        'recruitmentDate': '2026-10-21',
        'recruitmentEndDate': '2026-10-22',
      };
      final expiry = PesoJobCategories.effectiveExpiryAt(job)!;
      expect(expiry.toUtc(), DateTime.utc(2026, 10, 22, 15, 59, 59, 999));
      expect(PesoJobCategories.isVisible(job, now: DateTime.utc(2026, 10, 22, 15, 59)), isTrue);
      expect(PesoJobCategories.isVisible(job, now: expiry), isFalse);
    });

    test('stored server expiration takes precedence', () {
      final job = <String, dynamic>{
        'category': PesoJobCategories.localRecruitmentActivity,
        'status': 'active',
        'createdAt': '2026-10-17T06:00:00.000Z',
        'expiresAt': '2026-10-17T07:00:00.000Z',
      };
      expect(PesoJobCategories.effectiveExpiryAt(job)!.toUtc(), DateTime.utc(2026, 10, 17, 7));
    });

    test('LRA with missing creation and expiry timestamps stays hidden', () {
      final job = <String, dynamic>{
        'category': PesoJobCategories.localRecruitmentActivity,
        'status': 'active',
      };
      expect(
        PesoJobCategories.isVisible(job, now: DateTime.utc(2026, 10, 17)),
        isFalse,
      );
      expect(
        PesoJobCategories.expiryText(job, now: DateTime.utc(2026, 10, 17)),
        'Expiration not available',
      );
    });

    test('inactive jobs are hidden regardless of category', () {
      final job = <String, dynamic>{
        'category': PesoJobCategories.walkInApplication,
        'status': 'inactive',
      };
      expect(PesoJobCategories.isVisible(job), isFalse);
    });
  });
}
