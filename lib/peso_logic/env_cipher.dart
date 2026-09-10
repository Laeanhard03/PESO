import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvCipher {
  // A 32-character key shared with the team in the codebase to lock/unlock the JSON
  static final _key = enc.Key.fromUtf8('PesoJobKonek2026SecureCipherKey!');
  static final _iv = enc.IV.fromLength(16);
  static const _jsonPath = 'lib/peso_logic/secrets.json';

  /// The app uses this to decrypt the key for everyone or fallback to the local .env
  static Future<String> getTeamKey() async {
    // 1. Direct priority: If .env is already loaded and contains the key, use it directly
    if (dotenv.isInitialized &&
        (dotenv.env['GEMINI_API_KEY']?.isNotEmpty ?? false)) {
      return dotenv.env['GEMINI_API_KEY']!;
    }

    // 2. Secondary: Try reading the encrypted secrets.json asset
    try {
      final jsonString = await rootBundle.loadString(_jsonPath);
      final data = jsonDecode(jsonString);
      final encryptedKey = data['gemini_api_key'];

      if (encryptedKey != null && encryptedKey.toString().isNotEmpty) {
        final encrypter = enc.Encrypter(enc.AES(_key));
        return encrypter.decrypt(
          enc.Encrypted.fromBase64(encryptedKey),
          iv: _iv,
        );
      }
    } catch (e) {
      print('[INFO] secrets.json not found or empty, attempting .env load...');
    }

    // 3. Fallback: Try loading .env if it wasn't initialized
    try {
      if (!dotenv.isInitialized) {
        await dotenv.load(fileName: ".env");
      }
      return dotenv.env['GEMINI_API_KEY'] ?? '';
    } catch (e) {
      print(
        '[ERROR] Neither secrets.json nor .env could provide the API key: $e',
      );
      return '';
    }
  }
}
