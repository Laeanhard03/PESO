import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'peso_api_client.dart';

/// Encrypted local draft storage keyed by authenticated account. Never cookies.
class ApplicantDraftService {
  ApplicantDraftService._();
  static const _storage = FlutterSecureStorage();
  static String _key(String uid, String kind) => 'peso_applicant_$uid' '_$kind';

  static Future<Map<String, dynamic>?> read(String uid, String kind) async {
    if (uid.isEmpty) return null;
    try {
      final raw = await _storage.read(key: _key(uid, kind));
      final data = raw == null ? null : jsonDecode(raw);
      return data is Map ? Map<String, dynamic>.from(data) : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String uid, String kind, Map<String, dynamic> draft) async {
    if (uid.isEmpty) throw StateError('Sign in before saving a draft.');
    await _storage.write(key: _key(uid, kind), value: jsonEncode(draft));
  }

  static Future<void> clear(String uid, String kind) async {
    if (uid.isNotEmpty) await _storage.delete(key: _key(uid, kind));
  }

  static Map<String, dynamic> newest(
    Map<String, dynamic> remote, Map<String, dynamic>? local,
  ) {
    if (local == null || local.isEmpty) return remote;
    if (remote.isEmpty) return local;
    final localAt = DateTime.tryParse(local['draftUpdatedAt']?.toString() ?? '');
    final remoteAt = DateTime.tryParse(remote['draftUpdatedAt']?.toString() ?? '');
    return localAt != null && (remoteAt == null || localAt.isAfter(remoteAt))
        ? local : remote;
  }

  /// Merge only pendingDraft; never overwrite a submitted form on autosave.
  static Future<void> sync(String kind, Map<String, dynamic> draft) async {
    final field = kind == 'resume' ? 'resumeData' : 'pesoFormData';
    final result = await PesoApiClient.getProfile();
    final profile = result['profile'] is Map
        ? Map<String, dynamic>.from(result['profile'] as Map)
        : <String, dynamic>{};
    final existing = profile[field] is Map
        ? Map<String, dynamic>.from(profile[field] as Map)
        : <String, dynamic>{};
    final previous = existing['pendingDraft'] is Map
        ? Map<String, dynamic>.from(existing['pendingDraft'] as Map)
        : <String, dynamic>{};
    final remoteAt = DateTime.tryParse(previous['draftUpdatedAt']?.toString() ?? '');
    final localAt = DateTime.tryParse(draft['draftUpdatedAt']?.toString() ?? '');
    if (remoteAt != null && (localAt == null || remoteAt.isAfter(localAt))) {
      throw StateError('A newer server draft exists. Reopen before saving.');
    }
    await PesoApiClient.saveOnboarding(<String, dynamic>{
      'draft': true,
      'expectedRevision': (profile['onboardingRevision'] as num?)?.toInt() ?? 0,
      field: <String, dynamic>{'pendingDraft': draft},
    });
  }
}
