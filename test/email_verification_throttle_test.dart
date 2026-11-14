import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_logic/email_verification_throttle.dart';

class FakeRateLimit implements Exception {}

void main() {
  group('EmailVerificationThrottle', () {
    late DateTime now;
    DateTime? persistedUntil;
    late EmailVerificationThrottle throttle;

    setUp(() {
      now = DateTime.utc(2026, 11, 14, 13);
      persistedUntil = null;
      throttle = EmailVerificationThrottle(
        readCooldownUntil: () async => persistedUntil,
        writeCooldownUntil: (until) async {
          persistedUntil = until;
        },
        clock: () => now,
      );
    });

    test('a successful send starts a persistent 60-second cooldown', () async {
      var sends = 0;
      await throttle.send(() async {
        sends++;
      }, isRateLimited: (_) => false);
      expect(sends, 1);
      expect(persistedUntil, now.add(const Duration(seconds: 60)));
      expect(await throttle.remaining(), const Duration(seconds: 60));

      await expectLater(
        throttle.send(() async {
          sends++;
        }, isRateLimited: (_) => false),
        throwsA(
          isA<EmailVerificationThrottleException>().having(
            (error) => error.failure,
            'failure',
            EmailVerificationThrottleFailure.cooldown,
          ),
        ),
      );
      expect(sends, 1);
    });

    test('the persisted cooldown survives a new throttle instance', () async {
      await throttle.send(() async {}, isRateLimited: (_) => false);
      final restarted = EmailVerificationThrottle(
        readCooldownUntil: () async => persistedUntil,
        writeCooldownUntil: (until) async {
          persistedUntil = until;
        },
        clock: () => now,
      );
      expect(await restarted.remaining(), const Duration(seconds: 60));
    });

    test('Firebase too-many-requests applies a 15-minute backoff', () async {
      await expectLater(
        throttle.send(
          () async => throw FakeRateLimit(),
          isRateLimited: (error) => error is FakeRateLimit,
        ),
        throwsA(isA<FakeRateLimit>()),
      );
      expect(persistedUntil, now.add(const Duration(minutes: 15)));
      expect(await throttle.remaining(), const Duration(minutes: 15));
    });

    test('concurrent taps cannot start a second request', () async {
      final request = Completer<void>();
      final first = throttle.send(
        () => request.future,
        isRateLimited: (_) => false,
      );
      await Future<void>.delayed(Duration.zero);
      await expectLater(
        throttle.send(() async {}, isRateLimited: (_) => false),
        throwsA(
          isA<EmailVerificationThrottleException>().having(
            (error) => error.failure,
            'failure',
            EmailVerificationThrottleFailure.requestInProgress,
          ),
        ),
      );
      request.complete();
      await first;
    });

    test('an expired cooldown no longer blocks a new request', () async {
      await throttle.send(() async {}, isRateLimited: (_) => false);
      now = now.add(const Duration(seconds: 61));
      expect(await throttle.remaining(), Duration.zero);
      var sends = 0;
      await throttle.send(() async {
        sends++;
      }, isRateLimited: (_) => false);
      expect(sends, 1);
    });

    test(
      'storage failures do not crash verification and retain in-memory guard',
      () async {
        final noStorage = EmailVerificationThrottle(
          readCooldownUntil: () async =>
              throw StateError('storage unavailable'),
          writeCooldownUntil: (_) async =>
              throw StateError('storage unavailable'),
          clock: () => now,
        );
        await noStorage.send(() async {}, isRateLimited: (_) => false);
        expect(await noStorage.remaining(), const Duration(seconds: 60));
      },
    );
  });
}
