import 'dart:convert';
import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart';

import 'env_cipher.dart';

class PesoAIEngine {
  /// Parses resumes from PDFs, JPGs, or PNGs using Gemini 1.5 Flash
  static Future<Map<String, dynamic>> parseResume(
    Uint8List fileBytes,
    String extension,
  ) async {
    // 1. Grab the decrypted key securely
    final String actualApiKey = await EnvCipher.getTeamKey();

    if (actualApiKey.isEmpty) {
      throw Exception('Decrypted API Key is missing');
    }

    // 2. Initialize Gemini
    final model = GenerativeModel(
      model: 'gemini-3.6-flash', // Updated to the required 3.6 version
      apiKey: actualApiKey,
      generationConfig: GenerationConfig(responseMimeType: 'application/json'),
    );

    // 3. Set the prompt
    const prompt = '''
    Analyze this resume and extract the following information. 
    Return the result strictly as a JSON object using exactly these keys:
    - "fullName": (string)
    - "professionalTitle": (string)
    - "email": (string)
    - "skills": (list of strings, max 5 key skills)
    - "bilingualBio": (string, write a short professional bio summarizing their experience in Tagalog and English)
    - "yearsExperience": (integer, estimate based on work history dates)
    ''';

    // 4. Map the file extension to the correct MIME type
    String mimeType;
    switch (extension.toLowerCase()) {
      case 'pdf':
        mimeType = 'application/pdf';
        break;
      case 'jpg':
      case 'jpeg':
        mimeType = 'image/jpeg';
        break;
      case 'png':
        mimeType = 'image/png';
        break;
      case 'webp':
        mimeType = 'image/webp';
        break;
      default:
        mimeType = 'application/pdf'; // Fallback
    }

    // 5. Package and send the payload
    final content = [
      Content.multi([TextPart(prompt), DataPart(mimeType, fileBytes)]),
    ];

    try {
      final response = await model.generateContent(content);
      final jsonString = response.text;

      if (jsonString != null) {
        return jsonDecode(jsonString);
      }
      return {};
    } catch (e) {
      throw Exception('Gemini extraction failed: $e');
    }
  }
}
