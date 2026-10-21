import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'peso_api_client.dart';
import 'peso_auth_session.dart';

/// Source form was encrypted locally but is not yet confirmed in MongoDB.
class OnboardingDraftQueuedException implements Exception {
  const OnboardingDraftQueuedException();
  @override
  String toString() => 'Form saved securely on this device, awaiting network synchronization.';
}

/// The remote form changed in the same field; neither copy was discarded.
class OnboardingDraftConflictException implements Exception {
  const OnboardingDraftConflictException(this.fields);
  final List<String> fields;
  @override
  String toString() => 'Conflicting edits detected. Your local draft remains saved for review.';
}

typedef DraftRead = Future<String?> Function(String key);
typedef DraftWrite = Future<void> Function(String key, String value);
typedef DraftDelete = Future<void> Function(String key);
typedef DraftGetProfile = Future<Map<String, dynamic>> Function();
typedef DraftPost = Future<Map<String, dynamic>> Function(Map<String, dynamic>);
typedef DraftActiveUid = Future<String?> Function();

/// Encrypt first; retry using revision + mutation ID. Never auto-overwrite
/// remote changes to the same field, and never persist credentials or PDF bytes.
class OnboardingDraftSync {
  OnboardingDraftSync({
    required DraftRead read,
    required DraftWrite write,
    required DraftDelete delete,
    required DraftGetProfile getProfile,
    required DraftPost post,
    DraftActiveUid? activeUid,
  }) : _read = read, _write = write, _delete = delete,
       _getProfile = getProfile, _post = post,
       _activeUidProvider = activeUid;

  static const FlutterSecureStorage _secure = FlutterSecureStorage();
  static final OnboardingDraftSync live = OnboardingDraftSync(
    read: (key) => _secure.read(key: key),
    write: (key, value) => _secure.write(key: key, value: value),
    delete: (key) => _secure.delete(key: key),
    getProfile: PesoApiClient.getProfile,
    post: PesoApiClient.saveOnboarding,
    activeUid: PesoAuthSession.currentUid,
  );
  static const List<String> _fields = ['resumeData', 'pesoFormData', 'onboardingText'];
  final DraftRead _read;
  final DraftWrite _write;
  final DraftDelete _delete;
  final DraftGetProfile _getProfile;
  final DraftPost _post;
  final DraftActiveUid? _activeUidProvider;
  Future<void> _serialWork = Future<void>.value();
  Timer? _retryTimer;
  bool _syncing = false;
  String? _activeUid;

  /// Serialize disk reads, writes and network acknowledgements; a delayed
  /// acknowledgement must never erase a newer locally queued edit.
  Future<T> _exclusive<T>(Future<T> Function() task) async {
    final previous = _serialWork;
    final finished = Completer<void>();
    _serialWork = finished.future;
    await previous;
    try {
      return await task();
    } finally {
      finished.complete();
    }
  }

  Future<bool> _ownsSession(String uid) async {
    if (_activeUidProvider == null) return true;
    return (await _activeUidProvider()) == uid;
  }

  String _pendingKey(String uid) => 'peso.form.pending.$uid';
  String _baseKey(String uid) => 'peso.form.base.$uid';
  Map<String, dynamic> _map(Object? input) =>
      input is Map ? Map<String, dynamic>.from(input) : <String, dynamic>{};

  Map<String, dynamic> _snapshot(Map<String, dynamic> profile) => {
    'revision': profile['onboardingRevision'] is int
        ? profile['onboardingRevision'] : 0,
    'lastMutationId': profile['onboardingLastMutationId'],
    for (final field in _fields)
      if (profile.containsKey(field)) field: profile[field],
  };

  Future<Map<String, dynamic>?> _load(String key) async {
    final raw = await _read(key);
    if (raw == null) return null;
    final value = jsonDecode(raw);
    if (value is! Map) throw StateError('An encrypted draft could not be decoded.');
    return Map<String, dynamic>.from(value);
  }

  Future<bool> hasPending(String uid) async =>
      await _read(_pendingKey(uid)) != null;

  Future<void> rememberProfile(String uid, Map<String, dynamic> profile) =>
      _exclusive(() async {
        if (uid.isEmpty || await hasPending(uid)) return;
        await _write(_baseKey(uid), jsonEncode(_snapshot(profile)));
      });

  String _newMutationId() {
    final entropy = Random.secure().nextInt(0x7fffffff);
    return 'peso-' + DateTime.now().microsecondsSinceEpoch.toString() +
        '-' + entropy.toString();
  }

  Future<void> save({
    required String uid,
    required Map<String, dynamic> data,
  }) => _exclusive(() async {
    if (uid.isEmpty || !await _ownsSession(uid)) {
      throw StateError('The active Firebase account does not match the form owner.');
    }
    if (!_fields.any(data.containsKey)) return;
    final old = await _load(_pendingKey(uid));
    final payload = _map(old?['data']);
    for (final field in _fields) {
      if (!data.containsKey(field)) continue;
      if (field == 'resumeData' || field == 'pesoFormData') {
        if (data[field] is! Map) {
          throw ArgumentError('Form data must be a structured object.');
        }
        payload[field] = {..._map(payload[field]), ..._map(data[field])};
      } else {
        payload[field] = data[field];
      }
    }
    final base = old?['base'] ?? await _load(_baseKey(uid));
    await _write(_pendingKey(uid), jsonEncode({
      'id': _newMutationId(),
      'base': base,
      'data': payload,
      'createdAt': old?['createdAt'] ??
          DateTime.now().toUtc().toIso8601String(),
    }));
    if (!await _retryPendingInternal(uid)) {
      throw const OnboardingDraftQueuedException();
    }
  });

  /// True when committed or no queue; false when offline. A conflicting field
  /// raises an exception but the queued data remains encrypted and intact.
  Future<bool> retryPending(String uid) =>
      _exclusive(() => _retryPendingInternal(uid));

  Future<bool> _retryPendingInternal(String uid) async {
    if (uid.isEmpty || _syncing || !await _ownsSession(uid)) return false;
    _activeUid = uid;
    final pending = await _load(_pendingKey(uid));
    if (pending == null) {
      stopRetry();
      return true;
    }
    _syncing = true;
    try {
      for (var attempt = 0; attempt < 3; attempt++) {
        if (!await _ownsSession(uid)) return false;
        late Map<String, dynamic> remote;
        try {
          remote = _map((await _getProfile())['profile']);
        } catch (_) {
          _schedule(uid);
          return false;
        }
        if ((remote['uid'] != null && remote['uid'] != uid) ||
            !await _ownsSession(uid)) return false;
        if (remote['onboardingLastMutationId'] == pending['id']) {
          await _write(_baseKey(uid), jsonEncode(_snapshot(remote)));
          await _delete(_pendingKey(uid));
          stopRetry();
          return true;
        }
        final changes = _map(pending['data']);
        final baseline = _map(pending['base']);
        final conflicts = <String>[];
        for (final field in _fields) {
          if (!changes.containsKey(field)) continue;
          if (field == 'onboardingText') {
            final intended = changes[field];
            final prior = baseline[field];
            final live = remote[field];
            if (live != prior && live != intended) conflicts.add(field);
            continue;
          }
          final changedEntries = _map(changes[field]);
          final beforeEntries = _map(baseline[field]);
          final currentEntries = _map(remote[field]);
          for (final entry in changedEntries.entries) {
            final prior = beforeEntries[entry.key];
            final live = currentEntries[entry.key];
            if (jsonEncode(live) != jsonEncode(prior) &&
                jsonEncode(live) != jsonEncode(entry.value)) {
              conflicts.add(field + '.' + entry.key);
            }
          }
        }
        if (conflicts.isNotEmpty) {
          stopRetry();
          throw OnboardingDraftConflictException(conflicts);
        }
        final revision = remote['onboardingRevision'] is int
            ? remote['onboardingRevision'] as int : 0;
        try {
          if (!await _ownsSession(uid)) return false;
          final saved = await _post({
            ...changes,
            'draft': true,
            'complete': true,
            'expectedRevision': revision,
            'mutationId': pending['id'],
          });
          final savedProfile = _map(saved['profile']);
          if ((savedProfile['uid'] != null && savedProfile['uid'] != uid) ||
              !await _ownsSession(uid)) return false;
          await _write(_baseKey(uid), jsonEncode(_snapshot(savedProfile)));
          await _delete(_pendingKey(uid));
          stopRetry();
          return true;
        } on PesoApiException catch (error) {
          if (error.statusCode == 409 &&
              error.code == 'onboarding_revision_conflict') continue;
          if (error.statusCode == 0 || error.statusCode == 429 ||
              error.statusCode == 502 || error.statusCode == 503) {
            _schedule(uid);
            return false;
          }
          rethrow;
        }
      }
      _schedule(uid);
      return false;
    } finally {
      _syncing = false;
    }
  }

  void _schedule(String uid) {
    if (_retryTimer?.isActive == true && _activeUid == uid) return;
    _retryTimer?.cancel();
    _activeUid = uid;
    _retryTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      try {
        if (await PesoAuthSession.currentUid() != uid) {
          timer.cancel();
          return;
        }
        await retryPending(uid);
      } on OnboardingDraftConflictException {
        timer.cancel();
      } catch (_) {
        // Keep encrypted local source data until sign-in/reconnection.
      }
    });
  }

  Future<void> resumeAfterSignIn(String uid) async {
    if (uid.isEmpty) return;
    try {
      await retryPending(uid);
    } on OnboardingDraftConflictException {
      // Conflict remains available to the explicit save/review flow.
    } catch (_) {
      if (await hasPending(uid)) _schedule(uid);
    }
  }

  void stopRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _activeUid = null;
  }
}
