import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../peso_services/peso_api_client.dart';
import '../User/profile_document_dialog.dart';

/// Admin-only entry point into the same PDF preview used by AI Profile.
/// The metadata endpoint is owned by the residency/backend integration.
class AdminApplicantDocumentViewer {
  static const _resumeCategories = <String>{
    'resume_upload', 'resume_builder', 'resume_pdf', 'resume', 'legacy_resume',
  };
  static const _nsrpCategories = <String>{
    'nsrp_form', 'nsrp_pdf', 'nsrp', 'peso_form',
    'employment_form', 'legacy_nsrp_form',
  };

  /// Pure resolution helper: never trust a row label or email to locate a file.
  /// The backend always returns metadata already scoped to a single UID.
  static Map<String, dynamic>? findArtifact(
    Map<String, dynamic> response, {
    required String uid,
    required String kind,
  }) {
    if (response['uid']?.toString() != uid) return null;
    final artifacts = response['artifacts'];
    if (artifacts is! List) return null;
    final accepted = kind == 'resume' ? _resumeCategories : _nsrpCategories;
    for (final raw in artifacts) {
      if (raw is! Map) continue;
      final artifact = Map<String, dynamic>.from(raw);
      final id = artifact['id']?.toString().trim() ?? '';
      final category = artifact['category']?.toString().toLowerCase() ?? '';
      if (id.isNotEmpty && accepted.contains(category)) return artifact;
    }
    return null;
  }

  static void _notice(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  static Future<void> _openStructuredResume(
    BuildContext context, String uid, String name,
  ) async {
    final response = await PesoApiClient.adminCreateResumeLink(uid);
    final raw = response['url']?.toString() ?? '';
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasAuthority ||
        !(uri.scheme == 'https' || (uri.scheme == 'http' &&
          (uri.host == 'localhost' || uri.host == '127.0.0.1')))) {
      throw const PesoApiException(
        statusCode: 502,
        code: 'invalid_admin_document_link',
        message: 'The saved resume link is unavailable.',
      );
    }
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Saved resume (structured entries)'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Text(
            '$name has resume entries saved without an uploaded PDF. '
            'You can open the existing secure resume preview in a new tab '
            'and print or save it using your browser. This link expires.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () async {
              final launched = await launchUrl(
                uri,
                mode: LaunchMode.platformDefault,
                webOnlyWindowName: '_blank',
              );
              if (launched && dialogContext.mounted) Navigator.pop(dialogContext);
              if (!launched && context.mounted) {
                _notice(context, 'Could not open the private resume tab. Check popup settings.');
              }
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open saved resume'),
          ),
        ],
      ),
    );
  }

  static Future<void> open(
    BuildContext context, {
    required String uid,
    required String applicantName,
    required String kind,
  }) async {
    if (uid.trim().isEmpty || !{'resume', 'nsrp'}.contains(kind)) return;
    final label = kind == 'resume' ? 'resume' : 'NSRP Form 1';
    try {
      final response = await PesoApiClient.adminApplicantDocuments(uid);
      if (!context.mounted) return;
      final artifact = findArtifact(response, uid: uid, kind: kind);
      if (artifact != null) {
        final artifactId = artifact['id'].toString();
        await showDialog<void>(
          context: context,
          builder: (_) => ProfileDocumentDialog(
            artifact: artifact,
            fetchBytes: (_) => PesoApiClient.adminReadApplicantDocument(
              uid, kind, artifactId: artifactId,
            ),
          ),
        );
        return;
      }
      if (kind == 'resume' && response['resumeSubmitted'] == true) {
        await _openStructuredResume(context, uid, applicantName);
        return;
      }
      if (kind == 'nsrp' && response['formSubmitted'] == true) {
        _notice(context, '$applicantName has saved NSRP entries but no generated '
            'Form 1 PDF yet. The applicant can regenerate Form 1 from their account.');
        return;
      }
      _notice(context, '$applicantName has not submitted a viewable $label yet.');
    } on PesoApiException catch (error) {
      _notice(context, 'Unable to view $label: ' + error.message);
    } catch (_) {
      _notice(context, 'Unable to view the selected applicant\'s $label. Please retry.');
    }
  }
}
