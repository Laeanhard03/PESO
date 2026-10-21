/// Legacy compatibility shim. AI provider credentials belong on the trusted
/// PESO backend; never include provider keys in Flutter source or bundles.
@Deprecated('Use the authenticated PESO API; provider keys must not be read on-device.')
class EnvCipher {
  EnvCipher._();

  static Future<String> getTeamKey() async {
    throw UnsupportedError(
      'Client-side Gemini key access has been removed. Configure the trusted PESO API backend.',
    );
  }
}
