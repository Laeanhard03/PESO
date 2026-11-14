enum EmailVerificationThrottleFailure { requestInProgress, cooldown }

class EmailVerificationThrottleException implements Exception {
  const EmailVerificationThrottleException.inProgress()
    : failure = EmailVerificationThrottleFailure.requestInProgress,
      remaining = Duration.zero;

  const EmailVerificationThrottleException.cooldown(this.remaining)
    : failure = EmailVerificationThrottleFailure.cooldown;

  final EmailVerificationThrottleFailure failure;
  final Duration remaining;

  @override
  String toString() {
    if (failure == EmailVerificationThrottleFailure.requestInProgress) {
      return 'A verification email request is already in progress.';
    }
    return 'Wait ${remaining.inSeconds} seconds before requesting another verification email.';
  }
}

/// Device-level verification-email rate control.
///
/// The normal interval prevents accidental repeated sends. When Firebase
/// reports its device-level abuse block, a longer local backoff prevents the
/// app from immediately retrying the blocked operation. The persisted deadline
/// survives a page reload; the in-memory deadline remains active if storage is
/// temporarily unavailable.
class EmailVerificationThrottle {
  EmailVerificationThrottle({
    required this.readCooldownUntil,
    required this.writeCooldownUntil,
    DateTime Function()? clock,
    this.clearStoredCooldown,
    this.minimumInterval = const Duration(seconds: 60),
    this.rateLimitBackoff = const Duration(minutes: 15),
  }) : _clock = clock ?? DateTime.now;

  final Future<DateTime?> Function() readCooldownUntil;
  final Future<void> Function(DateTime until) writeCooldownUntil;
  final DateTime Function() _clock;
  final Future<void> Function()? clearStoredCooldown;
  final Duration minimumInterval;
  final Duration rateLimitBackoff;

  DateTime? _memoryCooldownUntil;
  bool _requestInFlight = false;

  Future<Duration> remaining() async {
    final now = _clock().toUtc();
    DateTime? stored;
    try {
      stored = (await readCooldownUntil())?.toUtc();
    } catch (_) {
      // Secure-storage failures must not crash sign-in or verification UI.
    }
    final memory = _memoryCooldownUntil;
    final latest = stored == null
        ? memory
        : memory == null || stored.isAfter(memory)
        ? stored
        : memory;
    if (latest == null || !latest.isAfter(now)) return Duration.zero;
    return latest.difference(now);
  }

  Future<void> _storeCooldown(DateTime until) async {
    final utcUntil = until.toUtc();
    if (_memoryCooldownUntil == null ||
        utcUntil.isAfter(_memoryCooldownUntil!)) {
      _memoryCooldownUntil = utcUntil;
    }
    try {
      await writeCooldownUntil(utcUntil);
    } catch (_) {
      // The in-memory deadline still prevents repeated sends in this session.
    }
  }

  Future<void> clear() async {
    _memoryCooldownUntil = null;
    try {
      await clearStoredCooldown?.call();
    } catch (_) {
      // Clearing a local hint must not affect a successfully verified user.
    }
  }

  Future<void> send(
    Future<void> Function() request, {
    required bool Function(Object error) isRateLimited,
  }) async {
    if (_requestInFlight) {
      throw const EmailVerificationThrottleException.inProgress();
    }
    _requestInFlight = true;
    try {
      final wait = await remaining();
      if (wait > Duration.zero) {
        throw EmailVerificationThrottleException.cooldown(wait);
      }

      // Reserve the interval before the network call so a failed request or a
      // rapid second tap cannot immediately issue another Firebase request.
      await _storeCooldown(_clock().toUtc().add(minimumInterval));
      try {
        await request();
      } catch (error) {
        if (isRateLimited(error)) {
          await _storeCooldown(_clock().toUtc().add(rateLimitBackoff));
        }
        rethrow;
      }
    } finally {
      _requestInFlight = false;
    }
  }
}
