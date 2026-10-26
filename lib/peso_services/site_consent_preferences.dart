import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Preferences for the public website's notice acknowledgement and cookie choice.
/// Registration's Terms/Privacy/data-processing consent is separate and remains required.
abstract final class SiteConsentPreferences {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _noticeKey = 'peso.site-notice.acknowledgement.v1';
  static const String _noticeVersion = 'prototype-2026-10-26-v1';
  static const String _cookieKey = 'peso.site-cookie-choice.v1';

  static bool _noticeAcknowledgedThisSession = false;
  static String? _cookieChoiceThisSession;

  static Future<bool> hasAcknowledgedNotice() async {
    if (_noticeAcknowledgedThisSession) return true;
    try {
      final stored = await _storage.read(key: _noticeKey);
      if (stored == _noticeVersion) {
        _noticeAcknowledgedThisSession = true;
        return true;
      }
    } catch (_) {
      // If secure browser storage is unavailable, continue with session-only
      // acknowledgement rather than blocking access to the public page.
    }
    return false;
  }

  static Future<bool> isNoticeRemembered() async {
    try {
      return await _storage.read(key: _noticeKey) == _noticeVersion;
    } catch (_) {
      return false;
    }
  }

  static Future<void> acknowledgeNotice({required bool remember}) async {
    _noticeAcknowledgedThisSession = true;
    try {
      if (remember) {
        await _storage.write(key: _noticeKey, value: _noticeVersion);
      } else {
        await _storage.delete(key: _noticeKey);
      }
    } catch (_) {
      // The in-memory session acknowledgement still prevents repeated dialogs
      // while this page session is alive.
    }
  }

  /// Returns all-v1, essential-v1, or null when the visitor has not chosen.
  static Future<String?> readCookieChoice() async {
    final inSession = _cookieChoiceThisSession;
    if (inSession != null) return inSession;
    try {
      final stored = await _storage.read(key: _cookieKey);
      if (stored == 'all-v1' || stored == 'essential-v1') {
        _cookieChoiceThisSession = stored;
        return stored;
      }
    } catch (_) {
      // Treat unavailable storage as undecided and show the banner again.
    }
    return null;
  }

  static Future<void> saveCookieChoice(String choice) async {
    if (choice != 'all-v1' && choice != 'essential-v1') {
      throw ArgumentError.value(choice, 'choice', 'Unsupported cookie choice.');
    }
    _cookieChoiceThisSession = choice;
    try {
      await _storage.write(key: _cookieKey, value: choice);
    } catch (_) {
      // Keep the preference for this session even if persistent storage fails.
    }
  }
}
