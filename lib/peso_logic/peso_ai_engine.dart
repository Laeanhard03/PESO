import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;

import '../peso_models/profile_artifact.dart';
import '../peso_services/peso_api_client.dart';

/// Extracts supported profile facts through the authenticated server-side
/// MongoDB-backed PESO API. Gemini credentials never enter the Flutter runtime.
class PesoAIEngine {
  static const int _maxAttachmentBytes = 4 * 1024 * 1024;

  static Future<Map<String, dynamic>> generateProfile({
    required List<ProfileArtifactInput> artifacts,
    String? rawText,
    bool persist = true,
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
        'fileName': artifact.fileName,
        'category': artifact.category,
        'mimeType': artifact.mimeType.toLowerCase(),
        'base64': base64Encode(artifact.bytes),
      });
    }

    debugPrint(
      '[PESO AI] Sending profile request to the authenticated PESO API (' +
          encodedArtifacts.length.toString() + ' resume attachment(s)).',
    );
    final response = await PesoApiClient.extractProfile(
      rawText: supplementalText,
      artifacts: encodedArtifacts,
      persist: persist,
    );
    final profile = response['profile'];
    if (profile is! Map) {
      throw StateError('The PESO API returned an invalid extracted profile.');
    }
    debugPrint('[PESO AI] Secure profile extraction completed.');
    return Map<String, dynamic>.from(profile);
  }

  static bool _isSupportedMimeType(String value) => const {
        'application/pdf',
        'image/jpeg',
        'image/png',
      }.contains(value.toLowerCase());
}
