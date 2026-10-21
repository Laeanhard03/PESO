import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import 'peso_auth_session.dart';

class GeminiGatewayException implements Exception {
  const GeminiGatewayException({
    required this.message,
    required this.statusCode,
    this.retryAfterSeconds,
    this.code,
  });

  final String message;
  final int statusCode;
  final int? retryAfterSeconds;
  final String? code;

  @override
  String toString() {
    if (retryAfterSeconds != null) {
      return '$message Try again in about $retryAfterSeconds seconds.';
    }
    return message;
  }
}

/// Authenticated client for the server-side Gemini gateway.
/// The URL is public configuration; no provider credential is compiled into
/// this client. Configure it using --dart-define at build time.
class GeminiGatewayClient {
  GeminiGatewayClient._();

  static const String _gatewayUrl = String.fromEnvironment(
    'GEMINI_GATEWAY_URL',
    defaultValue: '',
  );

  static Future<Map<String, dynamic>> query(String prompt) async {
    final response = await _send(<String, dynamic>{
      'operation': 'query',
      'prompt': prompt,
    });
    return <String, dynamic>{
      'text': response['text']?.toString() ?? '',
    };
  }

  static Future<Map<String, dynamic>> extractProfile({
    required String rawText,
    required List<Map<String, dynamic>> artifacts,
  }) async {
    final response = await _send(<String, dynamic>{
      'operation': 'profile_extraction',
      'rawText': rawText,
      'artifacts': artifacts,
    });
    final profile = response['profile'];
    if (profile is! Map) {
      throw const FormatException(
        'The secure Gemini service returned an invalid profile.',
      );
    }
    return Map<String, dynamic>.from(profile);
  }

  static Future<Map<String, dynamic>> _send(
    Map<String, dynamic> payload,
  ) async {
    if (_gatewayUrl.trim().isEmpty) {
      throw StateError(
        'The secure Gemini service is not deployed or configured. '
        'Build with --dart-define=GEMINI_GATEWAY_URL=https://YOUR_FUNCTION_URL.',
      );
    }

    final uri = Uri.tryParse(_gatewayUrl);
    if (uri == null ||
        !uri.hasAuthority ||
        !(uri.scheme == 'https' ||
            (uri.scheme == 'http' &&
                (uri.host == 'localhost' || uri.host == '127.0.0.1')))) {
      throw StateError('GEMINI_GATEWAY_URL must be a valid HTTPS URL.');
    }

    final token = await PesoAuthSession.getBearerToken();
    if (token == null || token.isEmpty) {
      throw StateError('Sign in before using Gemini.');
    }

    late final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: <String, String>{
              'content-type': 'application/json',
              'authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 245));
    } on Exception {
      debugPrint(
        '[GEMINI] Secure gateway request failed before receiving a response.',
      );
      rethrow;
    }

    Map<String, dynamic> result = <String, dynamic>{};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        result = Map<String, dynamic>.from(decoded);
      }
    } on FormatException {
      // Use a generic message rather than exposing a raw non-JSON response.
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = result['error']?.toString() ??
          'The secure Gemini service could not complete the request.';
      final seconds = int.tryParse(
        result['retryAfterSeconds']?.toString() ??
            response.headers['retry-after'] ??
            '',
      );
      throw GeminiGatewayException(
        message: message,
        statusCode: response.statusCode,
        retryAfterSeconds: seconds,
        code: result['code']?.toString(),
      );
    }

    return result;
  }
}
