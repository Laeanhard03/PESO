import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'peso_auth_session.dart';

import 'package:http/http.dart' as http;

/// Safe error returned by the non-Firebase PESO API.
class PesoApiException implements Exception {
  const PesoApiException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  final int statusCode;
  final String code;
  final String message;

  @override
  String toString() => message;
}

/// HTTP client for MongoDB-backed PESO application data.
///
/// Firebase supplies the signed-in identity/ID token only. The API verifies
/// the token server-side and reads/writes profiles and artifacts in MongoDB.
class PesoApiClient {
  PesoApiClient._();

  static const String _configuredBaseUrl = String.fromEnvironment(
    'PESO_API_BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    // Production and preview builds use the API bundled under their own origin.
    // This prevents a stale Vercel environment variable from routing users to
    // the retired separately deployed API or to the user's localhost.
    if (kIsWeb &&
        Uri.base.host.toLowerCase() != 'localhost' &&
        Uri.base.host != '127.0.0.1') {
      return Uri.base.origin;
    }
    final configured = _configuredBaseUrl.trim();
    if (configured.isNotEmpty) {
      return configured.replaceFirst(RegExp(r'/+$'), '');
    }
    // 10.0.2.2 is the Android Emulator's route to the host computer.
    // Physical phones should use --dart-define=PESO_API_BASE_URL=<reachable HTTPS/LAN URL>.
    final defaultUrl =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:3000'
        : 'http://127.0.0.1:3000';
    return defaultUrl;
  }

  static final http.Client _http = http.Client();
  static const int _maxArtifactBytes = 20 * 1024 * 1024;
  // Keep each base64 JSON request comfortably below Vercel's 4.5 MB limit.
  static const int _maxInlineArtifactUploadBytes = 3 * 1024 * 1024;
  static const int _artifactChunkBytes = 1024 * 1024;
  static const int _artifactChunkConcurrency = 3;

  /// Public, owner-independent catalog discovery for the landing/Home/Jobs
  /// screens. No Firebase token or private matching data is requested.
  static Future<Map<String, dynamic>> publicListJobs({
    int limit = 60,
    String? pageToken,
    String? search,
    String? category,
    String? employmentType,
  }) => _request(
    'GET',
    '/api/public/jobs',
    authenticated: false,
    query: <String, String>{
      'limit': limit.clamp(1, 100).toString(),
      if (pageToken != null && pageToken.isNotEmpty) 'pageToken': pageToken,
      if (search != null && search.trim().isNotEmpty) 'q': search.trim(),
      if (category != null && category.isNotEmpty) 'category': category,
      if (employmentType != null && employmentType.isNotEmpty)
        'type': employmentType,
    },
    timeout: const Duration(seconds: 20),
  );

  /// Public, non-sensitive landing-page content. The UI falls back to bundled
  /// gallery and partner assets until IT Admin saves custom content.
  static Future<Map<String, dynamic>> publicGetLandingSiteContent() => _request(
    'GET',
    '/api/public/site-content',
    authenticated: false,
    timeout: const Duration(seconds: 20),
  );

  static Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    Duration timeout = const Duration(seconds: 45),
    bool authenticated = true,
  }) async {
    String? token;
    if (authenticated) {
      token = await PesoAuthSession.getBearerToken();
      if (token == null || token.isEmpty) {
        throw const PesoApiException(
          statusCode: 401,
          code: 'unauthenticated',
          message: 'Sign in before accessing PESO data.',
        );
      }
    }

    final base = Uri.parse(baseUrl);
    final uri = base.replace(
      path: base.path.replaceFirst(RegExp(r'/$'), '') + path,
      queryParameters: query,
    );
    final request = http.Request(method, uri)
      ..headers['Accept'] = 'application/json';
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    try {
      final streamed = await _http.send(request).timeout(timeout);
      final response = await http.Response.fromStream(streamed)
          .timeout(timeout);
      Map<String, dynamic> payload = <String, dynamic>{};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          payload = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        // Non-JSON error bodies are converted to a safe generic error below.
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final code = payload['error']?.toString() ?? 'api_request_failed';
        final message =
            payload['message']?.toString() ??
            _statusMessage(response.statusCode);
        throw PesoApiException(
          statusCode: response.statusCode,
          code: code,
          message: message,
        );
      }
      return payload;
    } on PesoApiException {
      rethrow;
    } catch (error) {
      throw PesoApiException(
        statusCode: 0,
        code: 'api_unreachable',
        message:
            'The PESO data API at $baseUrl could not be reached. Check that the backend is running and its MongoDB connection is configured.',
      );
    }
  }

  static String _statusMessage(int status) {
    if (status == 401) return 'Your session expired. Sign in again.';
    if (status == 403) return 'Your account is not authorized for this action.';
    if (status == 404) return 'The requested PESO record was not found.';
    if (status == 503) {
      return 'The PESO API is not ready. Check its MongoDB and authentication configuration.';
    }
    return 'The PESO API request failed (HTTP $status). Please retry.';
  }

  static Future<Map<String, dynamic>> health() async {
    final uri = Uri.parse('$baseUrl/api/health');
    try {
      final response = await _http.get(uri).timeout(const Duration(seconds: 8));
      final decoded = jsonDecode(response.body);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      // Do not leak network exceptions or credentials to the UI.
    }
    return <String, dynamic>{
      'ok': false,
      'mongoDbConnected': false,
      'firebaseTokenVerificationReady': false,
      'smsAuthReady': false,
      'appRolesStoredIn': 'mongodb',
    };
  }

  static Future<Map<String, dynamic>> ensureProfile({
    Map<String, dynamic> body = const <String, dynamic>{},
  }) => _request('POST', '/api/profile/ensure', body: body);

  static Future<Map<String, dynamic>> getResidencyBarangays() =>
      _request('GET', '/api/residency/barangays', authenticated: false);

  static Future<Map<String, dynamic>> getMyResidency() =>
      _request('GET', '/api/account/residency');

  static Future<Map<String, dynamic>> saveMyResidency({
    required String barangay,
    required String address,
    int? expectedRevision,
  }) => _request(
    'PUT',
    '/api/account/residency',
    body: {
      'municipality': 'Montalban',
      'barangay': barangay,
      'address': address,
      if (expectedRevision != null) 'expectedRevision': expectedRevision,
    },
  );

  static Future<Map<String, dynamic>> reviewResidency({
    required String uid,
    required String status,
    required int expectedRevision,
    String? note,
    String? evidenceType,
  }) => _request(
    'PATCH',
    '/api/admin/users/' + Uri.encodeComponent(uid) + '/residency',
    body: {
      'status': status,
      'expectedRevision': expectedRevision,
      if (note != null) 'note': note,
      if (evidenceType != null) 'evidenceType': evidenceType,
    },
  );

  static Future<Map<String, dynamic>> getResidencyAudit(String uid) => _request(
    'GET',
    '/api/admin/users/' + Uri.encodeComponent(uid) + '/residency/audit',
  );

  static Future<Map<String, dynamic>> getMyDocumentStatus() =>
      _request('GET', '/api/account/documents');

  static Future<Map<String, dynamic>> getProfile() =>
      _request('GET', '/api/profile');

  static Future<Map<String, dynamic>> getAccountDocuments() =>
      _request('GET', '/api/account/documents');

  static Future<Map<String, dynamic>> getAccountResidency() =>
      _request('GET', '/api/account/residency');

  static Future<Map<String, dynamic>> updateAccountResidency({
    required String barangay,
    required String address,
  }) => _request(
    'PUT',
    '/api/account/residency',
    body: <String, dynamic>{
      'municipality': 'Montalban',
      'barangay': barangay,
      'address': address,
    },
  );

  static Future<Map<String, dynamic>> savePrivacyConsent({
    required String termsAcceptedAt,
    required String personalDataConsentAt,
    required String policyVersion,
  }) => _request(
    'PUT',
    '/api/account/privacy-consent',
    body: {
      'termsAccepted': true,
      'privacyPolicyRead': true,
      'personalDataConsent': true,
      'termsAcceptedAt': termsAcceptedAt,
      'personalDataConsentAt': personalDataConsentAt,
      'policyVersion': policyVersion,
    },
  );
  static Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> changes,
  ) => _request('PUT', '/api/profile', body: changes);

  static Future<Map<String, dynamic>> saveOnboarding(
    Map<String, dynamic> data,
  ) => _request('PATCH', '/api/profile/onboarding', body: data);

  static Future<Map<String, dynamic>> saveAiProfile(
    Map<String, dynamic> aiProfile,
  ) => _request(
    'PATCH',
    '/api/profile/ai-profile',
    body: <String, dynamic>{'aiProfile': aiProfile},
  );

  static Future<Map<String, dynamic>> savePreferences(
    Map<String, dynamic> preferences,
  ) => _request(
    'PATCH',
    '/api/profile/preferences',
    body: <String, dynamic>{'preferences': preferences},
  );

  static Future<Map<String, dynamic>> saveOutcomes(
    List<Map<String, dynamic>> outcomes,
  ) => _request(
    'PATCH',
    '/api/profile/outcomes',
    body: <String, dynamic>{'assessmentOutcomes': outcomes},
  );

  static Future<Map<String, dynamic>> submitJobApplication({
    required Map<String, dynamic> job,
    required Map<String, dynamic> answers,
  }) => _request(
    'POST',
    '/api/applications',
    body: <String, dynamic>{
      'jobId': job['id']?.toString() ?? job['title']?.toString() ?? '',
      'jobTitle': job['title']?.toString() ?? '',
      'employer': job['company']?.toString() ?? '',
      'location': job['location']?.toString() ?? '',
      'category': job['category']?.toString() ?? '',
      'matchScore':
          (job['fieldSimilarityScore'] ?? job['match']) is num &&
              (job['fieldSimilarityScore'] ?? job['match']) >= 0 &&
              (job['fieldSimilarityScore'] ?? job['match']) <= 100
          ? ((job['fieldSimilarityScore'] ?? job['match']) as num).toInt()
          : null,
      'answers': answers,
    },
    timeout: const Duration(seconds: 45),
  );

  static Future<Map<String, dynamic>> extractProfile({
    required String rawText,
    required List<Map<String, dynamic>> artifacts,
    List<String> artifactIds = const <String>[],
    bool persist = true,
  }) => _request(
    'POST',
    '/api/ai/profile',
    body: <String, dynamic>{
      'rawText': rawText,
      'artifacts': artifacts,
      'artifactIds': artifactIds,
      'persist': persist,
    },
    timeout: const Duration(seconds: 245),
  );

  /// The backend validates every selected role against one source-linked notice.
  static Future<Map<String, dynamic>> compareNoticeRoles({
    required String noticeId,
    required List<String> jobIds,
  }) => _request(
    'POST',
    '/api/ai/job-match',
    body: <String, dynamic>{'noticeId': noticeId, 'jobIds': jobIds},
    timeout: const Duration(seconds: 25),
  );

  /// Recompute actual Mini-AI recommendations from the owner's saved NSRP
  /// and resume. Unlike the optional Gemini explanation, this never needs MRQ.
  static Future<Map<String, dynamic>> evaluateCareerRecommendations() =>
      _request(
        'GET',
        '/api/ai/job-recommendations',
        timeout: const Duration(seconds: 30),
      );

  static Future<Map<String, dynamic>> evaluateJobMatch({
    required String jobId,
  }) => _request(
    'POST',
    '/api/ai/job-match',
    // Post-evaluation MRQ answers are application information, never model input.
    body: <String, dynamic>{'jobId': jobId},
    timeout: const Duration(seconds: 20),
  );

  /// Optional, non-scoring Gemini explanation of the ALREADY saved Go result.
  /// MRQ answers, resume content and credentials are not sent in this request.
  static Future<Map<String, dynamic>> explainJobMatch({
    required String jobId,
  }) => _request(
    'POST',
    '/api/ai/job-feedback',
    body: <String, dynamic>{'jobId': jobId},
    timeout: const Duration(seconds: 19),
  );

  static Future<Map<String, dynamic>> translateJob({
    required String jobId,
    required String language,
  }) => _request(
    'POST',
    '/api/jobs/${Uri.encodeComponent(jobId)}/translation',
    body: {'language': language},
    timeout: const Duration(seconds: 80),
  );

  static Future<Map<String, dynamic>> queryAi(String prompt) => _request(
    'POST',
    '/api/ai/query',
    body: <String, dynamic>{'prompt': prompt},
    timeout: const Duration(seconds: 245),
  );

  static Future<Map<String, dynamic>> uploadArtifact({
    required String fileName,
    required String category,
    required String mimeType,
    required List<int> bytes,
  }) async {
    if (bytes.isEmpty || bytes.length > _maxArtifactBytes) {
      throw const PesoApiException(
        statusCode: 413,
        code: 'artifact_size_limit',
        message: 'Choose a non-empty PDF/JPG/PNG file no larger than 20 MB.',
      );
    }

    if (bytes.length <= _maxInlineArtifactUploadBytes) {
      final response = await _request(
        'POST',
        '/api/artifacts',
        body: <String, dynamic>{
          'fileName': fileName,
          'category': category,
          'mimeType': mimeType,
          'base64': base64Encode(bytes),
        },
        timeout: const Duration(seconds: 90),
      );
      return _artifactFromResponse(response);
    }

    // Vercel Functions reject request bodies over 4.5 MB. Send larger files
    // as 1 MB base64 chunks, then let the authenticated API assemble them into
    // the same owner-scoped GridFS store used by normal artifact uploads.
    final session = await _request(
      'POST',
      '/api/artifacts/upload-sessions',
      body: <String, dynamic>{
        'fileName': fileName,
        'category': category,
        'mimeType': mimeType,
        'sizeBytes': bytes.length,
      },
      timeout: const Duration(seconds: 25),
    );
    final sessionId = session['sessionId']?.toString() ?? '';
    if (sessionId.isEmpty) {
      throw const PesoApiException(
        statusCode: 502,
        code: 'invalid_artifact_upload_session',
        message: 'The PESO API could not start the secure document upload.',
      );
    }

    final sessionPath =
        '/api/artifacts/upload-sessions/${Uri.encodeComponent(sessionId)}';
    try {
      final chunkCount =
          (bytes.length + _artifactChunkBytes - 1) ~/ _artifactChunkBytes;
      var nextChunkIndex = 0;
      Future<void> uploadNextChunk() async {
        while (true) {
          // Claim the next index before awaiting so workers never upload the
          // same part. The server assembles chunks by index, not arrival order.
          final chunkIndex = nextChunkIndex++;
          if (chunkIndex >= chunkCount) return;
          final offset = chunkIndex * _artifactChunkBytes;
          final end = offset + _artifactChunkBytes < bytes.length
              ? offset + _artifactChunkBytes
              : bytes.length;
          final chunk = bytes.sublist(offset, end);
          for (var attempt = 0; attempt < 3; attempt++) {
            try {
              await _request(
                'PUT',
                '$sessionPath/chunks/$chunkIndex',
                body: <String, dynamic>{'base64': base64Encode(chunk)},
                timeout: const Duration(seconds: 35),
              );
              break;
            } catch (error) {
              final transient =
                  error is PesoApiException &&
                  (error.statusCode == 0 ||
                      error.statusCode == 502 ||
                      error.statusCode == 503 ||
                      error.statusCode == 504);
              if (!transient || attempt == 2) rethrow;
              await Future<void>.delayed(
                Duration(milliseconds: 500 * (1 << attempt)),
              );
            }
          }
        }
      }

      final workerCount = chunkCount < _artifactChunkConcurrency
          ? chunkCount
          : _artifactChunkConcurrency;
      await Future.wait(
        List<Future<void>>.generate(workerCount, (_) => uploadNextChunk()),
      );
      final completed = await _request(
        'POST',
        '$sessionPath/complete',
        body: const <String, dynamic>{},
        timeout: const Duration(seconds: 90),
      );
      return _artifactFromResponse(completed);
    } catch (error) {
      try {
        final cleanup = await _request(
          'DELETE',
          sessionPath,
          timeout: const Duration(seconds: 15),
        );
        // The completion response may have been lost after GridFS committed.
        // The server keeps a short-lived idempotency record for this case.
        if (cleanup['completed'] == true) {
          return _artifactFromResponse(cleanup);
        }
      } catch (_) {
        // Keep the original upload error; expired sessions are cleaned server-side.
      }
      Error.throwWithStackTrace(error, StackTrace.current);
    }
  }

  static Map<String, dynamic> _artifactFromResponse(
    Map<String, dynamic> response,
  ) {
    final raw = response['artifact'];
    if (raw is! Map) {
      throw const PesoApiException(
        statusCode: 502,
        code: 'invalid_artifact_response',
        message: 'The PESO API did not return the uploaded document record.',
      );
    }
    return Map<String, dynamic>.from(raw);
  }

  static Future<List<Map<String, dynamic>>> listArtifacts() async {
    final response = await _request('GET', '/api/artifacts');
    return (response['artifacts'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  /// Fetch owner-checked bytes for in-app preview (no signed URL or popup).
  static Future<Uint8List> readArtifactBytes(String artifactId) async {
    final token = await PesoAuthSession.getBearerToken();
    if (token == null || token.isEmpty) {
      throw const PesoApiException(
        statusCode: 401,
        code: 'unauthenticated',
        message: 'Sign in before viewing your document.',
      );
    }
    final base = Uri.parse(baseUrl);
    final uri = base.replace(
      path: [
        base.path.replaceFirst(RegExp(r'/$'), ''),
        'api',
        'artifacts',
        Uri.encodeComponent(artifactId),
        'content',
      ].join('/'),
    );
    try {
      final response = await _http
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/pdf, image/png, image/jpeg',
            },
          )
          .timeout(const Duration(seconds: 45));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw PesoApiException(
          statusCode: response.statusCode,
          code: 'document_preview_unavailable',
          message: response.statusCode == 404
              ? 'Document not found or no longer available in your account.'
              : _statusMessage(response.statusCode),
        );
      }
      if (response.bodyBytes.isEmpty ||
          response.bodyBytes.lengthInBytes > 20 * 1024 * 1024) {
        throw const PesoApiException(
          statusCode: 502,
          code: 'invalid_document',
          message: 'The stored document is empty or too large to preview.',
        );
      }
      return response.bodyBytes;
    } on PesoApiException {
      rethrow;
    } catch (_) {
      throw const PesoApiException(
        statusCode: 0,
        code: 'document_network_unavailable',
        message: 'Could not load the document from PESO. Check your connection and retry.',
      );
    }
  }

  static Future<Uri> createArtifactLink(String artifactId) async {
    final response = await _request(
      'POST',
      '/api/artifacts/${Uri.encodeComponent(artifactId)}/link',
    );
    final rawUrl = response['url']?.toString() ?? '';
    final uri = Uri.tryParse(rawUrl);
    if (uri == null ||
        !uri.hasAuthority ||
        !(uri.scheme == 'https' ||
            (uri.scheme == 'http' &&
                (uri.host == 'localhost' ||
                    uri.host == '127.0.0.1' ||
                    uri.host == '10.0.2.2')))) {
      throw const PesoApiException(
        statusCode: 502,
        code: 'invalid_artifact_link',
        message: 'The PESO API returned an invalid document link.',
      );
    }
    return uri;
  }

  /// Paginated, server-filtered authoritative vacancies. No AI placeholders.
  static Future<Map<String, dynamic>> listJobsPage({
    int limit = 60,
    String? pageToken,
    String? search,
    String? category,
  }) => _request(
    'GET',
    '/api/jobs',
    query: <String, String>{
      'limit': limit.clamp(1, 100).toString(),
      if (pageToken != null && pageToken.isNotEmpty) 'pageToken': pageToken,
      if (search != null && search.trim().isNotEmpty) 'q': search.trim(),
      if (category != null && category != 'all' && category.isNotEmpty)
        'category': category,
    },
    timeout: const Duration(seconds: 30),
  );

  /// Compatibility for consumers that explicitly require every active role.
  static Future<List<Map<String, dynamic>>> listJobs() async {
    final all = <Map<String, dynamic>>[];
    String? pageToken;
    do {
      final response = await listJobsPage(limit: 100, pageToken: pageToken);
      final page = response['jobs'];
      if (page is! List) throw const FormatException('Invalid jobs response');
      all.addAll(
        page.whereType<Map>().map((job) => Map<String, dynamic>.from(job)),
      );
      pageToken = response['nextPageToken']?.toString();
    } while (pageToken != null && pageToken.isNotEmpty);
    return all;
  }

  /// Recent authoritative application status notifications; owner scoped.
  static Future<List<Map<String, dynamic>>> listNotifications({
    int limit = 30,
  }) async {
    final result = await _request(
      'GET',
      '/api/notifications',
      query: <String, String>{'limit': limit.clamp(1, 50).toString()},
      timeout: const Duration(seconds: 20),
    );
    final rows = result['notifications'];
    if (rows is! List)
      throw const FormatException('Invalid notifications response');
    return rows
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  /// Lists only applications attached to the currently authenticated Firebase UID.
  static Future<Map<String, dynamic>> listMyApplications({
    int limit = 50,
    String? pageToken,
  }) => _request(
    'GET',
    '/api/applications',
    query: <String, String>{
      'limit': limit.toString(),
      if (pageToken != null && pageToken.isNotEmpty) 'pageToken': pageToken,
    },
    timeout: const Duration(seconds: 45),
  );

  static Future<Map<String, dynamic>> adminListDevelopmentNotes({
    String query = '',
    String kind = 'all',
    String status = 'active',
    int limit = 200,
  }) => _request(
    'GET',
    '/api/admin/development-notes',
    query: <String, String>{
      'limit': limit.clamp(1, 200).toString(),
      if (query.trim().isNotEmpty) 'q': query.trim(),
      if (kind != 'all') 'kind': kind,
      if (status == 'archived') 'archived': '1',
      if (status != 'active' && status != 'all' && status != 'archived')
        'status': status,
    },
    timeout: const Duration(seconds: 45),
  );

  static Future<Map<String, dynamic>> adminCreateDevelopmentNote(
    Map<String, dynamic> note,
  ) => _request('POST', '/api/admin/development-notes', body: note);

  static Future<Map<String, dynamic>> adminUpdateDevelopmentNote(
    String id,
    Map<String, dynamic> changes, {
    required int expectedRevision,
  }) => _request(
    'PATCH',
    '/api/admin/development-notes/${Uri.encodeComponent(id)}',
    body: <String, dynamic>{...changes, 'expectedRevision': expectedRevision},
  );

  static Future<Map<String, dynamic>> adminAddDevelopmentChecklistItem(
    String id,
    String text, {
    required int expectedRevision,
  }) => _request(
    'POST',
    '/api/admin/development-notes/${Uri.encodeComponent(id)}/checklist',
    body: <String, dynamic>{'text': text, 'expectedRevision': expectedRevision},
  );

  static Future<Map<String, dynamic>> adminSetDevelopmentChecklistItem(
    String id,
    String itemId, {
    required bool completed,
    required int expectedRevision,
  }) => _request(
    'PATCH',
    '/api/admin/development-notes/${Uri.encodeComponent(id)}/checklist/${Uri.encodeComponent(itemId)}',
    body: <String, dynamic>{
      'completed': completed,
      'expectedRevision': expectedRevision,
    },
  );

  static Future<Map<String, dynamic>> adminRemoveDevelopmentChecklistItem(
    String id,
    String itemId, {
    required int expectedRevision,
  }) => _request(
    'DELETE',
    '/api/admin/development-notes/${Uri.encodeComponent(id)}/checklist/${Uri.encodeComponent(itemId)}',
    body: <String, dynamic>{'expectedRevision': expectedRevision},
  );

  static Future<Map<String, dynamic>> adminCommentDevelopmentNote(
    String id,
    String message,
  ) => _request(
    'POST',
    '/api/admin/development-notes/${Uri.encodeComponent(id)}/comments',
    body: <String, dynamic>{'message': message},
  );

  static Future<Map<String, dynamic>> adminAttachDevelopmentNoteImage(
    String id, {
    required String fileName,
    required String mimeType,
    required String base64,
    required int expectedRevision,
  }) => _request(
    'POST',
    '/api/admin/development-notes/${Uri.encodeComponent(id)}/attachments',
    body: <String, dynamic>{
      'fileName': fileName,
      'mimeType': mimeType,
      'base64': base64,
      'expectedRevision': expectedRevision,
    },
    timeout: const Duration(seconds: 60),
  );

  static Future<Uint8List> adminReadDevelopmentNoteImage(
    String id,
    String attachmentId,
  ) async {
    final token = await PesoAuthSession.getBearerToken();
    if (token == null || token.isEmpty) {
      throw const PesoApiException(
        statusCode: 401,
        code: 'unauthenticated',
        message: 'Sign in as an administrator to view this image.',
      );
    }
    final base = Uri.parse(baseUrl);
    final uri = base.replace(
      path:
          base.path.replaceFirst(RegExp(r'/$'), '') +
          '/api/admin/development-notes/${Uri.encodeComponent(id)}/attachments/${Uri.encodeComponent(attachmentId)}/content',
    );
    try {
      final response = await _http
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'image/png, image/jpeg, image/webp, image/gif',
            },
          )
          .timeout(const Duration(seconds: 45));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw PesoApiException(
          statusCode: response.statusCode,
          code: 'admin_note_image_unavailable',
          message: _statusMessage(response.statusCode),
        );
      }
      if (response.bodyBytes.isEmpty ||
          response.bodyBytes.length > 5 * 1024 * 1024) {
        throw const PesoApiException(
          statusCode: 502,
          code: 'invalid_note_image',
          message: 'The stored screenshot is empty or too large.',
        );
      }
      return response.bodyBytes;
    } on PesoApiException {
      rethrow;
    } catch (_) {
      throw const PesoApiException(
        statusCode: 0,
        code: 'note_image_network_error',
        message: 'Could not retrieve the private screenshot.',
      );
    }
  }

  static Future<Map<String, dynamic>> adminRemoveDevelopmentNoteImage(
    String id,
    String attachmentId, {
    required int expectedRevision,
  }) => _request(
    'DELETE',
    '/api/admin/development-notes/${Uri.encodeComponent(id)}/attachments/${Uri.encodeComponent(attachmentId)}',
    body: <String, dynamic>{'expectedRevision': expectedRevision},
  );

  /// Refreshes the authenticated user's activity timestamp for the Admin
  /// online/offline indicator. Failures are intentionally non-blocking.
  static Future<void> sendPresenceHeartbeat() async {
    try {
      await _request(
        'POST',
        '/api/presence/heartbeat',
        timeout: const Duration(seconds: 10),
      );
    } catch (_) {
      // Presence is informational and must never interrupt the jobseeker flow.
    }
  }

  static Future<Map<String, dynamic>> adminListJobs({
    int limit = 100,
    String? pageToken,
    bool includeDeleted = false,
  }) => _request(
    'GET',
    '/api/admin/jobs',
    query: <String, String>{
      'limit': limit.clamp(1, 500).toString(),
      if (pageToken != null && pageToken.isNotEmpty) 'pageToken': pageToken,
      if (includeDeleted) 'includeDeleted': '1',
    },
    timeout: const Duration(seconds: 45),
  );

  static Future<Map<String, dynamic>> adminListApplications({
    int limit = 100,
    String? pageToken,
  }) => _request(
    'GET',
    '/api/admin/applications',
    query: <String, String>{
      'limit': limit.toString(),
      if (pageToken != null && pageToken.isNotEmpty) 'pageToken': pageToken,
    },
    timeout: const Duration(seconds: 60),
  );

  static Future<Map<String, dynamic>> adminGetLandingSiteContent() => _request(
    'GET',
    '/api/admin/site-content',
    timeout: const Duration(seconds: 30),
  );

  static Future<Map<String, dynamic>> adminSaveLandingSiteContent(
    Map<String, dynamic> content,
  ) => _request(
    'PUT',
    '/api/admin/site-content',
    body: content,
    timeout: const Duration(seconds: 30),
  );

  /// Sends the current protected Excel report to the configured PESO report email.
  /// The backend confirms success only after the SMTP service accepts the message.
  static Future<Map<String, dynamic>> adminEmailApplicantWorkbook() => _request(
    'POST',
    '/api/admin/applications/email-report',
    timeout: const Duration(seconds: 90),
  );

  /// Returns a short-lived signed URL that opens the DOLE SPRS Excel workbook in
  /// a browser tab. The workbook is rebuilt from the database on every open.
  static Future<Map<String, dynamic>> adminCreateExportLink() => _request(
    'POST',
    '/api/admin/applications/export-link',
    timeout: const Duration(seconds: 60),
  );

  static Future<Map<String, dynamic>> adminSetApplicationStatus(
    String applicationId,
    String status,
  ) => _request(
    'PATCH',
    '/api/admin/applications/${Uri.encodeComponent(applicationId)}/status',
    body: <String, dynamic>{'status': status},
    timeout: const Duration(seconds: 60),
  );

  /// Admin-scoped document metadata, resolved by the selected Firebase UID.
  static Future<Map<String, dynamic>> adminApplicantDocuments(String uid) =>
      _request('GET', '/api/admin/users/${Uri.encodeComponent(uid)}/documents');

  static Future<Map<String, dynamic>> adminApplicantDocumentStatuses(
    List<String> uids,
  ) => _request(
    'POST',
    '/api/admin/users/document-status',
    body: <String, dynamic>{'uids': uids},
  );

  static Future<Uint8List> adminReadApplicantDocument(
    String uid,
    String kind, {
    String? artifactId,
  }) async {
    if (kind != 'resume' && kind != 'nsrp') {
      throw const PesoApiException(
        statusCode: 400,
        code: 'invalid_document_type',
        message: 'Unsupported document type.',
      );
    }
    final token = await PesoAuthSession.getBearerToken();
    if (token == null || token.isEmpty) {
      throw const PesoApiException(
        statusCode: 401,
        code: 'unauthenticated',
        message: 'Sign in as an administrator to view this file.',
      );
    }
    final base = Uri.parse(baseUrl);
    final uri = base.replace(
      path:
          base.path.replaceFirst(RegExp(r'/$'), '') +
          '/api/admin/users/${Uri.encodeComponent(uid)}/documents/$kind/content',
      queryParameters: artifactId == null || artifactId.isEmpty
          ? null
          : <String, String>{'artifactId': artifactId},
    );
    try {
      final response = await _http
          .get(
            uri,
            headers: <String, String>{
              'Authorization': 'Bearer $token',
              'Accept': 'application/pdf, image/png, image/jpeg',
            },
          )
          .timeout(const Duration(seconds: 45));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw PesoApiException(
          statusCode: response.statusCode,
          code: 'admin_document_unavailable',
          message: _statusMessage(response.statusCode),
        );
      }
      if (response.bodyBytes.isEmpty ||
          response.bodyBytes.length > 20 * 1024 * 1024) {
        throw const PesoApiException(
          statusCode: 502,
          code: 'invalid_document',
          message: 'Stored file is empty or too large to preview.',
        );
      }
      return response.bodyBytes;
    } on PesoApiException {
      rethrow;
    } catch (_) {
      throw const PesoApiException(
        statusCode: 0,
        code: 'document_network_unavailable',
        message: 'Could not retrieve the private applicant document.',
      );
    }
  }

  /// Short-lived signed URL that opens a job seeker's resume in a browser tab.
  static Future<Map<String, dynamic>> adminCreateResumeLink(String uid) =>
      _request(
        'POST',
        '/api/admin/users/${Uri.encodeComponent(uid)}/resume-link',
        timeout: const Duration(seconds: 60),
      );

  static Future<Map<String, dynamic>> adminUploadJobImage({
    required String fileName,
    required String mimeType,
    required List<int> bytes,
  }) => _request(
    'POST',
    '/api/admin/job-images',
    body: <String, dynamic>{
      'fileName': fileName,
      'mimeType': mimeType,
      'base64': base64Encode(bytes),
    },
    timeout: const Duration(seconds: 60),
  );

  static Future<Map<String, dynamic>> adminCreateJob(
    Map<String, dynamic> posting,
  ) => _request(
    'POST',
    '/api/admin/jobs',
    body: posting,
    timeout: const Duration(seconds: 60),
  );

  /// Admin-curated online PDF link registry. Attachments are reviewed before
  /// any job posting is published; this is not an AI ingestion result.
  static Future<Map<String, dynamic>> adminListPdfLinks() => _request(
    'GET',
    '/api/admin/jobs/pdf-links',
    timeout: const Duration(seconds: 30),
  );

  static Future<Map<String, dynamic>> adminAddPdfLink({
    required String title,
    required String url,
    required String category,
  }) => _request(
    'POST',
    '/api/admin/jobs/pdf-links',
    body: <String, dynamic>{
      'title': title.trim(),
      'url': url.trim(),
      'category': category,
    },
    timeout: const Duration(seconds: 35),
  );

  static Future<Map<String, dynamic>> adminSetJobStatus(
    String jobId, {
    required bool active,
  }) => _request(
    'PATCH',
    '/api/admin/jobs/${Uri.encodeComponent(jobId)}/status',
    body: <String, dynamic>{'active': active},
  );

  /// Canonical deletion routes are implemented by the jobs/backend session.
  static Future<Map<String, dynamic>> adminDeleteJob(String jobId) =>
      _request('DELETE', '/api/admin/jobs/${Uri.encodeComponent(jobId)}');

  static Future<Map<String, dynamic>> adminDeleteAllJobs({
    required String confirmation,
  }) => _request(
    'DELETE',
    '/api/admin/jobs',
    body: <String, dynamic>{'confirmation': confirmation},
    timeout: const Duration(seconds: 60),
  );

  static Future<Map<String, dynamic>> adminListUsers({
    int limit = 100,
    String? pageToken,
  }) => _request(
    'GET',
    '/api/admin/users',
    query: <String, String>{
      'limit': limit.toString(),
      if (pageToken != null && pageToken.isNotEmpty) 'pageToken': pageToken,
    },
    timeout: const Duration(seconds: 60),
  );

  static Future<Map<String, dynamic>> adminUpdateProfile(
    String uid,
    Map<String, dynamic> profile,
  ) => _request(
    'PATCH',
    '/api/admin/users/${Uri.encodeComponent(uid)}/profile',
    body: profile,
  );

  static Future<Map<String, dynamic>> adminSetDisabled(
    String uid, {
    required bool disabled,
  }) => _request(
    'PATCH',
    '/api/admin/users/${Uri.encodeComponent(uid)}/status',
    body: <String, dynamic>{'disabled': disabled},
  );

  static Future<Map<String, dynamic>> adminPromoteUser(String uid) => _request(
    'PATCH',
    '/api/admin/users/${Uri.encodeComponent(uid)}/role',
    body: <String, dynamic>{'role': 'admin'},
  );

  static Future<Map<String, dynamic>> adminDeleteUser(String uid) => _request(
    'DELETE',
    '/api/admin/users/${Uri.encodeComponent(uid)}',
    timeout: const Duration(seconds: 60),
  );

  /// Deletes the currently signed-in administrator through the dedicated
  /// self-service endpoint, including retry access for its own pending deletion.
  static Future<Map<String, dynamic>> deleteMyAccount() => _request(
    'DELETE',
    '/api/account/me',
    timeout: const Duration(seconds: 60),
  );
}
