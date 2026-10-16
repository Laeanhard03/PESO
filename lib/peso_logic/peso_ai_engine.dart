import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;

import '../peso_models/profile_artifact.dart';
import '../peso_services/gemini_gateway_client.dart';

/// Extracts supported profile facts through the authenticated server-side
/// gateway. Gemini credentials never enter the Flutter runtime.
class PesoAIEngine {
  static const int _maxAttachmentBytes = 4 * 1024 * 1024;

  static Future<Map<String, dynamic>> generateProfile({
    required List<ProfileArtifactInput> artifacts,
    String? rawText,
  }) async {
    final supplementalText = rawText?.trim() ?? '';
    final includedArtifacts = artifacts
        .where((item) =>
            item.includeInAi &&
            item.bytes.isNotEmpty &&
            _isSupportedMimeType(item.mimeType))
        .toList();

    if (supplementalText.isEmpty && includedArtifacts.isEmpty) {
      throw StateError(
        'No resume file or resume/form text was received. Please retry onboarding.',
      );
    }

    final encodedArtifacts = <Map<String, dynamic>>[];
    for (final artifact in includedArtifacts) {
      if (artifact.bytes.length > _maxAttachmentBytes) {
        throw StateError(
          'A resume attachment exceeds the 4 MB limit. Choose a smaller PDF or image.',
        );
      }
      encodedArtifacts.add(<String, dynamic>{
        'mimeType': artifact.mimeType.toLowerCase(),
        'base64': base64Encode(artifact.bytes),
      });
    }

    debugPrint(
      '[PESO AI] Sending profile request to the authenticated Gemini gateway (' +
          encodedArtifacts.length.toString() + ' resume attachment(s)).',
    );
    final profile = await GeminiGatewayClient.extractProfile(
      rawText: supplementalText,
      artifacts: encodedArtifacts,
    );
    debugPrint('[PESO AI] Secure profile extraction completed.');
    return profile;
  }

  static bool _isSupportedMimeType(String value) => const {
        'application/pdf',
        'image/jpeg',
        'image/png',
      }.contains(value.toLowerCase());
}
