import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Firebase-only bearer/session provider for authenticated PESO API calls.
/// Email/password and Google are the only enabled app authentication flows.
class PesoAuthSession {
  PesoAuthSession._();

  static const FlutterSecureStorage _legacyStorage = FlutterSecureStorage();
  static bool _legacyCleanupAttempted = false;

  static Future<void> _clearLegacySmsSessionData() async {
    if (_legacyCleanupAttempted) return;
    _legacyCleanupAttempted = true;

    // Remove tokens from the retired SMS-only sign-in feature. They are no
    // longer accepted by the backend and must never become an auth fallback.
    try {
      await _legacyStorage.write(key: 'peso.sms.active', value: '0');
      await _legacyStorage.delete(key: 'peso.sms.session_token');
      await _legacyStorage.delete(key: 'peso.sms.expires_at');
      await _legacyStorage.delete(key: 'peso.sms.user');
    } catch (_) {
      // A cleanup issue must not replace or weaken the current Firebase identity.
    }
  }

  static Future<String?> getBearerToken() async {
    await _clearLegacySmsSessionData();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) return null;
    return token;
  }

  static Future<bool> hasAuthenticatedSession() async =>
      (await getBearerToken()) != null;

  static Future<String?> currentUid() async {
    await _clearLegacySmsSessionData();
    return FirebaseAuth.instance.currentUser?.uid;
  }
}
