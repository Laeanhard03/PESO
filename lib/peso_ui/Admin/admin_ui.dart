import 'admin_excel_live_preview.dart';
import 'admin_pdf_link_ingestion.dart';

import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Landingpage/landingpage_ui.dart';
import '../../peso_services/peso_api_client.dart';
import 'admin_user_management_section.dart';
import 'admin_applicant_document_viewer.dart';
import 'job_applications_section.dart';
import 'job_management_section.dart';
import 'gemini_api_key_management_section.dart';
import '../../peso_services/app_toast.dart';

// =====================================================================
// THEME (matched to the React design: slate-950 sidebar, blue-600 accent,
// emerald/rose/amber status colors)
// =====================================================================
class _C {
  static const sidebar = Color(0xFF102C24); // slate-950
  static const primary = Color(0xFF236349); // blue-600
  static const indigo = Color(0xFF4F46E5);
  static const emerald = Color(0xFF10B981);
  static const emerald600 = Color(0xFF059669);
  static const rose = Color(0xFFF43F5E);
  static const rose600 = Color(0xFFE11D48);
  static const amber = Color(0xFFF59E0B);
  static const amber600 = Color(0xFFD97706);
  static const purple = Color(0xFF9333EA);
  static const bg = Color(0xFFF5F7F5); // slate-100
  static const slate100 = Color(0xFFF5F7F5);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate600 = Color(0xFF475569);
  static const slate700 = Color(0xFF334155);
  static const slate900 = Color(0xFF193D31);
}

// =====================================================================
// STATUS STYLES
// =====================================================================
class StatusStyle {
  final String label;
  final Color text;
  final Color bg;
  final Color dot;
  const StatusStyle(this.label, this.text, this.bg, this.dot);
}

// Job-matching status (replaces the old AI-exam / assessment status).
const Map<String, StatusStyle> kMatchStyles = {
  'matched': StatusStyle(
    'Matched to a Job',
    Color(0xFF047857),
    Color(0xFFECFDF5),
    Color(0xFF10B981),
  ),
  'not_matched': StatusStyle(
    'Users with Low Qualification',
    Color(0xFFBE123C),
    Color(0xFFFFF1F2),
    Color(0xFFF43F5E),
  ),
  'pending': StatusStyle(
    'Resume Under Review',
    Color(0xFFB45309),
    Color(0xFFFFFBEB),
    Color(0xFFF59E0B),
  ),
};

// =====================================================================
// MODELS
// =====================================================================
class Applicant {
  final String uid;
  final int id;
  final String name;
  final String barangay;
  final String targetJob;
  final DateTime registeredDate;
  final int yearsExperience;
  final bool resumeSubmitted;
  final bool formSubmitted;
  final String matchStatus; // pending | matched | not_matched
  final int matchedJobsCount;
  final String resumeFileName;

  Applicant({
    required this.uid,
    required this.id,
    required this.name,
    required this.barangay,
    required this.targetJob,
    required this.registeredDate,
    required this.yearsExperience,
    required this.resumeSubmitted,
    required this.formSubmitted,
    required this.matchStatus,
    required this.matchedJobsCount,
    required this.resumeFileName,
  });
}

class Concern {
  final int id;
  final String applicantName;
  final String barangay;
  final String targetJob;
  final String message;
  final DateTime submittedDate;
  bool resolved;

  Concern({
    required this.id,
    required this.applicantName,
    required this.barangay,
    required this.targetJob,
    required this.message,
    required this.submittedDate,
    this.resolved = false,
  });
}

String _fmtDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

bool _isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

// =====================================================================
// NAVIGATION
// =====================================================================
enum AdminTab {
  analytics,
  users,
  concerns,
  jobs,
  applications,
  ingestion,
  export,
  geminiKeys,
  platform,
}

class _NavItem {
  final AdminTab tab;
  final String label;
  final IconData icon;
  final String title;
  final String description;
  const _NavItem(this.tab, this.label, this.icon, this.title, this.description);
}

const List<_NavItem> kNavItems = [
  _NavItem(
    AdminTab.analytics,
    'Applicant Analytics',
    Icons.insights_outlined,
    'Applicant Analytics',
    'Job seeker registrations and resume-based job matching outcomes across Montalban barangays.',
  ),
  _NavItem(
    AdminTab.users,
    'User Management',
    Icons.manage_accounts_outlined,
    'Job Seeker Accounts',
    "Review Firebase Authentication accounts with profile fields stored in MongoDB through the trusted PESO API.",
  ),
  _NavItem(
    AdminTab.concerns,
    'Concerns & Feedback',
    Icons.forum_outlined,
    'Concerns & Feedback',
    'Messages from job seekers who were not matched to a job, and other concerns they raised.',
  ),
  _NavItem(
    AdminTab.jobs,
    'Jobs & Sources',
    Icons.work_outline,
    'Jobs & PDF Sources',
    'Manage existing job postings and review verified recruitment PDF links.',
  ),
  _NavItem(
    AdminTab.applications,
    'Recruitment Pipeline',
    Icons.assignment_outlined,
    'Applications & DOLE Records',
    'Review job applications and access live DOLE SPRS export records.',
  ),
  _NavItem(
    AdminTab.geminiKeys,
    'AI & Platform',
    Icons.tune_outlined,
    'AI Configuration & Platform',
    'Manage Gemini API keys, model matching preferences, and platform statistics.',
  ),
];

// =====================================================================
// TOAST HELPER
// =====================================================================
void showToast(
  BuildContext context,
  String message, {
  IconData icon = Icons.check_circle,
  Color iconColor = _C.emerald,
}) {
  AppToast.show(
    context,
    message,
    kind: icon == Icons.picture_as_pdf
        ? AppToastKind.info
        : AppToastKind.success,
    icon: icon,
    color: iconColor,
  );
}

// =====================================================================
// ANIMATION HELPERS
// =====================================================================

/// Fades + slides a child upward into place. Give each item in a list an
/// increasing [delayMs] to get a staggered "cascade" entrance.
class FadeSlideEntrance extends StatefulWidget {
  final Widget child;
  final int delayMs;
  final Duration duration;
  const FadeSlideEntrance({
    super.key,
    required this.child,
    this.delayMs = 0,
    this.duration = const Duration(milliseconds: 480),
  });

  @override
  State<FadeSlideEntrance> createState() => _FadeSlideEntranceState();
}

class _FadeSlideEntranceState extends State<FadeSlideEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.10),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Animates an integer value counting up from 0 to [value], with comma
/// formatting and an optional prefix/suffix (e.g. '%').
class AnimatedCounterText extends StatefulWidget {
  final int value;
  final TextStyle style;
  final String prefix;
  final String suffix;
  final Duration duration;
  const AnimatedCounterText({
    super.key,
    required this.value,
    required this.style,
    this.prefix = '',
    this.suffix = '',
    this.duration = const Duration(milliseconds: 900),
  });

  @override
  State<AnimatedCounterText> createState() => _AnimatedCounterTextState();
}

class _AnimatedCounterTextState extends State<AnimatedCounterText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late Animation<int> _animation;

  @override
  void initState() {
    super.initState();
    _animation = IntTween(
      begin: 0,
      end: widget.value,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutExpo));
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedCounterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = IntTween(begin: oldWidget.value, end: widget.value).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutExpo),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final formatted = _animation.value.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
        return Text(
          '${widget.prefix}$formatted${widget.suffix}',
          style: widget.style,
        );
      },
    );
  }
}

// =====================================================================
// ROOT WIDGET
// =====================================================================
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key, this.googleSignIn});

  /// Optional test adapter; the PESO API still verifies administrator roles.
  final Future<UserCredential> Function()? googleSignIn;

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  // Admin authorization is validated by the protected MongoDB-backed PESO API.

  AdminTab _activeTab = AdminTab.analytics;
  final _adminGateEmailController = TextEditingController();
  final _adminGatePasswordController = TextEditingController();
  bool _isVerifyingAdmin = false;
  bool _googleVerifyPending = false;
  int _googleVerifyRequestId = 0;
  bool _firebaseAdminVerified = false;
  bool _obscureAdminGatePassword = true;
  String? _adminGateError;
  bool _isLoggingOut = false;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  List<Applicant> _applicants = <Applicant>[];
  List<Concern> _concerns = <Concern>[];
  bool _loadingAdminProfiles = false;
  String? _adminProfileLoadError;

  @override
  void dispose() {
    _adminGateEmailController.dispose();
    _adminGatePasswordController.dispose();
    super.dispose();
  }

  DateTime _dateValue(Object? value) {
    if (value is DateTime) return value;
    if (value is String)
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _text(Object? value) => value?.toString() ?? '';

  String _orText(Object? value, String fallback) {
    final text = _text(value).trim();
    return text.isEmpty ? fallback : text;
  }

  int _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<bool> _confirmMongoAdminRole() async {
    try {
      // The backend verifies the Firebase token and MongoDB users.role.
      await PesoApiClient.adminListUsers(limit: 1);
      return true;
    } on PesoApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        try {
          await FirebaseAuth.instance.signOut();
        } catch (_) {
          // The server denial remains authoritative even if sign-out fails.
        }
      }
      if (mounted) {
        final message = switch (error.statusCode) {
          403 => 'This account does not have the PESO Admin role in MongoDB.',
          503 => 'The PESO Admin API or MongoDB is not ready. Complete backend setup, then retry.',
          401 => 'Your Firebase session could not be verified. Sign in again and retry.',
          _ => error.message,
        };
        setState(() => _adminGateError = message);
      }
      return false;
    } catch (_) {
      if (mounted) {
        setState(
          () => _adminGateError = 'The PESO API could not verify this account. Check the backend connection and retry.',
        );
      }
      return false;
    }
  }

  Future<void> _loadAdminDashboardProfiles() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() {
      _loadingAdminProfiles = true;
      _adminProfileLoadError = null;
    });
    try {
      // The protected PESO API below validates the MongoDB-backed Admin role.
      final profiles = <Map<String, dynamic>>[];
      String? pageToken;
      // Bound the scan to avoid an accidental endless paging loop.
      for (var pageIndex = 0; pageIndex < 100; pageIndex++) {
        final response = await PesoApiClient.adminListUsers(
          limit: 100,
          pageToken: pageToken,
        );
        final pageUsers = (response['users'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item));
        profiles.addAll(
          pageUsers.where(
            (user) =>
                user['customAdmin'] != true && _text(user['role']) != 'admin',
          ),
        );
        pageToken = response['nextPageToken'] as String?;
        if (pageToken == null || pageToken.isEmpty) break;
      }

      // Authoritative GridFS/structured document availability, batched by UID.
      final documentStatuses = <String, Map<String, dynamic>>{};
      final profileUids = profiles.map((p) => _text(p['uid']))
          .where((uid) => uid.isNotEmpty).toList();
      for (var start = 0; start < profileUids.length; start += 100) {
        final end = start + 100 < profileUids.length ? start + 100 : profileUids.length;
        try {
          final result = await PesoApiClient.adminApplicantDocumentStatuses(
              profileUids.sublist(start, end));
          final records = result['records'];
          if (records is Map) {
            for (final entry in records.entries) {
              if (entry.value is Map) {
                documentStatuses[entry.key.toString()] =
                    Map<String, dynamic>.from(entry.value as Map);
              }
            }
          }
        } catch (_) {
          // Keep user list available if the document-status integration is offline.
        }
      }
      final applicants = <Applicant>[];
      for (final data in profiles) {
        final displayName = _text(data['displayName']).trim().isNotEmpty
            ? _text(data['displayName']).trim()
            : (_text(data['firstName']).trim() +
                      ' ' +
                      _text(data['lastName']).trim())
                  .trim();
        applicants.add(
          Applicant(
            uid: _text(data['uid']),
            id: applicants.length + 1,
            name: displayName.isNotEmpty
                ? displayName
                : _orText(data['email'], 'Unnamed user'),
            barangay: _orText(data['location'], 'Unspecified'),
            targetJob: _orText(data['professionalTitle'], 'Not specified'),
            registeredDate: _dateValue(
              data['createdAt'] ?? data['lastSignInAt'],
            ),
            yearsExperience: _intValue(data['yearsExperience']),
            resumeSubmitted: documentStatuses[_text(data['uid'])]?['resume'] is Map
                ? (documentStatuses[_text(data['uid'])]!['resume'] as Map)['status'] != 'not_submitted'
                : data['resumeSubmitted'] == true,
            formSubmitted: documentStatuses[_text(data['uid'])]?['nsrp'] is Map
                ? (documentStatuses[_text(data['uid'])]!['nsrp'] as Map)['status'] != 'not_submitted'
                : data['formSubmitted'] == true,
            matchStatus:
                const {
                  'matched',
                  'not_matched',
                  'pending',
                }.contains(_text(data['matchStatus']))
                ? _text(data['matchStatus'])
                : 'pending',
            matchedJobsCount: _intValue(data['matchedJobsCount']),
            resumeFileName: _orText(
              data['resumeFileName'],
              'No resume uploaded',
            ),
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _applicants = applicants;
        // No real concerns collection is configured yet; never seed demo data.
        _concerns = <Concern>[];
      });
    } on PesoApiException catch (error) {
      if (mounted) {
        setState(() => _adminProfileLoadError = error.message);
      }
      debugPrint('[ADMIN] PESO API profile load failed: ' + error.code);
    } catch (error) {
      if (mounted) {
        setState(
          () => _adminProfileLoadError = 'Could not verify or load admin dashboard data. Check the PESO API and MongoDB backend, then retry.',
        );
      }
      debugPrint('[ADMIN] Profile refresh failed: $error');
    } finally {
      if (mounted) setState(() => _loadingAdminProfiles = false);
    }
  }

  void _cancelAdminGoogleSignIn() {
    if (!_googleVerifyPending) return;
    ++_googleVerifyRequestId;
    setState(() {
      _googleVerifyPending = false;
      _isVerifyingAdmin = false;
      _adminGateError = 'Google verification was cancelled. Try again or use another sign-in method.';
    });
  }

  Future<void> _signInWithGoogleForAdmin() async {
    if (_isVerifyingAdmin) return;
    final requestId = ++_googleVerifyRequestId;
    setState(() {
      _isVerifyingAdmin = true;
      _googleVerifyPending = true;
      _adminGateError = null;
    });

    try {
      final provider = GoogleAuthProvider()
        ..addScope('email')
        ..setCustomParameters({'prompt': 'select_account'});

      // On web, Firebase's Google OAuth popup returns to this exact admin
      // screen. Native platforms use the system/provider sign-in flow.
      final credential =
          await (widget.googleSignIn?.call() ??
              (kIsWeb
                  ? FirebaseAuth.instance.signInWithPopup(provider)
                  : FirebaseAuth.instance.signInWithProvider(provider)));
      if (!mounted || requestId != _googleVerifyRequestId) return;
      final user = credential.user;
      if (user == null) {
        if (mounted) {
          setState(
            () => _adminGateError = 'Google sign-in returned no Firebase account. Please try again.',
          );
        }
        return;
      }

      if (!await _confirmMongoAdminRole()) return;

      if (!mounted || requestId != _googleVerifyRequestId) return;
      setState(() {
        _firebaseAdminVerified = true;
        _adminGateError = null;
        _adminGateEmailController.clear();
        _adminGatePasswordController.clear();
      });
      await _loadAdminDashboardProfiles();
    } on FirebaseAuthException catch (error) {
      if (!mounted || requestId != _googleVerifyRequestId) return;
      final message = switch (error.code) {
        'popup-closed-by-user' || 'cancelled-popup-request' => 'Google sign-in was cancelled. Select your administrator Google account to continue.',
        'popup-blocked' => 'The browser blocked the Google sign-in popup. Allow popups for this app and try again.',
        'operation-not-allowed' => 'Google sign-in is not enabled for this Firebase project. Enable Google under Firebase Console > Authentication > Sign-in method.',
        'unauthorized-domain' => 'This website domain is not authorized for Firebase sign-in. Add it under Firebase Console > Authentication > Settings > Authorized domains.',
        'network-request-failed' => 'Firebase could not be reached. Check your internet connection and try again.',
        'account-exists-with-different-credential' => 'This Google email is already registered with another sign-in method. Use the linked Firebase sign-in method first.',
        _ => 'Google/Firebase administrator verification failed. Check the Firebase Authentication configuration and try again.',
      };
      setState(() => _adminGateError = message);
    } catch (_) {
      if (mounted && requestId == _googleVerifyRequestId) {
        setState(
          () => _adminGateError = 'The Google sign-in security check could not finish. Check Firebase setup and try again.',
        );
      }
    } finally {
      if (mounted && requestId == _googleVerifyRequestId) {
        setState(() {
          _googleVerifyPending = false;
          _isVerifyingAdmin = false;
        });
      }
    }
  }

  Future<void> _verifyExistingFirebaseAdministrator() async {
    setState(() {
      _isVerifyingAdmin = true;
      _adminGateError = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted)
          setState(
            () => _adminGateError = 'No Firebase session is active. Sign in below with your administrator account.',
          );
        return;
      }
      if (!await _confirmMongoAdminRole()) return;
      if (!mounted) return;
      setState(() {
        _firebaseAdminVerified = true;
        _adminGateError = null;
        _adminGatePasswordController.clear();
      });
      await _loadAdminDashboardProfiles();
    } catch (_) {
      if (mounted)
        setState(
          () => _adminGateError = 'Firebase could not verify the current session. Sign in below and retry.',
        );
    } finally {
      if (mounted) setState(() => _isVerifyingAdmin = false);
    }
  }

  Future<void> _verifyFirebaseAdministrator() async {
    final email = _adminGateEmailController.text.trim();
    final password = _adminGatePasswordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(
        () => _adminGateError = 'Enter the email and password of your Firebase administrator account.',
      );
      return;
    }
    setState(() {
      _isVerifyingAdmin = true;
      _adminGateError = null;
    });
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        if (mounted)
          setState(
            () => _adminGateError =
                'Firebase could not confirm the signed-in account.',
          );
        return;
      }
      if (!await _confirmMongoAdminRole()) return;
      if (!mounted) return;
      setState(() {
        _firebaseAdminVerified = true;
        _adminGateError = null;
        _adminGatePasswordController.clear();
      });
      await _loadAdminDashboardProfiles();
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      final message = switch (error.code) {
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' => 'The Firebase email or password is incorrect.',
        'too-many-requests' => 'Firebase temporarily blocked sign-in attempts. Wait a little and retry.',
        'network-request-failed' => 'Firebase cannot be reached. Check your internet connection and retry.',
        _ => 'Firebase administrator verification failed. Check your credentials and try again.',
      };
      setState(() => _adminGateError = message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _adminGateError = 'The Firebase security check could not finish. Verify Firebase setup and try again.',
      );
    } finally {
      if (mounted) setState(() => _isVerifyingAdmin = false);
    }
  }

  Future<void> _leaveAdminGate() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      // Firebase may not be initialized when the local preview is opened.
    }
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LandingPage()),
      (_) => false,
    );
  }

  Widget _buildAdminSecurityGate() {
    return Scaffold(
      backgroundColor: const Color(0xFF0D251B),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _C.slate200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    alignment: Alignment.center,
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5EE),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 40,
                      color: _C.primary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Protected Admin Area',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: _C.slate900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Verify your identity directly with Firebase. Admin access is based on the MongoDB user profile role. The protected PESO API confirms role=admin before granting access.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _C.slate600, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _isVerifyingAdmin
                        ? null
                        : _signInWithGoogleForAdmin,
                    icon: _isVerifyingAdmin
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.g_mobiledata, size: 30),
                    label: Text(
                      _isVerifyingAdmin
                          ? 'Waiting for Google / verifying account...'
                          : 'Continue with Google',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _C.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  if (_googleVerifyPending) ...[
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: _cancelAdminGoogleSignIn,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text(
                        'Cancel Google verification / unlock form',
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _isVerifyingAdmin
                        ? null
                        : _verifyExistingFirebaseAdministrator,
                    icon: const Icon(Icons.verified_user_outlined),
                    label: const Text(
                      'Verify current Firebase session instead',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Firebase verifies your sign-in. The PESO API grants Admin access only when your MongoDB user profile has role=admin. The configured initial Admin account can be bootstrapped after Google sign-in when MongoDB is connected; other accounts must be assigned the Admin role in MongoDB.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _C.slate500,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      'OR SIGN IN WITH FIREBASE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _C.slate500,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  TextField(
                    controller: _adminGateEmailController,
                    enabled: !_isVerifyingAdmin,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [
                      AutofillHints.username,
                      AutofillHints.email,
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Firebase administrator email',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _verifyFirebaseAdministrator(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _adminGatePasswordController,
                    enabled: !_isVerifyingAdmin,
                    obscureText: _obscureAdminGatePassword,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: 'Firebase password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _obscureAdminGatePassword =
                              !_obscureAdminGatePassword,
                        ),
                        icon: Icon(
                          _obscureAdminGatePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        tooltip: _obscureAdminGatePassword
                            ? 'Show password'
                            : 'Hide password',
                      ),
                    ),
                    onSubmitted: (_) => _verifyFirebaseAdministrator(),
                  ),
                  if (_adminGateError != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _adminGateError!,
                        style: const TextStyle(color: _C.rose600, height: 1.4),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _isVerifyingAdmin
                        ? null
                        : _verifyFirebaseAdministrator,
                    icon: _isVerifyingAdmin
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.verified_user_outlined),
                    label: Text(
                      _isVerifyingAdmin
                          ? 'Verifying with Firebase...'
                          : 'Verify and unlock Admin',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _C.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: _isVerifyingAdmin ? null : _leaveAdminGate,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back to PESO home'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);
    try {
      await FirebaseAuth.instance.signOut();
    } catch (error) {
      debugPrint('[ADMIN] Firebase sign-out failed: $error');
    }
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LandingPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_firebaseAdminVerified) return _buildAdminSecurityGate();
    final navItem = kNavItems.firstWhere((n) => n.tab == _activeTab);
    final unresolvedConcerns = _concerns.where((c) => !c.resolved).length;
    final badgeCounts = <AdminTab, int>{
      if (unresolvedConcerns > 0) AdminTab.concerns: unresolvedConcerns,
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 980;
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: _C.bg,
          drawer: isWide
              ? null
              : Drawer(
                  backgroundColor: _C.sidebar,
                  child: _Sidebar(
                    activeTab: _activeTab,
                    badgeCounts: badgeCounts,
                    onSelect: (t) {
                      setState(() => _activeTab = t);
                      Navigator.pop(context);
                    },
                    onLogout: () {
                      Navigator.pop(context);
                      _logout();
                    },
                  ),
                ),
          body: Stack(
            children: [
              Row(
                children: [
                  if (isWide)
                    SizedBox(
                      width: 300,
                      child: _Sidebar(
                        activeTab: _activeTab,
                        badgeCounts: badgeCounts,
                        onSelect: (t) => setState(() => _activeTab = t),
                        onLogout: _logout,
                      ),
                    ),
                  Expanded(
                    child: Column(
                      children: [
                        _TopBar(
                          title: navItem.title,
                          subtitle: navItem.description,
                          onMenuTap: isWide
                              ? null
                              : () => _scaffoldKey.currentState?.openDrawer(),
                        ),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 380),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 0.03),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                ),
                            child: Padding(
                              key: ValueKey(_activeTab),
                              padding: const EdgeInsets.all(24),
                              child: _buildActiveSection(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_isLoggingOut) _buildLogoutOverlay(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActiveSection() {
    switch (_activeTab) {
      case AdminTab.analytics:
        if (_loadingAdminProfiles) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading registered profiles from the PESO API...'),
              ],
            ),
          );
        }
        if (_adminProfileLoadError != null) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      size: 42,
                      color: _C.rose600,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Live dashboard data could not be loaded',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_adminProfileLoadError!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _loadAdminDashboardProfiles,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry PESO API connection'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return ApplicantAnalyticsSection(applicants: _applicants);
      case AdminTab.users:
        return const AdminUserManagementSection();
      case AdminTab.concerns:
        return ConcernsSection(initialConcerns: _concerns);
      case AdminTab.jobs:
        return const _WorkspaceSubTabs(
          labels: ['Job Postings', 'Online PDF Sources'],
          children: [JobManagementSection(), AdminPdfLinkIngestionSection()],
        );
      case AdminTab.applications:
        return _WorkspaceSubTabs(
          labels: const ['Job Applications', 'DOLE SPRS & Excel'],
          children: [
            const JobApplicationsSection(),
            DoleSprsExportSection(applicants: _applicants),
          ],
        );
      case AdminTab.ingestion:
        return const AdminPdfLinkIngestionSection();
      case AdminTab.export:
        return DoleSprsExportSection(applicants: _applicants);
      case AdminTab.geminiKeys:
        return _WorkspaceSubTabs(
          labels: const ['Gemini API Keys', 'Platform Analytics'],
          children: [
            const GeminiApiKeyManagementSection(),
            PlatformAnalyticsSection(applicants: _applicants),
          ],
        );
      case AdminTab.platform:
        return PlatformAnalyticsSection(applicants: _applicants);
    }
  }

  Widget _buildLogoutOverlay() {
    return Positioned.fill(
      child: RepaintBoundary(
        child: Container(
          color: _C.sidebar.withValues(alpha: 0.6),
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.9, end: 1.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: _C.primary,
                      strokeWidth: 4,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Securing session...',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _C.slate900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Safely logging you out of the Admin Portal.',
                      style: TextStyle(color: _C.slate500),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// SIDEBAR
// =====================================================================
class _Sidebar extends StatelessWidget {
  final AdminTab activeTab;
  final ValueChanged<AdminTab> onSelect;
  final VoidCallback onLogout;
  final Map<AdminTab, int> badgeCounts;
  const _Sidebar({
    required this.activeTab,
    required this.onSelect,
    required this.onLogout,
    this.badgeCounts = const {},
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.sidebar,
      padding: const EdgeInsets.all(20),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: _C.primary,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _C.primary.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'System Admin',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'IT & Data Operations',
                        style: TextStyle(
                          color: Color(0xFFA4D3B8),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: List.generate(kNavItems.length, (index) {
                  final item = kNavItems[index];
                  final isActive = item.tab == activeTab;
                  final badge = badgeCounts[item.tab] ?? 0;
                  return FadeSlideEntrance(
                    delayMs: index * 60,
                    duration: const Duration(milliseconds: 380),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Material(
                        color: isActive
                            ? const Color(0xFF193D31)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => onSelect(item.tab),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  width: 3,
                                  height: isActive ? 20 : 0,
                                  decoration: BoxDecoration(
                                    color: _C.primary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                SizedBox(width: isActive ? 10 : 13),
                                AnimatedScale(
                                  scale: isActive ? 1.1 : 1.0,
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    item.icon,
                                    size: 18,
                                    color: isActive
                                        ? const Color(0xFFA4D3B8)
                                        : Colors.white54,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 200),
                                    style: TextStyle(
                                      color: isActive
                                          ? const Color(0xFFA4D3B8)
                                          : Colors.white54,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                    ),
                                    child: Text(item.label),
                                  ),
                                ),
                                if (badge > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _C.rose,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '$badge',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 12),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onLogout,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 18, color: Color(0xFFFB7185)),
                      SizedBox(width: 12),
                      Text(
                        'Secure Logout',
                        style: TextStyle(
                          color: Color(0xFFFB7185),
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// TOP BAR
// =====================================================================
class _TopBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onMenuTap;
  const _TopBar({required this.title, required this.subtitle, this.onMenuTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _C.slate200)),
      ),
      child: Row(
        children: [
          if (onMenuTap != null) ...[
            IconButton(
              onPressed: onMenuTap,
              icon: const Icon(Icons.menu),
              color: _C.slate600,
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.25),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: Column(
                key: ValueKey(title),
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: _C.slate900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: _C.slate500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          _iconBtn(Icons.settings_outlined, _C.slate600, _C.slate100),
          const SizedBox(width: 10),
          _iconBtn(Icons.person_outline, _C.primary, const Color(0xFFDBEAFE)),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, Color bg) {
    return _PulseTapIcon(icon: icon, color: color, bg: bg);
  }
}

class _PulseTapIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final Color bg;
  const _PulseTapIcon({
    required this.icon,
    required this.color,
    required this.bg,
  });

  @override
  State<_PulseTapIcon> createState() => _PulseTapIconState();
}

class _PulseTapIconState extends State<_PulseTapIcon> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.88),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: widget.bg, shape: BoxShape.circle),
          child: Icon(widget.icon, size: 18, color: widget.color),
        ),
      ),
    );
  }
}

// =====================================================================
// SHARED WIDGETS
// =====================================================================
class _SectionCard extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;
  final Widget child;
  const _SectionCard({
    this.title,
    this.icon,
    this.iconColor,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _C.slate200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 10,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null)
                      Icon(icon, size: 20, color: iconColor ?? _C.primary),
                    if (icon != null) const SizedBox(width: 8),
                    Text(
                      title!,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _C.slate900,
                      ),
                    ),
                  ],
                ),
                if (trailing != null) trailing!,
              ],
            ),
          if (title != null) const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _KpiCard extends StatefulWidget {
  final String label;
  final int numericValue;
  final String suffix;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final Color? subtitleColor;
  const _KpiCard({
    required this.label,
    required this.numericValue,
    this.suffix = '',
    required this.icon,
    required this.color,
    this.subtitle,
    this.subtitleColor,
  });

  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hover ? -4 : 0, 0),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _hover ? widget.color.withValues(alpha: 0.35) : _C.slate200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _hover ? 0.08 : 0.03),
              blurRadius: _hover ? 22 : 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(widget.icon, size: 14, color: _C.slate500),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _C.slate500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            AnimatedCounterText(
              value: widget.numericValue,
              suffix: widget.suffix,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: widget.color,
              ),
            ),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 3),
              Text(
                widget.subtitle!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  color: widget.subtitleColor ?? _C.slate400,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final StatusStyle style;
  const _StatusBadge(this.style);
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: style.bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: style.dot,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              style.label,
              style: TextStyle(
                color: style.text,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// DONUT CHART — animated arc growth
// =====================================================================
class DonutChart extends StatefulWidget {
  final List<MapEntry<String, double>> segments;
  final Map<String, Color> colors;
  const DonutChart({super.key, required this.segments, required this.colors});

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant DonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, child) => CustomPaint(
        painter: _DonutPainter(widget.segments, widget.colors, _progress.value),
        size: Size.infinite,
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<MapEntry<String, double>> segments;
  final Map<String, Color> colors;
  final double progress;
  _DonutPainter(this.segments, this.colors, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final total = segments.fold<double>(0, (sum, e) => sum + e.value);
    if (total <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    const strokeWidth = 26.0;
    var startAngle = -math.pi / 2;
    for (final seg in segments) {
      final fullSweep = (seg.value / total) * 2 * math.pi;
      final sweep = fullSweep * progress;
      final gap = fullSweep > 0.04 ? 0.03 : 0.0;
      final paint = Paint()
        ..color = colors[seg.key] ?? Colors.grey
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        (sweep - gap).clamp(0, 2 * math.pi),
        false,
        paint,
      );
      startAngle += fullSweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// =====================================================================
// INTERACTIVE TREND CHART — hover/tap a day to see its numbers
// (This is what answers "pag inano ko yong mouse nandon yong day at
// ilan ang nag-match" — hover or tap a point on the line to see that
// day's registrations vs matches.)
// =====================================================================
class TrendSeries {
  final String label;
  final Color color;
  final List<double> values;
  const TrendSeries(this.label, this.color, this.values);
}

class InteractiveTrendChart extends StatefulWidget {
  final List<DateTime> dates;
  final List<TrendSeries> series;
  const InteractiveTrendChart({
    super.key,
    required this.dates,
    required this.series,
  });

  @override
  State<InteractiveTrendChart> createState() => _InteractiveTrendChartState();
}

class _InteractiveTrendChartState extends State<InteractiveTrendChart> {
  int? _hoverIndex;

  void _updateHover(Offset localPos, double width) {
    if (widget.dates.length < 2) return;
    final stepX = width / (widget.dates.length - 1);
    final idx = (localPos.dx / stepX).round().clamp(0, widget.dates.length - 1);
    if (idx != _hoverIndex) setState(() => _hoverIndex = idx);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: widget.series
                  .map(
                    (s) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: s.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          s.label,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _C.slate600,
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 14),
            MouseRegion(
              onHover: (e) => _updateHover(e.localPosition, width),
              onExit: (_) => setState(() => _hoverIndex = null),
              child: GestureDetector(
                onPanUpdate: (d) => _updateHover(d.localPosition, width),
                onPanDown: (d) => _updateHover(d.localPosition, width),
                onTapDown: (d) => _updateHover(d.localPosition, width),
                child: SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _MultiLinePainter(
                      widget.dates,
                      widget.series,
                      _hoverIndex,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _hoverIndex != null
                ? _buildTooltipRow(widget.dates[_hoverIndex!], _hoverIndex!)
                : const Row(
                    children: [
                      Icon(
                        Icons.touch_app_outlined,
                        size: 14,
                        color: _C.slate400,
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'I-hover o i-tap ang graph para makita ang detalye ng araw na iyon.',
                          style: TextStyle(fontSize: 11, color: _C.slate400),
                        ),
                      ),
                    ],
                  ),
          ],
        );
      },
    );
  }

  Widget _buildTooltipRow(DateTime date, int idx) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _C.slate100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 20,
        runSpacing: 8,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today, size: 12, color: _C.slate500),
              const SizedBox(width: 6),
              Text(
                _fmtDate(date),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: _C.slate900,
                ),
              ),
            ],
          ),
          for (final s in widget.series)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: s.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${s.label}: ${s.values[idx].toInt()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: _C.slate700,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MultiLinePainter extends CustomPainter {
  final List<DateTime> dates;
  final List<TrendSeries> series;
  final int? hoverIndex;
  _MultiLinePainter(this.dates, this.series, this.hoverIndex);

  @override
  void paint(Canvas canvas, Size size) {
    if (dates.isEmpty) return;
    final maxV = series
        .expand((s) => s.values)
        .fold<double>(0, (p, e) => math.max(p, e));
    final safeMax = maxV <= 0 ? 1.0 : maxV;
    final stepX = dates.length > 1
        ? size.width / (dates.length - 1)
        : size.width;

    final gridPaint = Paint()
      ..color = _C.slate200
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height / 3 * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (final s in series) {
      final path = Path();
      for (var i = 0; i < s.values.length; i++) {
        final x = i * stepX;
        final y = size.height - (s.values[i] / safeMax) * size.height;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      final paint = Paint()
        ..color = s.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, paint);

      for (var i = 0; i < s.values.length; i++) {
        final x = i * stepX;
        final y = size.height - (s.values[i] / safeMax) * size.height;
        final isHover = hoverIndex == i;
        canvas.drawCircle(
          Offset(x, y),
          isHover ? 4.5 : 2.5,
          Paint()..color = s.color,
        );
        if (isHover) {
          canvas.drawCircle(
            Offset(x, y),
            8,
            Paint()..color = s.color.withValues(alpha: 0.20),
          );
        }
      }
    }

    if (hoverIndex != null) {
      final x = hoverIndex! * stepX;
      final linePaint = Paint()
        ..color = _C.slate400
        ..strokeWidth = 1;
      const dashHeight = 4.0, dashGap = 4.0;
      var startY = 0.0;
      while (startY < size.height) {
        canvas.drawLine(
          Offset(x, startY),
          Offset(x, math.min(startY + dashHeight, size.height)),
          linePaint,
        );
        startY += dashHeight + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MultiLinePainter oldDelegate) =>
      oldDelegate.hoverIndex != hoverIndex ||
      oldDelegate.series != series ||
      oldDelegate.dates != dates;
}

// =====================================================================
// MINI TREND CARD — a single-metric card with a colored dot + label,
// a big animated number, and a smooth gradient-filled sparkline below
// it. Hovering/tapping the sparkline shows a small floating tooltip
// with that day's date and value (mirrors the reference design where
// "Registered", "Passed"/"Matched" and "Did not pass"/"No match" are
// each shown as their own standalone card).
// =====================================================================
class _TrendMiniCard extends StatefulWidget {
  final String label;
  final Color color;
  final int value;
  final List<DateTime> dates;
  final List<double> values;
  const _TrendMiniCard({
    required this.label,
    required this.color,
    required this.value,
    required this.dates,
    required this.values,
  });

  @override
  State<_TrendMiniCard> createState() => _TrendMiniCardState();
}

class _TrendMiniCardState extends State<_TrendMiniCard> {
  int? _hoverIndex;

  void _updateHover(Offset localPos, double width) {
    if (widget.dates.length < 2) return;
    final stepX = width / (widget.dates.length - 1);
    final idx = (localPos.dx / stepX).round().clamp(0, widget.dates.length - 1);
    if (idx != _hoverIndex) setState(() => _hoverIndex = idx);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _C.slate200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _C.slate600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          AnimatedCounterText(
            value: widget.value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: widget.color,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                return MouseRegion(
                  onHover: (e) => _updateHover(e.localPosition, c.maxWidth),
                  onExit: (_) => setState(() => _hoverIndex = null),
                  child: GestureDetector(
                    onPanUpdate: (d) =>
                        _updateHover(d.localPosition, c.maxWidth),
                    onPanDown: (d) => _updateHover(d.localPosition, c.maxWidth),
                    onTapDown: (d) => _updateHover(d.localPosition, c.maxWidth),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: double.infinity,
                          child: CustomPaint(
                            painter: _AreaSparklinePainter(
                              widget.values,
                              widget.color,
                              _hoverIndex,
                            ),
                          ),
                        ),
                        if (_hoverIndex != null) _buildTooltip(c.maxWidth),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: _C.slate200),
          const SizedBox(height: 8),
          const Text(
            'Last 14 days',
            style: TextStyle(
              fontSize: 11.5,
              color: _C.slate400,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTooltip(double width) {
    final idx = _hoverIndex!;
    final stepX = widget.dates.length > 1
        ? width / (widget.dates.length - 1)
        : width;
    final x = idx * stepX;
    final alignRight = x > width / 2;
    return Positioned(
      top: 0,
      left: alignRight ? null : (x - 10).clamp(0.0, math.max(0.0, width - 20)),
      right: alignRight
          ? (width - x - 10).clamp(0.0, math.max(0.0, width - 20))
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.slate200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _fmtShortDate(widget.dates[idx]),
              style: const TextStyle(
                fontSize: 10.5,
                color: _C.slate500,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${widget.label} : ${widget.values[idx].toInt()}',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: widget.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtShortDate(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _AreaSparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final int? hoverIndex;
  _AreaSparklinePainter(this.values, this.color, this.hoverIndex);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxV = values.fold<double>(0, (p, e) => math.max(p, e));
    final minV = values.fold<double>(maxV, (p, e) => math.min(p, e));
    final range = (maxV - minV) <= 0 ? 1.0 : (maxV - minV);
    final n = values.length;
    final stepX = n > 1 ? size.width / (n - 1) : size.width;
    const topPad = 8.0;
    const bottomPad = 2.0;
    final chartHeight = math.max(1.0, size.height - topPad - bottomPad);

    final points = List.generate(n, (i) {
      final x = i * stepX;
      final normalized = (values[i] - minV) / range;
      final y = topPad + chartHeight - normalized * chartHeight;
      return Offset(x, y);
    });

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final midX = (p0.dx + p1.dx) / 2;
      linePath.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }

    final areaPath = Path()
      ..addPath(linePath, Offset.zero)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(areaPath, fillPaint);

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    if (hoverIndex != null && hoverIndex! >= 0 && hoverIndex! < points.length) {
      final hp = points[hoverIndex!];
      final dashPaint = Paint()
        ..color = color.withValues(alpha: 0.35)
        ..strokeWidth = 1;
      const dashH = 4.0, dashG = 4.0;
      var startY = 0.0;
      while (startY < size.height) {
        canvas.drawLine(
          Offset(hp.dx, startY),
          Offset(hp.dx, math.min(startY + dashH, size.height)),
          dashPaint,
        );
        startY += dashH + dashG;
      }
      canvas.drawCircle(hp, 8, Paint()..color = color.withValues(alpha: 0.18));
      canvas.drawCircle(hp, 4, Paint()..color = color);
      canvas.drawCircle(
        hp,
        4,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AreaSparklinePainter oldDelegate) =>
      oldDelegate.hoverIndex != hoverIndex ||
      oldDelegate.values != values ||
      oldDelegate.color != color;
}

// =====================================================================
// SECTION 1: APPLICANT ANALYTICS
// =====================================================================
class ApplicantAnalyticsSection extends StatefulWidget {
  final List<Applicant> applicants;
  const ApplicantAnalyticsSection({super.key, required this.applicants});

  @override
  State<ApplicantAnalyticsSection> createState() =>
      _ApplicantAnalyticsSectionState();
}

class _ApplicantAnalyticsSectionState extends State<ApplicantAnalyticsSection> {
  String _barangayFilter = 'All';
  int _visibleApplicantRows = 12;

  List<Applicant> get _filtered => _barangayFilter == 'All'
      ? widget.applicants
      : widget.applicants.where((a) => a.barangay == _barangayFilter).toList();

  Future<void> _openDocument(Applicant a, String kind) =>
      AdminApplicantDocumentViewer.open(context,
          uid: a.uid, applicantName: a.name, kind: kind);

  Future<void> _exportApplicationsWorkbook() async {
    try {
      final response = await PesoApiClient.adminCreateExportLink();
      final uri = Uri.tryParse(response['url']?.toString() ?? '');
      if (uri == null || !uri.hasAuthority || !{'http', 'https'}.contains(uri.scheme)) {
        throw StateError('The protected report URL is unavailable.');
      }
      final opened = await launchUrl(uri, mode: LaunchMode.platformDefault,
          webOnlyWindowName: '_blank');
      if (!opened && mounted) {
        showToast(context, 'Could not open the protected Excel report. Check popup settings.');
      }
    } catch (_) {
      if (mounted) showToast(context, 'Could not generate the Excel report. Please retry.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final matched = filtered.where((a) => a.matchStatus == 'matched').length;
    final notMatched = filtered
        .where((a) => a.matchStatus == 'not_matched')
        .length;
    final pending = filtered.where((a) => a.matchStatus == 'pending').length;
    final processed = matched + notMatched;
    final matchRate = processed > 0 ? ((matched / processed) * 100).round() : 0;

    final today = DateTime.now();
    final dates = List.generate(
      14,
      (i) => today.subtract(Duration(days: 13 - i)),
    );
    final regSeries = <double>[];
    final matchedSeries = <double>[];
    final notMatchedSeries = <double>[];
    for (final d in dates) {
      final dayApplicants = filtered.where(
        (a) => _isSameDate(a.registeredDate, d),
      );
      regSeries.add(dayApplicants.length.toDouble());
      matchedSeries.add(
        dayApplicants
            .where((a) => a.matchStatus == 'matched')
            .length
            .toDouble(),
      );
      notMatchedSeries.add(
        dayApplicants
            .where((a) => a.matchStatus == 'not_matched')
            .length
            .toDouble(),
      );
    }

    final recent = [...filtered]
      ..sort((a, b) => b.registeredDate.compareTo(a.registeredDate));
    final recentTop = recent.take(_visibleApplicantRows).toList();

    final donutSegments = [
      if (matched > 0) MapEntry('Matched', matched.toDouble()),
      if (notMatched > 0) MapEntry('Low qualification', notMatched.toDouble()),
      if (pending > 0) MapEntry('Under review', pending.toDouble()),
    ];
    final donutColors = {
      'Matched': _C.emerald,
      'Low qualification': _C.rose,
      'Under review': _C.amber,
    };

    final kpiCards = [
      _KpiCard(
        label: 'REGISTERED JOB SEEKERS',
        numericValue: filtered.length,
        icon: Icons.groups_outlined,
        color: _C.slate900,
        subtitle: 'Saved MongoDB job-seeker profiles',
      ),
      _KpiCard(
        label: 'MATCHED TO A JOB',
        numericValue: matched,
        icon: Icons.check_circle_outline,
        color: _C.emerald600,
        subtitle: 'Resume + form matched to an employer listing',
        subtitleColor: _C.emerald600,
      ),
      _KpiCard(
        label: 'LOW QUALIFICATION',
        numericValue: notMatched,
        icon: Icons.cancel_outlined,
        color: _C.rose600,
        subtitle: 'Reviewed but no qualifying job found',
      ),
      _KpiCard(
        label: 'MATCH RATE',
        numericValue: matchRate,
        suffix: '%',
        icon: Icons.trending_up,
        color: _C.purple,
        subtitle: 'Of $processed with a completed resume review',
      ),
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (filtered.isEmpty)
            const _SectionCard(
              title: 'No registered profiles yet',
              icon: Icons.groups_outlined,
              child: Text(
                'This dashboard reads job-seeker profiles through the PESO API backed by MongoDB. Registered Firebase Authentication accounts appear as the API syncs them; match and resume metrics stay pending until those results are stored.',
                style: TextStyle(color: _C.slate600, height: 1.4),
              ),
            ),
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth > 900 ? 4 : (c.maxWidth > 560 ? 2 : 1);
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.55,
                children: List.generate(
                  kpiCards.length,
                  (i) => FadeSlideEntrance(delayMs: i * 80, child: kpiCards[i]),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          FadeSlideEntrance(
            delayMs: 320,
            child: Row(
              children: [
                const Text(
                  'Barangay:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _C.slate500,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: _C.slate300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _barangayFilter,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _C.slate700,
                      ),
                      items:
                          [
                                'All',
                                ...(widget.applicants
                                    .map((a) => a.barangay)
                                    .where((b) => b.trim().isNotEmpty)
                                    .toSet()
                                    .toList()
                                  ..sort()),
                              ]
                              .map(
                                (b) =>
                                    DropdownMenuItem(value: b, child: Text(b)),
                              )
                              .toList(),
                      onChanged: (v) =>
                          setState(() => _barangayFilter = v ?? 'All'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FadeSlideEntrance(
            delayMs: 380,
            child: LayoutBuilder(
              builder: (context, c) {
                final cols = c.maxWidth > 760 ? 3 : (c.maxWidth > 480 ? 2 : 1);
                const cardHeight = 260.0;
                final cellWidth = (c.maxWidth - (cols - 1) * 16) / cols;
                final cards = [
                  _TrendMiniCard(
                    label: 'Registered',
                    color: _C.slate900,
                    value: filtered.length,
                    dates: dates,
                    values: regSeries,
                  ),
                  _TrendMiniCard(
                    label: 'Matched',
                    color: _C.emerald,
                    value: matched,
                    dates: dates,
                    values: matchedSeries,
                  ),
                  _TrendMiniCard(
                    label: 'Low qualification',
                    color: _C.rose,
                    value: notMatched,
                    dates: dates,
                    values: notMatchedSeries,
                  ),
                ];
                return GridView.count(
                  crossAxisCount: cols,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: cellWidth / cardHeight,
                  children: List.generate(
                    cards.length,
                    (i) => FadeSlideEntrance(
                      delayMs: 420 + i * 100,
                      child: cards[i],
                    ),
                  ),
                );
              },
            ),
          ),
          FadeSlideEntrance(
            delayMs: 460,
            child: _SectionCard(
              title: 'Matching Breakdown',
              icon: Icons.auto_awesome,
              iconColor: _C.amber,
              child: LayoutBuilder(
                builder: (context, c) {
                  final stacked = c.maxWidth < 480;
                  final donut = SizedBox(
                    width: 170,
                    height: 170,
                    child: donutSegments.isEmpty
                        ? const SizedBox()
                        : DonutChart(
                            segments: donutSegments,
                            colors: donutColors,
                          ),
                  );
                  final legend = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: donutSegments
                        .map(
                          (s) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: donutColors[s.key],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  s.key,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: _C.slate600,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Text(
                                  '${s.value.toInt()}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: _C.slate900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  );
                  return stacked
                      ? Column(
                          children: [donut, const SizedBox(height: 20), legend],
                        )
                      : Row(
                          children: [
                            donut,
                            const SizedBox(width: 32),
                            Expanded(child: legend),
                          ],
                        );
                },
              ),
            ),
          ),
          FadeSlideEntrance(
            delayMs: 540,
            child: _SectionCard(
              title: 'Applicant Registrations, Resumes & Matching Records',
              icon: Icons.list_alt_outlined,
              trailing: OutlinedButton.icon(
                onPressed: _exportApplicationsWorkbook,
                icon: const Icon(Icons.download, size: 15),
                label: const Text(
                  'Download DOLE Excel',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _C.slate700,
                  side: const BorderSide(color: _C.slate300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              child: Column(
                children: [SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  dataRowMinHeight: 52,
                  dataRowMaxHeight: 70,
                  headingRowColor: MaterialStateProperty.all(_C.slate100),
                  columns: const [
                    DataColumn(label: Text('Job Seeker')),
                    DataColumn(label: Text('Barangay')),
                    DataColumn(label: Text('Target Job')),
                    DataColumn(label: Text('Registered')),
                    DataColumn(label: Text('Yrs. Exp.')),
                    DataColumn(label: Text('Matched Jobs')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Resume / NSRP')),
                  ],
                  rows: recentTop
                      .map(
                        (a) => DataRow(
                          cells: [
                            DataCell(
                              Text(
                                a.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                'Brgy. ${a.barangay}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            DataCell(
                              Text(
                                a.targetJob,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            DataCell(
                              Text(
                                _fmtDate(a.registeredDate),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                '${a.yearsExperience}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                a.matchStatus == 'matched'
                                    ? '${a.matchedJobsCount}'
                                    : '\u2014',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            DataCell(
                              _StatusBadge(kMatchStyles[a.matchStatus]!),
                            ),
                            DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(tooltip: a.resumeSubmitted
                                  ? 'View saved resume' : 'Resume not submitted',
                                icon: Icon(Icons.picture_as_pdf, size: 19,
                                  color: a.resumeSubmitted ? _C.rose600 : _C.slate400),
                                onPressed: a.uid.isEmpty ? null : () => _openDocument(a, 'resume')),
                              IconButton(tooltip: a.formSubmitted
                                  ? 'View saved NSRP Form 1' : 'NSRP Form 1 not submitted',
                                icon: Icon(Icons.assignment_outlined, size: 19,
                                  color: a.formSubmitted ? _C.primary : _C.slate400),
                                onPressed: a.uid.isEmpty ? null : () => _openDocument(a, 'nsrp')),
                            ])),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
              if (recent.length > recentTop.length)
                Align(alignment: Alignment.centerRight,
                  child: Padding(padding: const EdgeInsets.only(top: 12),
                    child: TextButton.icon(
                      onPressed: () => setState(() => _visibleApplicantRows += 25),
                      icon: const Icon(Icons.expand_more),
                      label: Text('Show more applicants (${recentTop.length}/${recent.length})'),
                    ),
                  ),
                ),
              ],),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// =====================================================================
// SECTION 3: CONCERNS & FEEDBACK
// (Inbox for messages from job seekers who did not get matched, or
// who have any other concern.)
// =====================================================================
class ConcernsSection extends StatefulWidget {
  final List<Concern> initialConcerns;
  const ConcernsSection({super.key, required this.initialConcerns});

  @override
  State<ConcernsSection> createState() => _ConcernsSectionState();
}

class _ConcernsSectionState extends State<ConcernsSection> {
  late List<Concern> _concerns;
  String _filter = 'unresolved'; // all | unresolved | resolved

  @override
  void initState() {
    super.initState();
    _concerns = List.of(widget.initialConcerns);
  }

  List<Concern> get _filtered {
    switch (_filter) {
      case 'unresolved':
        return _concerns.where((c) => !c.resolved).toList();
      case 'resolved':
        return _concerns.where((c) => c.resolved).toList();
      default:
        return _concerns;
    }
  }

  void _toggleResolved(Concern c) {
    setState(() => c.resolved = !c.resolved);
    showToast(
      context,
      c.resolved
          ? "Marked ${c.applicantName}'s concern as resolved."
          : "Reopened ${c.applicantName}'s concern.",
      icon: c.resolved ? Icons.check_circle : Icons.mark_email_unread_outlined,
      iconColor: c.resolved ? _C.emerald : _C.amber600,
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _concerns.length;
    final unresolved = _concerns.where((c) => !c.resolved).length;
    final resolved = total - unresolved;
    final filtered = _filtered;

    final kpiCards = [
      _KpiCard(
        label: 'TOTAL CONCERNS',
        numericValue: total,
        icon: Icons.forum_outlined,
        color: _C.slate900,
        subtitle: 'From job seekers with no job match yet',
      ),
      _KpiCard(
        label: 'NEEDS RESPONSE',
        numericValue: unresolved,
        icon: Icons.priority_high,
        color: _C.rose600,
        subtitle: 'Waiting for a PESO admin follow-up',
      ),
      _KpiCard(
        label: 'RESOLVED',
        numericValue: resolved,
        icon: Icons.check_circle_outline,
        color: _C.emerald600,
        subtitle: 'Already addressed',
      ),
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth > 700 ? 3 : 1;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 2.1,
                children: List.generate(
                  kpiCards.length,
                  (i) => FadeSlideEntrance(delayMs: i * 80, child: kpiCards[i]),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          FadeSlideEntrance(
            delayMs: 240,
            child: Row(
              children: [
                const Text(
                  'Show:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _C.slate500,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: _C.slate300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _filter,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _C.slate700,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'unresolved',
                          child: Text('Needs response'),
                        ),
                        DropdownMenuItem(
                          value: 'resolved',
                          child: Text('Resolved'),
                        ),
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('All concerns'),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _filter = v ?? 'unresolved'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'Wala pang concerns dito.',
                  style: TextStyle(color: _C.slate400),
                ),
              ),
            )
          else
            Column(
              children: List.generate(filtered.length, (i) {
                final c = filtered[i];
                return FadeSlideEntrance(
                  delayMs: i * 60,
                  child: _concernCard(c),
                );
              }),
            ),
        ],
      ),
    );
  }

  Widget _concernCard(Concern c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: c.resolved
                ? _C.emerald.withValues(alpha: 0.35)
                : _C.slate200,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFFFF1F2),
                  child: Icon(
                    Icons.person_outline,
                    color: _C.rose600,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.applicantName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: _C.slate900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Brgy. ${c.barangay} \u00b7 Target: ${c.targetJob} \u00b7 ${_fmtDate(c.submittedDate)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: _C.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(
                  c.resolved
                      ? const StatusStyle(
                          'Resolved',
                          Color(0xFF047857),
                          Color(0xFFECFDF5),
                          Color(0xFF10B981),
                        )
                      : const StatusStyle(
                          'Needs Response',
                          Color(0xFFBE123C),
                          Color(0xFFFFF1F2),
                          Color(0xFFF43F5E),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _C.slate100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                c.message,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: _C.slate700,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _toggleResolved(c),
                icon: Icon(
                  c.resolved ? Icons.replay : Icons.check_circle_outline,
                  size: 15,
                  color: c.resolved ? _C.slate500 : _C.emerald600,
                ),
                label: Text(
                  c.resolved ? 'Reopen' : 'Mark as Resolved',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: c.resolved ? _C.slate500 : _C.emerald600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// SECTION 5: DOLE SPRS EXPORT
// =====================================================================
class DoleSprsExportSection extends StatefulWidget {
  final List<Applicant> applicants;
  const DoleSprsExportSection({super.key, required this.applicants});

  @override
  State<DoleSprsExportSection> createState() => _DoleSprsExportSectionState();
}

class _DoleSprsExportSectionState extends State<DoleSprsExportSection> {
  static int _sortIndex(String status) {
    switch (status) {
      case 'matched':
        return 0;
      case 'pending':
        return 1;
      case 'not_matched':
        return 2;
      default:
        return 3;
    }
  }

  List<Applicant> get _sortedApplicants {
    final all = List.of(widget.applicants);
    all.sort((a, b) {
      final si = _sortIndex(a.matchStatus);
      final sj = _sortIndex(b.matchStatus);
      if (si != sj) return si - sj;
      return a.name.compareTo(b.name);
    });
    return all;
  }

  final Set<int> _handedOff = {};

  Future<void> _viewExcelOnline() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const AdminExcelLivePreview(),
    );
  }

  void _handoff() {
    final matched = _sortedApplicants
        .where((a) => a.matchStatus == 'matched')
        .toList();
    final pending = matched.where((a) => !_handedOff.contains(a.id)).toList();
    if (pending.isEmpty) {
      AppToast.show(
        context,
        'Everyone here has already been handed off to PESO Admin.',
      );
      return;
    }
    setState(() => _handedOff.addAll(pending.map((a) => a.id)));
    AppToast.show(
      context,
      'Handed off ${pending.length} candidate(s) to PESO Admin.',
    );
  }

  @override
  void initState() {
    super.initState();
    // No longer pre-filtering to matched only; all applicants are shown sorted.
  }

  @override
  Widget build(BuildContext context) {
    final total = _sortedApplicants.length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeSlideEntrance(
            delayMs: 0,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 12,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.filter_list, size: 15, color: _C.slate500),
                    const SizedBox(width: 8),
                    Text(
                      'Showing $total Applicants',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: _C.slate600,
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 10,
                  children: [
                    // Primary: View Excel Online button
                    ElevatedButton.icon(
                      onPressed: _viewExcelOnline,
                      icon: const Icon(Icons.open_in_new, size: 15),
                      label: const Text(
                        'View Excel Online',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _C.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    // Secondary: Handoff to PESO Admin (behavior unchanged)
                    OutlinedButton.icon(
                      onPressed: _handoff,
                      icon: const Icon(Icons.send, size: 15),
                      label: const Text(
                        'Handoff to PESO Admin',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _C.slate700,
                        side: const BorderSide(color: _C.slate300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Candidate cards: ALL applicants sorted matched-first, using Column with proper spacing
          ..._sortedApplicants.map(
            (a) => _ApplicantCard(
              applicant: a,
              handedOff: _handedOff.contains(a.id),
            ),
          ),
        ],
      ),
    );
  }
}

// Individual applicant card using Column with proper spacing
class _ApplicantCard extends StatelessWidget {
  final Applicant applicant;
  final bool handedOff;
  const _ApplicantCard({required this.applicant, required this.handedOff});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            left: BorderSide(
              color: handedOff
                  ? _C.emerald.withValues(alpha: 0.4)
                  : _C.slate200,
            ),
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFECFDF5),
                  child: Icon(Icons.person_outline, color: _C.emerald600),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        applicant.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: _C.slate900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            applicant.targetJob,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _C.slate500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusBadge(
                            kMatchStyles[applicant.matchStatus] ??
                                const StatusStyle(
                                  'Users with Low Qualification',
                                  Color(0xFFBE123C),
                                  Color(0xFFFFF1F2),
                                  Color(0xFFF43F5E),
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Submitted: ${_fmtDate(applicant.registeredDate)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: _C.slate400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Compact sub-navigation keeps existing admin pages in a single workspace.
/// Only the selected child is visible and each page retains its own controls.
class _WorkspaceSubTabs extends StatelessWidget {
  const _WorkspaceSubTabs({required this.labels, required this.children});

  final List<String> labels;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: labels.length,
      child: Column(
        children: [
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: _C.primary,
              labelColor: _C.primary,
              unselectedLabelColor: _C.slate500,
              tabs: [for (final label in labels) Tab(text: label)],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(child: TabBarView(children: children)),
        ],
      ),
    );
  }
}

// =====================================================================
// SECTION 6: PLATFORM ANALYTICS
// (AI exam settings are gone \u2014 replaced by the resume-matching engine.)
// =====================================================================
class PlatformAnalyticsSection extends StatefulWidget {
  final List<Applicant> applicants;
  const PlatformAnalyticsSection({super.key, required this.applicants});

  @override
  State<PlatformAnalyticsSection> createState() =>
      _PlatformAnalyticsSectionState();
}

class _PlatformAnalyticsSectionState extends State<PlatformAnalyticsSection>
    with SingleTickerProviderStateMixin {
  static const _defaultMinYears = 1.0;
  static const _defaultConfidence = 70.0;
  static const _defaultMaxMatches = 5.0;

  double _minYears = _defaultMinYears;
  double _confidence = _defaultConfidence;
  double _maxMatches = _defaultMaxMatches;
  double _savedMinYears = _defaultMinYears;
  double _savedConfidence = _defaultConfidence;
  double _savedMaxMatches = _defaultMaxMatches;

  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2500),
  )..repeat();

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  bool get _hasUnsaved =>
      _minYears != _savedMinYears ||
      _confidence != _savedConfidence ||
      _maxMatches != _savedMaxMatches;

  void _save() {
    setState(() {
      _savedMinYears = _minYears;
      _savedConfidence = _confidence;
      _savedMaxMatches = _maxMatches;
    });
    showToast(
      context,
      'Matching settings saved: ${_minYears.round()} yr min \u00b7 ${_confidence.round()}% confidence \u00b7 up to ${_maxMatches.round()} matches.',
    );
  }

  void _reset() {
    setState(() {
      _minYears = _defaultMinYears;
      _confidence = _defaultConfidence;
      _maxMatches = _defaultMaxMatches;
      _savedMinYears = _defaultMinYears;
      _savedConfidence = _defaultConfidence;
      _savedMaxMatches = _defaultMaxMatches;
    });
    showToast(context, 'Matching settings reset to default.');
  }

  @override
  Widget build(BuildContext context) {
    final resumesProcessed = widget.applicants
        .where((a) => a.resumeSubmitted && a.formSubmitted)
        .length;
    final autoMatched = widget.applicants
        .where((a) => a.matchStatus == 'matched')
        .length;
    final pendingReview = widget.applicants
        .where((a) => a.matchStatus == 'pending')
        .length;

    final kpiCards = [
      _KpiCard(
        label: 'RESUMES PROCESSED',
        numericValue: resumesProcessed,
        icon: Icons.description_outlined,
        color: _C.primary,
      ),
      _KpiCard(
        label: 'AUTO-MATCHED CANDIDATES',
        numericValue: autoMatched,
        icon: Icons.verified_outlined,
        color: _C.emerald600,
      ),
      _KpiCard(
        label: 'PENDING MANUAL REVIEW',
        numericValue: pendingReview,
        icon: Icons.pending_actions_outlined,
        color: _C.amber600,
      ),
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth > 700 ? 3 : 1;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 2.3,
                children: List.generate(
                  kpiCards.length,
                  (i) => FadeSlideEntrance(delayMs: i * 80, child: kpiCards[i]),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          FadeSlideEntrance(
            delayMs: 260,
            child: _SectionCard(
              title: 'Job Matching Engine Settings',
              icon: Icons.tune,
              iconColor: _C.indigo,
              trailing: _hasUnsaved
                  ? TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.7, end: 1.0),
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutBack,
                      builder: (context, scale, child) =>
                          Transform.scale(scale: scale, child: child),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Unsaved changes',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _C.amber600,
                          ),
                        ),
                      ),
                    )
                  : null,
              child: Column(
                children: [
                  LayoutBuilder(
                    builder: (context, c) {
                      final wide = c.maxWidth > 760;
                      final sliders = [
                        _settingSlider(
                          'Minimum years of experience',
                          Icons.timeline_outlined,
                          _minYears,
                          0,
                          10,
                          (v) => setState(() => _minYears = v),
                          'Applicants below this are routed to manual review instead of auto-match.',
                        ),
                        _settingSlider(
                          'Auto-match confidence threshold (%)',
                          Icons.psychology_outlined,
                          _confidence,
                          40,
                          95,
                          (v) => setState(() => _confidence = v),
                          'How closely the resume + form must fit a job posting to auto-match.',
                        ),
                        _settingSlider(
                          'Max matches shown per job seeker',
                          Icons.list_alt_outlined,
                          _maxMatches,
                          1,
                          10,
                          (v) => setState(() => _maxMatches = v),
                          'Caps how many matched job postings a job seeker sees at once.',
                        ),
                      ];
                      return wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: sliders
                                  .map(
                                    (s) => Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        child: s,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            )
                          : Column(
                              children: sliders
                                  .map(
                                    (s) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 20,
                                      ),
                                      child: s,
                                    ),
                                  )
                                  .toList(),
                            );
                    },
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save_outlined, size: 15),
                        label: const Text(
                          'Save Matching Settings',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _C.indigo,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _reset,
                        icon: const Icon(Icons.restart_alt, size: 15),
                        label: const Text(
                          'Reset to Default',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _C.slate600,
                          side: const BorderSide(color: _C.slate300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          FadeSlideEntrance(
            delayMs: 360,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _C.slate200),
              ),
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final t = _pulseController.value;
                      return SizedBox(
                        width: 70,
                        height: 70,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Opacity(
                              opacity: (1 - t).clamp(0, 1),
                              child: Transform.scale(
                                scale: 1 + t,
                                child: Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: _C.primary.withValues(alpha: 0.3),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: _C.primary.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.hub_outlined,
                                color: _C.primary,
                                size: 26,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'AI Matching Engine Status',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _C.slate900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 15,
                          color: _C.emerald600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '100% Uptime - Healthy',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _C.emerald600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingSlider(
    String label,
    IconData icon,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
    String helper,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: _C.slate600),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _C.slate600,
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: _C.indigo,
                  thumbColor: _C.indigo,
                  overlayColor: _C.indigo.withValues(alpha: 0.15),
                ),
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: math.max(1, ((max - min) / 1).round()),
                  onChanged: onChanged,
                ),
              ),
            ),
            SizedBox(
              width: 46,
              child: AnimatedCounterText(
                value: value.round(),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: _C.slate900,
                ),
                duration: const Duration(milliseconds: 200),
              ),
            ),
          ],
        ),
        Text(helper, style: const TextStyle(fontSize: 11, color: _C.slate400)),
      ],
    );
  }
}
