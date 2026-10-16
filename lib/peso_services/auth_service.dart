import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'firebase_setup.dart';

/// Authentication and user-document persistence for JobKonek.
/// Each authenticated user owns `users/{uid}` in Cloud Firestore.
class AuthService {
  AuthService._();

  static FirebaseAuth get _auth {
    _requireFirebase();
    return FirebaseAuth.instance;
  }

  static FirebaseFirestore get _db {
    _requireFirebase();
    return FirebaseFirestore.instance;
  }

  static ConfirmationResult? _webConfirmationResult;
  static String? _nativeVerificationId;
  static String? _pendingPhoneNumber;

  static void _requireFirebase() {
    if (Firebase.apps.isEmpty ||
        !FirebaseSetup.isConfigured) {
      throw StateError(
        'Firebase is not configured yet. From the project root, run '
        '`flutterfire configure`, then enable Email/Password, Google, and Phone '
        'sign-in in Firebase Authentication.',
      );
    }
  }

  static CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  static DocumentReference<Map<String, dynamic>> _userDocument(String uid) =>
      _users.doc(uid);

  static Future<UserCredential> registerWithEmail({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? phoneNumber,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) throw StateError('Firebase did not return a user.');

    final fullName = '${firstName.trim()} ${lastName.trim()}'.trim();
    await user.updateDisplayName(fullName);
    await ensureUserProfile(
      user,
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      phoneNumber: phoneNumber?.trim(),
    );

    // Verification is sent for account ownership, but is not required to use
    // the prototype yet. The UI can show the user that verification is pending.
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException {
      // Do not treat a verification-email delivery issue as failed registration.
    }
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
    final user = credential.user;
    if (user != null) await ensureUserProfile(user);
    return credential;
  }

  static Future<UserCredential> signInWithGoogle() async {
    final provider = GoogleAuthProvider()
      ..addScope('email')
      ..setCustomParameters({'prompt': 'select_account'});

    final credential = kIsWeb
        ? await _auth.signInWithPopup(provider)
        : await _auth.signInWithProvider(provider);

    final user = credential.user;
    if (user != null) await ensureUserProfile(user);
    return credential;
  }

  /// Starts an SMS sign-in. For web, Firebase handles the reCAPTCHA widget;
  /// Android/iOS use Firebase's native phone verification callbacks.
  static Future<void> sendPhoneCode(String phoneNumber) async {
    _requireFirebase();
    final phone = normalizePhoneNumber(phoneNumber);
    if (phone.isEmpty || !phone.startsWith('+')) {
      throw ArgumentError('Enter a phone number with a country code, e.g. +639171234567.');
    }
    _pendingPhoneNumber = phone;

    if (kIsWeb) {
      _webConfirmationResult = await _auth.signInWithPhoneNumber(phone);
      return;
    }

    final completer = Completer<void>();
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await _auth.signInWithCredential(credential);
            if (!completer.isCompleted) completer.complete();
          } catch (error, stackTrace) {
            if (!completer.isCompleted) {
              completer.completeError(error, stackTrace);
            }
          }
        },
        verificationFailed: (FirebaseAuthException error) {
          if (!completer.isCompleted) completer.completeError(error);
        },
        codeSent: (String verificationId, int? resendToken) {
          _nativeVerificationId = verificationId;
          if (!completer.isCompleted) completer.complete();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _nativeVerificationId = verificationId;
          if (!completer.isCompleted) completer.complete();
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (error, stackTrace) {
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
    }
    await completer.future.timeout(const Duration(seconds: 65));
  }

  static Future<User> confirmPhoneCode(String smsCode) async {
    _requireFirebase();
    User? user;

    // Android may complete phone verification automatically before the user
    // needs to type the SMS code.
    final current = _auth.currentUser;
    if (!kIsWeb &&
        current != null &&
        current.phoneNumber == _pendingPhoneNumber) {
      user = current;
    } else if (kIsWeb) {
      final confirmation = _webConfirmationResult;
      if (confirmation == null) {
        throw StateError('Request a new SMS code before confirming it.');
      }
      user = (await confirmation.confirm(smsCode.trim())).user;
    } else {
      final verificationId = _nativeVerificationId;
      if (verificationId == null) {
        throw StateError('Request a new SMS code before confirming it.');
      }
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode.trim(),
      );
      user = (await _auth.signInWithCredential(credential)).user;
    }

    if (user == null) throw StateError('Phone sign-in did not return a user.');
    await ensureUserProfile(user, phoneNumber: _pendingPhoneNumber);
    _webConfirmationResult = null;
    _nativeVerificationId = null;
    _pendingPhoneNumber = null;
    return user;
  }

  static Future<void> sendPasswordReset(String email) async {
    if (email.trim().isEmpty) throw ArgumentError('Enter your email address first.');
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  static Future<void> signOut() async {
    await _auth.signOut();
    _webConfirmationResult = null;
    _nativeVerificationId = null;
    _pendingPhoneNumber = null;
  }

  static Future<Map<String, dynamic>> ensureUserProfile(
    User user, {
    String? firstName,
    String? lastName,
    String? phoneNumber,
  }) async {
    final ref = _userDocument(user.uid);
    final snapshot = await ref.get();
    final existing = snapshot.data() ?? <String, dynamic>{};
    final resolvedName = _nonEmpty(
      '${firstName ?? ''} ${lastName ?? ''}'.trim(),
      user.displayName,
      existing['displayName'] as String?,
      user.email?.split('@').first,
      'PESO User',
    );
    final nameParts = resolvedName.split(RegExp(r'\s+'));
    final resolvedFirstName = _nonEmpty(
      firstName,
      existing['firstName'] as String?,
      nameParts.first,
    );
    final resolvedLastName = _nonEmpty(
      lastName,
      existing['lastName'] as String?,
      nameParts.length > 1 ? nameParts.skip(1).join(' ') : '',
    );

    final base = <String, dynamic>{
      'uid': user.uid,
      'email': user.email ?? existing['email'] ?? '',
      'photoURL': user.photoURL ?? existing['photoURL'] ?? '',
      'providerIds': user.providerData.map((item) => item.providerId).toList(),
      'emailVerified': user.emailVerified,
      'phoneVerified': user.phoneNumber != null || existing['phoneVerified'] == true,
      'lastLoginAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!snapshot.exists) {
      await ref.set({
        ...base,
        'role': 'job_seeker',
        'firstName': resolvedFirstName,
        'lastName': resolvedLastName,
        'displayName': resolvedName,
        'phoneNumber': user.phoneNumber ?? phoneNumber ?? '',
        'location': '',
        'educationLevel': '',
        'employmentStatus': 'Looking for work',
        'professionalTitle': '',
        'bio': '',
        'skills': <String>[],
        'aiProfile': <String, dynamic>{},
        'resumeData': <String, dynamic>{},
        'pesoFormData': <String, dynamic>{},
        'onboardingText': '',
        'assessmentOutcomes': <Map<String, dynamic>>[],
        'preferences': <String, dynamic>{
          'language': 'English',
          'emailNotifications': true,
          'appNotifications': true,
        },
        'profileCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      // Merge metadata only; never overwrite role or existing user-editable data.
      await ref.set({
        ...base,
        if ((existing['firstName'] as String? ?? '').trim().isEmpty)
          'firstName': resolvedFirstName,
        if ((existing['lastName'] as String? ?? '').trim().isEmpty)
          'lastName': resolvedLastName,
        if ((existing['displayName'] as String? ?? '').trim().isEmpty)
          'displayName': resolvedName,
        if ((existing['phoneNumber'] as String? ?? '').trim().isEmpty &&
            (user.phoneNumber ?? phoneNumber ?? '').isNotEmpty)
          'phoneNumber': user.phoneNumber ?? phoneNumber,
      }, SetOptions(merge: true));
    }

    final fresh = await ref.get();
    return fresh.data() ?? <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> getUserProfile(String uid) async {
    final snapshot = await _userDocument(uid).get();
    return snapshot.data() ?? <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> getCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return <String, dynamic>{};
    return ensureUserProfile(user);
  }

  static Future<String> getCurrentUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return 'guest';
    final profile = await getUserProfile(user.uid);
    return (profile['role'] as String?) ?? 'job_seeker';
  }

  static Future<void> saveAccountProfile(Map<String, dynamic> updates) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('You must sign in before editing a profile.');

    final firstName = (updates['firstName'] as String? ?? '').trim();
    final lastName = (updates['lastName'] as String? ?? '').trim();
    if (firstName.isEmpty || lastName.isEmpty) {
      throw ArgumentError('First name and last name are required.');
    }
    final displayName = '$firstName $lastName'.trim();
    final allowed = <String, dynamic>{
      'firstName': firstName,
      'lastName': lastName,
      'displayName': displayName,
      'phoneNumber': (updates['phoneNumber'] as String? ?? '').trim(),
      // A manually edited number is not verified. Keep the green verified
      // state only when it matches the phone number verified by Firebase Auth.
      'phoneVerified': user.phoneNumber != null &&
          user.phoneNumber == (updates['phoneNumber'] as String? ?? '').trim(),
      'location': (updates['location'] as String? ?? '').trim(),
      'educationLevel': (updates['educationLevel'] as String? ?? '').trim(),
      'employmentStatus': (updates['employmentStatus'] as String? ?? '').trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await _userDocument(user.uid).set(allowed, SetOptions(merge: true));
    await user.updateDisplayName(displayName);
  }

  /// Persists the structured source data collected by React before AI
  /// extraction. Raw form fields remain private under this user's own document.
  static Future<void> saveOnboardingData({
    Map<String, dynamic>? resumeData,
    Map<String, dynamic>? pesoFormData,
    String? onboardingText,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Sign in before saving resume and NSRP form data.');
    }
    await ensureUserProfile(user);
    await _userDocument(user.uid).set({
      if (resumeData != null) 'resumeData': resumeData,
      if (pesoFormData != null) 'pesoFormData': pesoFormData,
      if (onboardingText != null) 'onboardingText': onboardingText,
      'onboardingCompletedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> saveAiProfile(Map<String, dynamic> aiProfile) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sign in before saving an AI profile.');
    await ensureUserProfile(user);

    final skillsValue = aiProfile['skills'];
    final skills = skillsValue is List
        ? skillsValue.map((item) => item.toString()).where((item) => item.trim().isNotEmpty).toList()
        : <String>[];
    await _userDocument(user.uid).set({
      'aiProfile': aiProfile,
      'professionalTitle': aiProfile['professionalTitle']?.toString() ?? '',
      'skills': skills,
      'profileCompleted': true,
      'aiProfileUpdatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> savePreferences(Map<String, dynamic> preferences) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _userDocument(user.uid).set({
      'preferences': preferences,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> saveAssessmentOutcomes(
    List<Map<String, dynamic>> outcomes,
  ) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _userDocument(user.uid).set({
      'assessmentOutcomes': outcomes,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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

  static String _nonEmpty(String? a, [String? b, String? c, String? d, String? e]) {
    for (final value in <String?>[a, b, c, d, e]) {
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }
}
