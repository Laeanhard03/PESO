import 'dart:convert';
import 'dart:typed_data';

/// A document produced or selected during profile onboarding.
/// `category` is one of: resume_upload, resume_builder, nsrp_form.
class ProfileArtifactInput {
  const ProfileArtifactInput({
    required this.fileName,
    required this.category,
    required this.mimeType,
    required this.bytes,
  });

  final String fileName;
  final String category;
  final String mimeType;
  final Uint8List bytes;

  /// Only an original uploaded resume is sent as file bytes to Gemini.
  /// Resume-builder templates contain example content, so send only their
  /// changed field text. NSRP PDFs may contain government identifiers.
  bool get includeInAi => category == 'resume_upload';

  static ProfileArtifactInput? fromBridgePayload(Object? rawPayload) {
    if (rawPayload is! Map) return null;
    final payload = Map<String, dynamic>.from(rawPayload);
    final encoded = payload['base64']?.toString() ?? '';
    if (encoded.isEmpty) return null;

    try {
      final bytes = base64Decode(encoded);
      if (bytes.isEmpty) return null;
      return ProfileArtifactInput(
        fileName: _safeFileName(payload['fileName']?.toString() ?? 'document.pdf'),
        category: payload['category']?.toString() ?? 'resume_upload',
        mimeType: payload['mimeType']?.toString() ?? 'application/pdf',
        bytes: bytes,
      );
    } on FormatException {
      return null;
    }
  }

  static String _safeFileName(String value) {
    final base = value.split(RegExp(r'[/\\]')).last.trim();
    return base.isEmpty ? 'document.pdf' : base.replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '_');
  }
}
