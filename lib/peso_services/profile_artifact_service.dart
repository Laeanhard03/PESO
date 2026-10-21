import 'peso_auth_session.dart';

import 'package:flutter/foundation.dart';

import 'document_popup.dart';

import '../peso_models/profile_artifact.dart';
import 'peso_api_client.dart';

class ProfileArtifactSaveResult {
  const ProfileArtifactSaveResult({
    required this.records,
    required this.warnings,
  });

  final List<Map<String, dynamic>> records;
  final List<String> warnings;
}

/// Saves private resume/NSRP artifacts through the authenticated PESO API.
/// The API verifies the active Firebase or PESO SMS session and stores bytes in MongoDB GridFS.
class ProfileArtifactService {
  ProfileArtifactService._();

  static const int maxArtifactBytes = 20 * 1024 * 1024;

  static Future<ProfileArtifactSaveResult> saveArtifacts(
    List<ProfileArtifactInput> artifacts,
  ) async {
    if (artifacts.isEmpty) {
      return const ProfileArtifactSaveResult(records: [], warnings: []);
    }

    if (!await PesoAuthSession.hasAuthenticatedSession()) {
      throw StateError('Sign in before saving resume or NSRP documents.');
    }

    final records = <Map<String, dynamic>>[];
    final warnings = <String>[];

    for (final artifact in artifacts) {
      if (artifact.bytes.length > maxArtifactBytes) {
        warnings.add(
          '${artifact.fileName} was not saved because it exceeds the 20 MB limit.',
        );
        continue;
      }
      if (!_isAllowedMimeType(artifact.mimeType)) {
        warnings.add(
          '${artifact.fileName} was not saved because its file type is not supported.',
        );
        continue;
      }

      try {
        final record = await PesoApiClient.uploadArtifact(
          fileName: _safeFileName(artifact.fileName),
          category: artifact.category,
          mimeType: artifact.mimeType,
          bytes: artifact.bytes,
        );
        records.add(record);
      } catch (error) {
        warnings.add(
          'Could not save ${artifact.fileName}: ${_friendlyApiError(error)}',
        );
        // Avoid logging document data or any server-provided payload.
        debugPrint('[ARTIFACT] Upload failed (${error.runtimeType}).');
      }
    }

    return ProfileArtifactSaveResult(records: records, warnings: warnings);
  }

  static Future<List<Map<String, dynamic>>> getCurrentUserArtifacts() async {
    if (!await PesoAuthSession.hasAuthenticatedSession()) {
      return <Map<String, dynamic>>[];
    }

    final records = await PesoApiClient.listArtifacts();
    records.sort(
      (a, b) =>
          _timestampMillis(b['uploadedAt'])
              .compareTo(_timestampMillis(a['uploadedAt'])),
    );
    return records;
  }

  /// Requests an owner-checked, short-lived API download link when opening a file.
  /// The signed URL is never persisted in the profile record.
  static Future<void> openArtifact(Map<String, dynamic> artifact) async {
    final artifactId = artifact['id']?.toString() ?? '';
    if (artifactId.isEmpty) {
      throw StateError('This document has no artifact ID.');
    }

    // Reserve the browser tab inside the original click event. Waiting for
    // an async signed-link request before opening a tab triggers popup blockers.
    final popup = DocumentPopup.open();
    try {
      final uri = await PesoApiClient.createArtifactLink(artifactId);
      final launched = popup != null
          ? await popup.navigate(uri)
          : await DocumentPopupFallback().navigate(uri);
      if (!launched)
        throw StateError('Your browser could not open the document.');
    } catch (_) {
      popup?.close();
      rethrow;
    }
  }

  static bool _isAllowedMimeType(String mimeType) => const {
    'application/pdf',
    'image/jpeg',
    'image/png',
  }.contains(mimeType.toLowerCase());

  static String _safeFileName(String value) {
    final base = value.split(RegExp(r'[/\\]')).last.trim();
    final safe = base.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return safe.isEmpty
        ? 'document.pdf'
        : safe.substring(0, safe.length > 100 ? 100 : safe.length);
  }

  static int _timestampMillis(Object? value) {
    if (value is DateTime) return value.millisecondsSinceEpoch;
    if (value is num) return value.toInt();
    if (value is String) {
      return DateTime.tryParse(value)?.millisecondsSinceEpoch ?? 0;
    }
    return 0;
  }

  static String _friendlyApiError(Object error) {
    if (error is PesoApiException) {
      if (error.statusCode == 401)
        return 'Your sign-in session expired. Sign in again.';
      if (error.code == 'unsupported_file_type')
        return 'That document type is not supported.';
      if (error.statusCode == 503)
        return 'The document service is not configured yet.';
      if (error.statusCode == 0)
        return 'The PESO data API is unavailable. Check your connection and try again.';
      return error.message;
    }
    return 'The document could not be saved. Check your connection and try again.';
  }
}
