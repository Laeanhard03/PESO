import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../peso_models/profile_artifact.dart';

class ProfileArtifactSaveResult {
  const ProfileArtifactSaveResult({required this.records, required this.warnings});

  final List<Map<String, dynamic>> records;
  final List<String> warnings;
}

/// Uploads private user documents to Cloud Storage and keeps only their
/// metadata in users/{uid}/artifacts/{artifactId} in Firestore.
class ProfileArtifactService {
  ProfileArtifactService._();

  static const int maxArtifactBytes = 20 * 1024 * 1024;

  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static FirebaseStorage get _storage => FirebaseStorage.instance;

  static Future<ProfileArtifactSaveResult> saveArtifacts(
    List<ProfileArtifactInput> artifacts,
  ) async {
    if (artifacts.isEmpty) {
      return const ProfileArtifactSaveResult(records: [], warnings: []);
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Sign in before saving resume or NSRP documents.');
    }

    final records = <Map<String, dynamic>>[];
    final warnings = <String>[];
    final collection = _db.collection('users').doc(user.uid).collection('artifacts');

    for (var index = 0; index < artifacts.length; index++) {
      final artifact = artifacts[index];
      if (artifact.bytes.length > maxArtifactBytes) {
        warnings.add('${artifact.fileName} was not saved because it exceeds the 20 MB limit.');
        continue;
      }
      if (!_isAllowedMimeType(artifact.mimeType)) {
        warnings.add('${artifact.fileName} was not saved because its file type is not supported.');
        continue;
      }

      final safeName = _safeStorageName(artifact.fileName);
      final artifactId = '${DateTime.now().microsecondsSinceEpoch}_${index}_$safeName';
      final storagePath = 'users/${user.uid}/artifacts/$artifactId';
      Reference? storageRef;
      var uploaded = false;

      try {
        storageRef = _storage.ref(storagePath);
        await storageRef.putData(
          artifact.bytes,
          SettableMetadata(
            contentType: artifact.mimeType,
            customMetadata: {
              'ownerUid': user.uid,
              'category': artifact.category,
              'originalFileName': artifact.fileName,
            },
          ),
        );
        uploaded = true;

        final record = <String, dynamic>{
          'id': artifactId,
          'category': artifact.category,
          'fileName': artifact.fileName,
          'mimeType': artifact.mimeType,
          'sizeBytes': artifact.bytes.length,
          'storagePath': storagePath,
          'uploadedAt': FieldValue.serverTimestamp(),
        };
        await collection.doc(artifactId).set(record);
        records.add({
          ...record,
          'uploadedAt': DateTime.now(),
        });
      } catch (error) {
        // Avoid orphaned Storage objects if writing the metadata fails.
        if (uploaded && storageRef != null) {
          try {
            await storageRef.delete();
          } catch (_) {
            // Preserve the original error as the actionable warning.
          }
        }
        warnings.add('Could not save ${artifact.fileName}: ${_friendlyStorageError(error)}');
        debugPrint('[ARTIFACT] ${artifact.fileName} upload failed: $error');
      }
    }

    return ProfileArtifactSaveResult(records: records, warnings: warnings);
  }

  static Future<List<Map<String, dynamic>>> getCurrentUserArtifacts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return <Map<String, dynamic>>[];

    final snapshot = await _db
        .collection('users')
        .doc(user.uid)
        .collection('artifacts')
        .get();

    final records = snapshot.docs.map((doc) => <String, dynamic>{
      'id': doc.id,
      ...doc.data(),
    }).toList();
    records.sort((a, b) => _timestampMillis(b['uploadedAt']).compareTo(_timestampMillis(a['uploadedAt'])));
    return records;
  }

  /// Obtains a Storage URL only when the signed-in owner chooses to open a file.
  /// URLs are deliberately not persisted in Firestore because they are bearer links.
  static Future<void> openArtifact(Map<String, dynamic> artifact) async {
    final storagePath = artifact['storagePath']?.toString() ?? '';
    if (storagePath.isEmpty) throw StateError('This document has no Storage path.');

    final url = await _storage.ref(storagePath).getDownloadURL();
    final launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.platformDefault,
      webOnlyWindowName: '_blank',
    );
    if (!launched) throw StateError('Your browser could not open the document.');
  }

  static bool _isAllowedMimeType(String mimeType) => const {
        'application/pdf',
        'image/jpeg',
        'image/png',
      }.contains(mimeType.toLowerCase());

  static String _safeStorageName(String value) {
    final base = value.split(RegExp(r'[/\\]')).last.trim();
    final safe = base.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return safe.isEmpty ? 'document.pdf' : safe.substring(0, safe.length > 100 ? 100 : safe.length);
  }

  static int _timestampMillis(Object? value) {
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    if (value is DateTime) return value.millisecondsSinceEpoch;
    return 0;
  }

  static String _friendlyStorageError(Object error) {
    if (error is FirebaseException) {
      if (error.code == 'unauthorized' || error.code == 'permission-denied') {
        return 'Storage denied the upload. Check the deployed storage.rules.';
      }
      if (error.code == 'no-default-bucket') {
        return 'No Storage bucket is configured. Create a Firebase Storage bucket and rerun flutterfire configure.';
      }
      if (error.code == 'bucket-not-found' || error.code == 'object-not-found') {
        return 'The Firebase Storage bucket is not ready.';
      }
      if (error.code == 'unknown' && (error.message ?? '').toLowerCase().contains('billing')) {
        return 'Firebase Cloud Storage may require the Blaze billing plan for this project.';
      }
      return error.message ?? error.code;
    }
    final message = error.toString();
    if (message.toLowerCase().contains('billing')) {
      return 'Firebase Cloud Storage requires billing to be enabled for this project.';
    }
    return message;
  }
}
