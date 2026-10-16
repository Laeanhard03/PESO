/// Legacy compatibility shim. Gemini credentials must only be read by the
/// server-side Firebase Function from Google Secret Manager.
@Deprecated('Use GeminiGatewayClient; provider keys must not be read on-device.')
class EnvCipher {
  EnvCipher._();

  static Future<String> getTeamKey() async {
    throw UnsupportedError(
      'Client-side Gemini key access has been removed. Configure the secure gateway.',
    );
  }
}
