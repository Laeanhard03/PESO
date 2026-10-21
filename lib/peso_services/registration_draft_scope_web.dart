import 'dart:math';
import 'package:web/web.dart' as web;

/// Only a random nonce is kept in sessionStorage, never applicant fields or
/// a password. The encrypted draft is isolated to the current browser tab.
String registrationDraftScope() {
  try {
    const key = 'peso-registration-tab-nonce';
    var nonce = web.window.sessionStorage.getItem(key);
    if (nonce == null || nonce.length < 24) {
      final secure = Random.secure();
      nonce = List<String>.generate(24, (_) => secure.nextInt(256).toRadixString(16)
          .padLeft(2, '0')).join();
      web.window.sessionStorage.setItem(key, nonce);
    }
    return 'registration-tab-$nonce';
  } catch (_) {
    return 'registration-tab-' +
        Random.secure().nextInt(0x7fffffff).toRadixString(16);
  }
}
