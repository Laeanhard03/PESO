import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:google_generative_ai/google_generative_ai.dart';

import '../peso_models/profile_artifact.dart';
import 'env_cipher.dart';

class PesoAIEngine {
  /// Extracts profile facts from the selected resume(s) and the privacy-filtered
  /// text sent by the React resume builder / NSRP form.
  static Future<Map<String, dynamic>> generateProfile({
    required List<ProfileArtifactInput> artifacts,
    String? rawText,
  }) async {
    debugPrint('\n[PESO AI] Starting unified AI profile generation...');

    final apiKey = (await EnvCipher.getTeamKey()).trim();
    if (apiKey.isEmpty || apiKey == 'your_api_key_here_do_not_commit') {
      throw StateError(
        'Gemini API key is missing. Configure GEMINI_API_KEY in your local .env.',
      );
    }

    final model = GenerativeModel(
      model: 'gemini-3.6-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(responseMimeType: 'application/json'),
    );

    const prompt = '''
You are extracting a real job seeker's profile for a public employment service.
Use only facts supported by the supplied resume and supplemental form text.
Do not invent a person's name, email, employer, degree, certificate, skill, or work history.
If a field cannot be supported by the source, return an empty string, empty array, or 0 as appropriate.
Do not use sample-template names or sample-template employment history as the applicant's facts unless the user clearly entered those values as their own.
Do not reproduce government ID numbers, tax identifiers, passport numbers, household IDs, or other sensitive identifiers in the output.

Return only a valid JSON object using these keys:
- "fullName": string
- "professionalTitle": string
- "email": string
- "skills": array of up to 10 factual skills
- "bilingualBio": string; write concise English and Tagalog summaries based only on supported facts; otherwise empty string
- "yearsExperience": integer; estimate only when dates support the estimate, otherwise 0
- "education": array of strings
- "employmentHistory": array of strings
- "certifications": array of strings

Supplemental form text may contain blank fields or sample/template content. Treat unchecked or empty fields as absent.
''';

    final parts = <Part>[TextPart(prompt)];
    final supplementalText = rawText?.trim() ?? '';
    if (supplementalText.isNotEmpty) {
      debugPrint('[PESO AI] Appending React resume/NSRP text data...');
      parts.add(TextPart('SUPPLEMENTAL RESUME / NSRP TEXT (sensitive ID fields removed):\n$supplementalText'));
    }

    // Send only uploaded source resumes as file bytes. The React resume builder
    // uses sample-filled templates, so its edited field text is sent above rather
    // than its PDF. NSRP PDFs can contain government identifiers and are never
    // sent to Gemini; all source documents are stored privately for the user.
    for (final artifact in artifacts.where((item) => item.includeInAi)) {
      if (artifact.bytes.isEmpty) continue;
      if (!_isSupportedMimeType(artifact.mimeType)) continue;
      debugPrint('[PESO AI] Attaching ${artifact.fileName} (${artifact.mimeType})');
      parts.add(DataPart(artifact.mimeType, artifact.bytes));
    }

    if (parts.length == 1) {
      throw StateError('No resume file or resume/form text was received. Please retry onboarding.');
    }

    final content = [Content.multi(parts)];
    const maxRetries = 4;
    var delayMs = 1500;

    for (var attempt = 0; attempt < maxRetries; attempt++) {
      try {
        debugPrint('[PESO AI] Sending unified payload (attempt ${attempt + 1} of $maxRetries)...');
        final response = await model.generateContent(content);
        final responseText = response.text;
        if (responseText == null || responseText.trim().isEmpty) {
          throw FormatException('Gemini returned an empty profile response.');
        }
        final decoded = jsonDecode(responseText);
        if (decoded is! Map) {
          throw FormatException('Gemini returned JSON that is not an object.');
        }
        debugPrint('[PESO AI] Successfully generated structured profile.');
        return Map<String, dynamic>.from(decoded);
      } catch (error) {
        final message = error.toString();
        final retryable = message.contains('503') ||
            message.contains('UNAVAILABLE') ||
            message.contains('429') ||
            message.contains('RESOURCE_EXHAUSTED');
        if (!retryable || attempt == maxRetries - 1) {
          debugPrint('[PESO AI ERROR] Extraction failed: $error');
          rethrow;
        }
        debugPrint('[PESO AI WARN] Temporary Gemini capacity issue; retrying in ${delayMs / 1000}s.');
        await Future<void>.delayed(Duration(milliseconds: delayMs));
        delayMs = (delayMs * 2).clamp(1500, 8000).toInt();
      }
    }

    throw StateError('Gemini did not return a usable profile.');
  }

  static bool _isSupportedMimeType(String value) => const {
        'application/pdf',
        'image/jpeg',
        'image/png',
      }.contains(value.toLowerCase());
}
