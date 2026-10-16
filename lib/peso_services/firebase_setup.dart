// Agent Doctor 6 (2026-10-16): this helper only validates generated options; it does not use Firebase Core APIs.

import '../firebase_options.dart';

class FirebaseSetup {
  FirebaseSetup._();

  static bool get isConfigured {
    try {
      final options = DefaultFirebaseOptions.currentPlatform;
      return options.apiKey.isNotEmpty &&
          !options.apiKey.startsWith('YOUR_') &&
          options.appId.isNotEmpty &&
          !options.appId.startsWith('YOUR_') &&
          options.projectId.isNotEmpty &&
          !options.projectId.startsWith('YOUR_');
    } catch (_) {
      return false;
    }
  }
}
