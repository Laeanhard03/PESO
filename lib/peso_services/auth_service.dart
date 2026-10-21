import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;

import 'firebase_setup.dart';
import 'peso_api_client.dart';
import 'peso_auth_session.dart';
import 'peso_role_policy.dart';

/// Firebase Authentication adapter plus MongoDB-backed profile persistence.
/// Profile records are accessed through the authenticated PESO API.
class AuthService {
  AuthService._();

  static FirebaseAuth get _auth {
    _requireFirebase();
    return FirebaseAuth.instance;
  }

  static void _requireFirebase() {
    if (Firebase.apps.isEmpty || !FirebaseSetup.isConfigured) {
      throw StateError(
        'Firebase is not configured yet. From the project root, run '
        '`flutterfire configure`, then enable Email/Password, Google, and Phone '
        'sign-in in Firebase Authentication.',
      );
    }
  }

  static Future<UserCredential> registerWithEmail({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) throw StateError('Firebase did not return a user.');

    final fullName = '${firstName.trim()} ${lastName.trim()}'.trim();
    await user.updateDisplayName(fullName);
    return credential;
  }

  static Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return credential;
  }

  static Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No signed-in user to verify.');
    await user.sendEmailVerification();
  }

  static Future<bool> reloadCurrentUserVerification() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No signed-in user to verify.');
    await user.reload();
    final refreshedUser = _auth.currentUser;
    if (refreshedUser?.emailVerified != true) return false;
    // Reload updates Firebase's user object but can leave a cached ID token
    // whose email_verified claim is still false. The PESO API correctly
    // rejects that stale token with HTTP 403. Force-refresh the token before
    // onboarding, profile storage, or any other authenticated API request.
    await refreshedUser!.getIdToken(true);
    return true;
  }

  static Future<UserCredential> signInWithGoogle() async {
    final provider = GoogleAuthProvider()
      ..addScope('email')
      ..setCustomParameters({'prompt': 'select_account'});

    final credential = kIsWeb
        ? await _auth.signInWithPopup(provider)
        : await _auth.signInWithProvider(provider);

    return credential;
  }

  static Future<void> sendPasswordReset(String email) async {
    if (email.trim().isEmpty)
      throw ArgumentError('Enter your email address first.');
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  static Future<void> signOut() async {
    if (Firebase.apps.isNotEmpty && FirebaseSetup.isConfigured) {
      await FirebaseAuth.instance.signOut();
    }
  }

  static Future<Map<String, dynamic>> ensureUserProfile(
    User user, {
    String? firstName,
    String? lastName,
    String? phoneNumber,
  }) async {
    final requestedName = ((firstName ?? '') + ' ' + (lastName ?? '')).trim();
    final resolvedName = _nonEmpty(
      requestedName,
      user.displayName,
      user.email?.split('@').first,
      'PESO User',
    );
    final nameParts = resolvedName.split(RegExp(r'\s+'));
    final resolvedFirstName = _nonEmpty(firstName, nameParts.first);
    final resolvedLastName = _nonEmpty(
      lastName,
      nameParts.length > 1 ? nameParts.skip(1).join(' ') : '',
    );

    try {
      final response = await PesoApiClient.ensureProfile(
        body: <String, dynamic>{
          'firstName': resolvedFirstName,
          'lastName': resolvedLastName,
          'displayName': resolvedName,
          'phoneNumber': user.phoneNumber ?? phoneNumber ?? '',
        },
      );
      final profile = response['profile'];
      return profile is Map
          ? Map<String, dynamic>.from(profile)
          : <String, dynamic>{
              'uid': user.uid,
              'role': 'job_seeker',
              'displayName': resolvedName,
              'firstName': resolvedFirstName,
              'lastName': resolvedLastName,
            };
    } catch (error) {
      // Firebase has already created/authenticated the identity. An unavailable
      // profile API should not report a false sign-in/registration failure.
      debugPrint(
        '[AUTH] MongoDB profile bootstrap unavailable (' +
            error.runtimeType.toString() +
            '); deferring profile synchronization.',
      );
      return <String, dynamic>{
        'uid': user.uid,
        'email': user.email ?? '',
        'role': 'job_seeker',
        'displayName': resolvedName,
        'firstName': resolvedFirstName,
        'lastName': resolvedLastName,
        'phoneNumber': user.phoneNumber ?? phoneNumber ?? '',
      };
    }
  }

  /// Profiles are owner-scoped by the API. Arbitrary UIDs cannot be used to
  /// read another user's private profile from the client.
  static Future<Map<String, dynamic>> getUserProfile(String uid) async {
    final currentUid = await PesoAuthSession.currentUid();
    if (currentUid == null) return <String, dynamic>{};
    if (uid != currentUid) {
      throw StateError('You can only read your own PESO profile.');
    }
    final response = await PesoApiClient.getProfile();
    final profile = response['profile'];
    return profile is Map
        ? Map<String, dynamic>.from(profile)
        : <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> getCurrentUserProfile() async {
    if (!await PesoAuthSession.hasAuthenticatedSession()) {
      return <String, dynamic>{};
    }
    final response = await PesoApiClient.getProfile();
    final profile = response['profile'];
    return profile is Map
        ? Map<String, dynamic>.from(profile)
        : <String, dynamic>{};
  }

  /// Resolve PESO application roles from the authenticated API profile.
  /// Firebase authenticates identity; MongoDB-backed API authorization decides
  /// the application role. If the API cannot be reached, fail closed.
  static Future<String> getCurrentUserRole() async {
    final uid = await PesoAuthSession.currentUid();
    if (uid == null) return 'guest';

    try {
      final profile = await getUserProfile(uid);
      return normalizePesoRole(profile['role']);
    } catch (error) {
      debugPrint(
        '[AUTH] MongoDB profile-role lookup unavailable (' +
            error.runtimeType.toString() +
            '); using job_seeker.',
      );
      return 'job_seeker';
    }
  }

  static Future<void> saveAccountProfile(Map<String, dynamic> updates) async {
    final uid = await PesoAuthSession.currentUid();
    if (uid == null) {
      throw StateError('You must sign in before editing a profile.');
    }

    final firstName = (updates['firstName'] as String? ?? '').trim();
    final lastName = (updates['lastName'] as String? ?? '').trim();
    if (firstName.isEmpty || lastName.isEmpty) {
      throw ArgumentError('First name and last name are required.');
    }
    final displayName = (firstName + ' ' + lastName).trim();
    final allowed = <String, dynamic>{
      'firstName': firstName,
      'lastName': lastName,
      'displayName': displayName,
      'phoneNumber': (updates['phoneNumber'] as String? ?? '').trim(),
      'location': (updates['location'] as String? ?? '').trim(),
      'educationLevel': (updates['educationLevel'] as String? ?? '').trim(),
      'employmentStatus': (updates['employmentStatus'] as String? ?? '').trim(),
      if (updates['professionalTitle'] is String)
        'professionalTitle': (updates['professionalTitle'] as String).trim(),
      if (updates['bio'] is String) 'bio': (updates['bio'] as String).trim(),
    };
    await PesoApiClient.updateProfile(allowed);
    final firebaseUser = Firebase.apps.isNotEmpty && FirebaseSetup.isConfigured
        ? FirebaseAuth.instance.currentUser
        : null;
    if (firebaseUser != null && firebaseUser.uid == uid) {
      await firebaseUser.updateDisplayName(displayName);
    }
  }

  /// Save the structured resume and NSRP input through the MongoDB API.
  static Future<void> saveOnboardingData({
    Map<String, dynamic>? resumeData,
    Map<String, dynamic>? pesoFormData,
    String? onboardingText,
  }) async {
    if (!await PesoAuthSession.hasAuthenticatedSession()) {
      throw StateError('Sign in before saving resume and NSRP form data.');
    }
    await PesoApiClient.saveOnboarding(<String, dynamic>{
      if (resumeData != null) 'resumeData': resumeData,
      if (pesoFormData != null) 'pesoFormData': pesoFormData,
      if (onboardingText != null) 'onboardingText': onboardingText,
    });
  }

  static Future<void> saveAiProfile(Map<String, dynamic> aiProfile) async {
    if (!await PesoAuthSession.hasAuthenticatedSession()) {
      throw StateError('Sign in before saving an AI profile.');
    }
    await PesoApiClient.saveAiProfile(aiProfile);
  }

  static Future<void> savePreferences(Map<String, dynamic> preferences) async {
    if (!await PesoAuthSession.hasAuthenticatedSession()) return;
    await PesoApiClient.savePreferences(preferences);
  }

  static Future<void> saveAssessmentOutcomes(
    List<Map<String, dynamic>> outcomes,
  ) async {
    if (!await PesoAuthSession.hasAuthenticatedSession()) return;
    await PesoApiClient.saveOutcomes(outcomes);
  }

  static String normalizePhoneNumber(String raw) {
    var value = raw.trim().replaceAll(RegExp(r'[\s().-]'), '');
    if (value.isEmpty) return '';
    if (value.startsWith('00')) value = '+${value.substring(2)}';
    if (value.startsWith('+')) return value;
    if (value.startsWith('0')) return '+63${value.substring(1)}';
    if (value.startsWith('63')) return '+$value';
    // This prototype defaults to the Philippines for unprefixed numbers.
    return '+63$value';
  }

  static String _nonEmpty(
    String? a, [
    String? b,
    String? c,
    String? d,
    String? e,
  ]) {
    for (final value in <String?>[a, b, c, d, e]) {
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }
}
