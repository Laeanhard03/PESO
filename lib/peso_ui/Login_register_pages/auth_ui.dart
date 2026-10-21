import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../peso_logic/registration_identity_merge.dart';
import '../../peso_services/applicant_draft_service.dart';
import '../../peso_services/registration_draft_scope.dart';

import '../../peso_services/app_toast.dart';
import '../../peso_services/auth_service.dart';
import '../../peso_services/peso_api_client.dart';
import '../../peso_services/profile_artifact_service.dart';
import '../../peso_services/peso_role_policy.dart';

import 'package:file_picker/file_picker.dart';

import '../../peso_models/profile_artifact.dart';
import '../../peso_logic/peso_ai_engine.dart';

// UI Imports from other directories
import '../Landingpage/landingpage_ui.dart';
import '../Reusable_Designs/reusable_ui.dart';
import '../Reusable_Designs/pesoform_ui.dart';
import '../Reusable_Designs/resumebuilder_ui.dart';
import '../Reusable_Designs/ai_processing_ui.dart';

// Sibling UI Imports
import 'login_ui.dart';
import 'register_ui.dart';
import '../Admin/admin_ui.dart';
import '../User/user_ui.dart';

enum AuthView { login, register, emailVerification, onboarding }

class AuthPage extends StatefulWidget {
  final bool initialIsLogin;
  final bool resumePendingVerification;
  const AuthPage({super.key, this.initialIsLogin = true,
    this.resumePendingVerification = false});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;
  late AuthView _currentView;

  String _selectedResumeType = 'upload'; // 'upload' or 'build'

  /// Values captured by the register form (or resolved from the signed-in
  /// account) that the resume builder, the AI extractor, and the NSRP form
  /// must inherit.
  Map<String, String> _registrationIdentity = const <String, String>{};
  RegistrationVerificationRequest? _verificationRequest;
  bool _verificationForRegistration = false;
  String _verificationEmail = '';
  bool _verificationBusy = false;
  bool _verificationEmailSent = false;
  String? _verificationEmailError;

  @override
  void initState() {
    super.initState();
    _currentView = widget.resumePendingVerification
        ? AuthView.emailVerification
        : (widget.initialIsLogin ? AuthView.login : AuthView.register);
    if (widget.resumePendingVerification) {
      _verificationEmail = FirebaseAuth.instance.currentUser?.email ?? '';
      _verificationForRegistration = false;
      _verificationEmailSent = true;
    }

    _scrollController.addListener(() {
      if (_scrollController.offset > 50 && !_isScrolled) {
        setState(() => _isScrolled = true);
      } else if (_scrollController.offset <= 50 && _isScrolled) {
        setState(() => _isScrolled = false);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _asStringMap(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _aiTextFromPayload(Map<String, dynamic> payload) =>
      (payload['aiText'] ?? payload['data'] ?? '').toString().trim();

  String _mimeTypeForExtension(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'pdf':
      default:
        return 'application/pdf';
    }
  }

  /// Sends the uploaded resume to Gemini before onboarding finishes so the
  /// extracted values can be inherited by the NSRP form. Uses `persist: false`,
  /// so nothing is stored until the final AI processing pass.
  Future<Map<String, dynamic>> _previewResumeExtraction(
    List<ProfileArtifactInput> artifacts,
  ) async {
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    // Gemini does not report byte-level progress. Ease an estimated bar toward
    // 90%, then show 100% only after extraction genuinely returns successfully.
    final progress = ValueNotifier<double>(0.08);
    final ticker = Timer.periodic(const Duration(milliseconds: 350), (_) {
      if (progress.value < 0.9) {
        progress.value = (progress.value + (0.9 - progress.value) * 0.025)
            .clamp(0.08, 0.9);
      }
    });
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ResumeAnalysisDialog(progress: progress),
    );
    try {
      // Store original owner-scoped bytes before non-persisting Gemini preview.
      final stored = await ProfileArtifactService.saveArtifacts(artifacts);
      if (stored.warnings.isNotEmpty ||
          stored.records.length != artifacts.length) {
        if (mounted) {
          AppToast.warning(context,
              'Your resume could not be uploaded yet. Continue with NSRP and retry the resume when online.');
        }
        return <String, dynamic>{};
      }
      final extracted = await PesoAIEngine.generateProfile(
        artifacts: artifacts,
        persist: false,
      );
      ticker.cancel();
      progress.value = 1;
      await Future<void>.delayed(const Duration(milliseconds: 550));
      return extracted;
    } catch (error) {
      debugPrint('[ONBOARDING] Resume scan unavailable ($error).');
      if (mounted) {
        AppToast.warning(
          context,
          'Resume scan is unavailable right now. Continue with the form; your document can be processed after onboarding.',
        );
      }
      return <String, dynamic>{};
    } finally {
      ticker.cancel();
      if (mounted && rootNavigator.canPop()) rootNavigator.pop();
      progress.dispose();
    }
  }

  /// Resume-extracted names and contacts are unverified suggestions.
  /// Registered identity takes precedence; only missing fields may be proposed
  /// for the applicant to review on the editable NSRP form.
  Map<String, String> _nsrpIdentityFromExtraction(
    Map<String, dynamic> extracted,
    Map<String, String> base,
  ) {
    return mergeResumeIdentityForNsrp(base, extracted);
  }

  Future<void> _completeOnboarding() async {
    final navigator = Navigator.of(context);
    final identity = await _resolveRegistrationIdentity();
    if (_selectedResumeType == 'build') {
      final artifacts = <ProfileArtifactInput>[];
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (context) => ResumeBuilderWizard(
            initialValues: identity,
            onComplete: (builderPayload) {
              final resumeData = _asStringMap(builderPayload['resumeData']);
              final resumeText = _aiTextFromPayload(builderPayload);
              final resumeArtifact = ProfileArtifactInput.fromBridgePayload(
                builderPayload['artifact'],
              );
              if (resumeArtifact != null) artifacts.add(resumeArtifact);

              navigator.pushReplacement(
                MaterialPageRoute(
                  builder: (context) => PesoRegistrationWizard(
                    initialValues: identity,
                    verifiedResumeSex: explicitResumeSex(resumeText),
                    onComplete: (pesoPayload) {
                      final pesoFormData = _asStringMap(
                        pesoPayload['formData'],
                      );
                      final pesoText = _aiTextFromPayload(pesoPayload);
                      final pesoArtifact =
                          ProfileArtifactInput.fromBridgePayload(
                            pesoPayload['artifact'],
                          );
                      if (pesoArtifact != null) artifacts.add(pesoArtifact);

                      final supplementalText = <String>[
                        if (resumeText.isNotEmpty)
                          '--- RESUME BUILDER ---\n$resumeText',
                        if (pesoText.isNotEmpty)
                          '--- NSRP FORM (sensitive ID numbers removed) ---\n$pesoText',
                      ].join('\n\n');

                      navigator.pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => AIProcessingScreen(
                            artifacts: List<ProfileArtifactInput>.unmodifiable(
                              artifacts,
                            ),
                            rawTextData: supplementalText,
                            resumeData: resumeData,
                            pesoFormData: pesoFormData,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      );
    } else if (_selectedResumeType == 'upload') {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result == null || result.files.single.bytes == null) return;
      final platformFile = result.files.single;
      final extension = (platformFile.extension ?? 'pdf').toLowerCase();
      final artifacts = <ProfileArtifactInput>[
        ProfileArtifactInput(
          fileName: platformFile.name,
          category: 'resume_upload',
          mimeType: _mimeTypeForExtension(extension),
          bytes: platformFile.bytes!,
        ),
      ];

      // Read/scan the uploaded resume through the Gemini key pool first, then
      // transfer whatever values it extracted into the NSRP form below.
      final extractedProfile = await _previewResumeExtraction(artifacts);
      final nsrpIdentity = _nsrpIdentityFromExtraction(
        extractedProfile,
        identity,
      );

      if (mounted) {
        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (context) => PesoRegistrationWizard(
              initialValues: nsrpIdentity,
              verifiedResumeSex: verifiedResumeSex(extractedProfile),
              onComplete: (pesoPayload) {
                final pesoFormData = _asStringMap(pesoPayload['formData']);
                final pesoText = _aiTextFromPayload(pesoPayload);
                final pesoArtifact = ProfileArtifactInput.fromBridgePayload(
                  pesoPayload['artifact'],
                );
                if (pesoArtifact != null) artifacts.add(pesoArtifact);

                navigator.pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => AIProcessingScreen(
                      artifacts: List<ProfileArtifactInput>.unmodifiable(
                        artifacts,
                      ),
                      rawTextData: pesoText,
                      resumeData: <String, dynamic>{
                        'documentType': 'Uploaded Resume',
                        'fileName': platformFile.name,
                        'fileExtension': extension,
                      },
                      pesoFormData: pesoFormData,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }
    }
  }

  void _requireRegistrationVerification(
    RegistrationVerificationRequest request,
  ) {
    setState(() {
      _verificationRequest = request;
      _registrationIdentity = request.identity;
      _verificationEmail = request.identity['email'] ?? '';
      _verificationForRegistration = true;
      _verificationEmailSent = request.verificationEmailSent;
      _verificationEmailError = request.verificationEmailError;
      _currentView = AuthView.emailVerification;
    });
  }

  void _requireLoginVerification(String email) {
    setState(() {
      _verificationRequest = null;
      _verificationEmail = email;
      _verificationForRegistration = false;
      _verificationEmailSent = false;
      _verificationEmailError = null;
      _currentView = AuthView.emailVerification;
    });
  }

  Future<void> _resendVerificationEmail() async {
    try {
      await AuthService.sendEmailVerification();
      if (mounted) {
        setState(() {
          _verificationEmailSent = true;
          _verificationEmailError = null;
        });
        AppToast.success(context, 'A new verification email has been sent.');
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _verificationEmailSent = false;
          _verificationEmailError = error.toString();
        });
        AppToast.error(
          context,
          'Could not send the verification email: $error',
        );
      }
    }
  }

  Future<void> _checkEmailVerification() async {
    if (_verificationBusy) return;
    setState(() => _verificationBusy = true);
    try {
      final isVerified = await AuthService.reloadCurrentUserVerification();
      if (!mounted) return;
      if (!isVerified) {
        AppToast.warning(
          context,
          'Your email is not verified yet. Open the link in your inbox, then check again.',
        );
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw StateError('No signed-in account was found.');
      await AuthService.ensureUserProfile(
        user,
        firstName: _registrationIdentity['firstName'],
        lastName: _registrationIdentity['lastName'],
        phoneNumber: _registrationIdentity['phone'],
        municipality: _registrationIdentity['municipality'],
        barangay: _registrationIdentity['barangay'],
        address: _registrationIdentity['address'],
      );

      if (_verificationForRegistration) {
        if ((_registrationIdentity['barangay'] ?? '').isNotEmpty) {
          await PesoApiClient.updateProfile({
            'municipality': 'Montalban',
            'barangay': _registrationIdentity['barangay'],
            'address': _registrationIdentity['address'] ?? '',
          });
        }
        await ApplicantDraftService.clear(registrationDraftScope(), 'registration');
        await _saveRegistrationAvatar(_verificationRequest);
        if (!mounted) return;
        setState(() {
          _verificationRequest = null;
          _currentView = AuthView.onboarding;
        });
      } else {
        await _openVerifiedUserArea();
      }
    } catch (error) {
      if (mounted) {
        AppToast.error(context, 'Could not verify your email: $error');
      }
    } finally {
      if (mounted) setState(() => _verificationBusy = false);
    }
  }

  Future<void> _saveRegistrationAvatar(
    RegistrationVerificationRequest? request,
  ) async {
    if (request == null ||
        (request.photoBytes == null && request.avatarStyle == 'person')) {
      return;
    }
    try {
      if (request.photoBytes != null) {
        await PesoApiClient.uploadArtifact(
          fileName: request.photoName ?? 'profile.jpg',
          category: 'profile_photo',
          mimeType: (request.photoName ?? '').toLowerCase().endsWith('.png')
              ? 'image/png'
              : 'image/jpeg',
          bytes: request.photoBytes!,
        );
      } else {
        await PesoApiClient.updateProfile({'avatarStyle': request.avatarStyle});
      }
    } catch (error) {
      if (mounted) {
        AppToast.warning(
          context,
          'Your account is verified, but the profile image could not be saved: $error',
        );
      }
    }
  }

  Future<void> _openVerifiedUserArea() async {
    final role = await AuthService.getCurrentUserRole();
    if (!mounted) return;
    var openAdmin = false;
    if (shouldOpenAdminArea(role)) {
      final choice = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Admin debug'),
          content: const Text('Choose your PESO workspace. Admin features still require server authorization.'),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext, 'user'),
              child: const Text('Login as User'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, 'admin'),
              child: const Text('Login as Admin'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      openAdmin = choice == 'admin';
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) =>
          openAdmin ? const AdminDashboard() : const UserProfile()),
    );
  }

  /// Registration data inherited by the resume builder, the AI extractor, and
  /// the NSRP form. Values captured by the register form are preferred; when
  /// they are missing (for example after a Google sign-up), they are resolved
  /// from the authenticated PESO profile and the Firebase account.
  Future<Map<String, String>> _resolveRegistrationIdentity() async {
    final captured = _registrationIdentity;
    if ((captured['firstName'] ?? '').trim().isNotEmpty ||
        (captured['lastName'] ?? '').trim().isNotEmpty ||
        (captured['email'] ?? '').trim().isNotEmpty) {
      return captured;
    }

    var firstName = '';
    var lastName = '';
    var email = '';
    var phone = '';

    try {
      final profile = await AuthService.getCurrentUserProfile();
      firstName = (profile['firstName'] as String? ?? '').trim();
      lastName = (profile['lastName'] as String? ?? '').trim();
      email = (profile['email'] as String? ?? '').trim();
      phone = (profile['phoneNumber'] as String? ?? '').trim();
    } catch (error) {
      debugPrint('[ONBOARDING] PESO profile lookup unavailable ($error).');
    }

    try {
      if (Firebase.apps.isNotEmpty) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          if (email.isEmpty) email = (user.email ?? '').trim();
          if (phone.isEmpty) phone = (user.phoneNumber ?? '').trim();
          if (firstName.isEmpty && lastName.isEmpty) {
            final parts = (user.displayName ?? '')
                .trim()
                .split(RegExp(r'\s+'))
                .where((part) => part.isNotEmpty)
                .toList();
            if (parts.isNotEmpty) {
              firstName = parts.first;
              lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
            }
          }
        }
      }
    } catch (error) {
      debugPrint(
        '[ONBOARDING] Firebase identity fallback unavailable ($error).',
      );
    }

    final resolved = <String, String>{
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
    };
    _registrationIdentity = resolved;
    return resolved;
  }

  @override
  Widget build(BuildContext context) {
    final Color pesoGreen = const Color(0xFF236349);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              children: [
                const SizedBox(height: 90),
                _buildHeroAndSlidingAuthCard(pesoGreen),
                GlobalFooter(
                  pesoGreen: pesoGreen,
                  onTabSelected: (index) => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LandingPage()),
                  ),
                  onScrollToTop: () => _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                  ),
                ),
              ],
            ),
          ),
          _buildStickyHeader(pesoGreen),
        ],
      ),
    );
  }

  Widget _buildStickyHeader(Color pesoGreen) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      top: 0,
      left: 0,
      right: 0,
      child: GlobalNavBar(
        pesoGreen: pesoGreen,
        activePageIndex: -1,
        onRegisterTap: () => setState(() => _currentView = AuthView.register),
        onLoginTap: () => setState(() => _currentView = AuthView.login),
        onTabSelected: (index) => Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LandingPage()),
        ),
      ),
    );
  }

  Widget _buildHeroAndSlidingAuthCard(Color pesoGreen) {
    final width = MediaQuery.sizeOf(context).width;
    final narrow = width < 980;
    final isLogin = _currentView == AuthView.login;
    final isLight = !isLogin;
    final showHero = isLogin && !narrow;
    final compact = width < 600;
    Widget introduction({bool insideCard = false}) => Column(
      crossAxisAlignment: insideCard
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF2C8663).withValues(alpha: 0.23),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: const Color(0xFF51D6A0).withValues(alpha: 0.32),
            ),
          ),
          child: const Text(
            'PESO MONTALBAN DIGITAL',
            style: TextStyle(
              color: Color(0xFF72EDB6),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ),
        SizedBox(height: insideCard ? 15 : 25),
        Text(
          'Your Gateway to\nLocal Opportunities.',
          textAlign: insideCard ? TextAlign.center : TextAlign.left,
          style: TextStyle(
            fontSize: insideCard ? (compact ? 23 : 27) : 43,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1.13,
          ),
        ),
        SizedBox(height: insideCard ? 9 : 22),
        Text(
          insideCard
              ? 'Explore local jobs, discover your strengths, and plan your next career step.'
              : 'Discover AI-matched local jobs, review your qualifications, and plan your next steps with PESO and TESDA.',
          textAlign: insideCard ? TextAlign.center : TextAlign.left,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: insideCard ? 13 : 16,
            height: 1.6,
          ),
        ),
      ],
    );
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        minHeight: MediaQuery.sizeOf(context).height - 90,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF07160F), Color(0xFF103F2C), Color(0xFF071B14)],
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : (narrow ? 28 : 50),
        vertical: compact ? 28 : 56,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1160),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (showHero) ...[
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 56),
                    child: introduction(),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Flexible(
                flex: showHero ? 0 : 1,
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: isLogin ? 470 : 580,
                    padding: EdgeInsets.all(compact ? 23 : 38),
                    decoration: BoxDecoration(
                      color: isLight ? Colors.white : const Color(0xFF183A2D),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: isLight
                            ? const Color(0xFFE0E6E2)
                            : const Color(0xFF436A58),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .20),
                          blurRadius: 35,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (isLogin && narrow) ...[
                          introduction(insideCard: true),
                          const SizedBox(height: 27),
                          Divider(color: Colors.white.withValues(alpha: .17)),
                          const SizedBox(height: 20),
                        ],
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: KeyedSubtree(
                            key: ValueKey<AuthView>(_currentView),
                            child: _buildCurrentAuthView(pesoGreen, isLight),
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
      ),
    );
  }

  Widget _buildCurrentAuthView(Color pesoGreen, bool isLight) {
    switch (_currentView) {
      case AuthView.login:
        return LoginForm(
          pesoGreen: pesoGreen,
          isLight: isLight,
          onSwitchToRegister: () =>
              setState(() => _currentView = AuthView.register),
          onEmailVerificationRequired: _requireLoginVerification,
        );
      case AuthView.register:
        return RegisterForm(
          pesoGreen: pesoGreen,
          isLight: isLight,
          onSwitchToLogin: () => setState(() => _currentView = AuthView.login),
          onEmailVerificationRequired: _requireRegistrationVerification,
          onProceedToOnboarding: (identity) => setState(() {
            _registrationIdentity = identity;
            _currentView = AuthView.onboarding;
          }),
        );
      case AuthView.emailVerification:
        return _buildEmailVerificationView(pesoGreen, isLight);
      case AuthView.onboarding:
        return _buildOnboardingView(pesoGreen, isLight);
    }
  }

  Widget _buildEmailVerificationView(Color pesoGreen, bool isLight) {
    final textColor = isLight ? Colors.black87 : Colors.white;
    final mutedColor = isLight ? Colors.black54 : Colors.white70;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.mark_email_read_outlined, color: pesoGreen, size: 56),
        const SizedBox(height: 18),
        Text(
          'Verify your email first',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: textColor,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _verificationEmailSent
              ? 'We sent a verification link to'
              : 'Email verification is required for',
          textAlign: TextAlign.center,
          style: TextStyle(color: mutedColor, fontSize: 15),
        ),
        const SizedBox(height: 4),
        Text(
          _verificationEmail,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        if (_verificationEmailError != null) ...[
          Text(
            'We could not send the verification email. $_verificationEmailError',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent, height: 1.4),
          ),
          const SizedBox(height: 10),
        ],
        Text(
          _verificationEmailSent
              ? 'Open the link in your inbox, then come back here. You can continue only after the address is verified.'
              : 'Open the verification link in your inbox, then come back here. If you need a new link, use the resend button below.',
          textAlign: TextAlign.center,
          style: TextStyle(color: mutedColor, height: 1.5),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _verificationBusy ? null : _checkEmailVerification,
          icon: _verificationBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.verified_user_outlined),
          label: const Text('I verified my email'),
          style: FilledButton.styleFrom(
            backgroundColor: pesoGreen,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _verificationBusy ? null : _resendVerificationEmail,
          child: const Text('Resend verification email'),
        ),
        TextButton(
          onPressed: _verificationBusy
              ? null
              : () async {
                  await AuthService.signOut();
                  if (!mounted) return;
                  setState(() {
                    _verificationRequest = null;
                    _registrationIdentity = const <String, String>{};
                    _currentView = _verificationForRegistration
                        ? AuthView.register
                        : AuthView.login;
                  });
                },
          child: const Text('Use a different account'),
        ),
      ],
    );
  }

  Widget _buildOnboardingView(Color pesoGreen, bool isLight) {
    Color textColor = isLight ? Colors.black87 : Colors.white;
    Color subtitleColor = isLight ? Colors.black54 : Colors.white70;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 30,
              height: 4,
              decoration: BoxDecoration(
                color: pesoGreen,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 30,
              height: 4,
              decoration: BoxDecoration(
                color: pesoGreen,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Icon(Icons.description_outlined, color: Colors.green, size: 50),
        const SizedBox(height: 15),
        Text(
          'Resume Data Source',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: textColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          'Our AI engine needs your professional data. Choose how you want to provide your resume before proceeding to the PESO form.',
          style: TextStyle(color: subtitleColor, fontSize: 15, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 35),

        Row(
          children: [
            Expanded(
              child: _buildResumeChoiceCard(
                'upload',
                Icons.upload_file,
                'Read/Scan Resume',
                'Let AI read your existing file',
                pesoGreen,
                isLight,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildResumeChoiceCard(
                'build',
                Icons.auto_awesome_mosaic,
                'Resume Builder',
                'Create a new design in-app',
                pesoGreen,
                isLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),

        ElevatedButton(
          onPressed: _completeOnboarding,
          style: ElevatedButton.styleFrom(
            backgroundColor: pesoGreen,
            padding: const EdgeInsets.symmetric(vertical: 22),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Proceed to Next Step',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResumeChoiceCard(
    String type,
    IconData icon,
    String title,
    String subtitle,
    Color pesoGreen,
    bool isLight,
  ) {
    bool isSelected = _selectedResumeType == type;
    Color activeBg = isLight
        ? pesoGreen.withValues(alpha: 0.1)
        : pesoGreen.withValues(alpha: 0.15);
    Color inactiveBg = isLight
        ? Colors.grey.shade100
        : Colors.white.withValues(alpha: 0.03);
    Color borderColor = isLight
        ? Colors.grey.shade300
        : Colors.white.withValues(alpha: 0.1);
    Color textColor = isLight ? Colors.black87 : Colors.white;

    return GestureDetector(
      onTap: () => setState(() => _selectedResumeType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 15),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : inactiveBg,
          border: Border.all(
            color: isSelected ? pesoGreen : borderColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 36,
              color: isSelected
                  ? Colors.green
                  : (isLight ? Colors.black38 : Colors.white38),
            ),
            const SizedBox(height: 15),
            Text(
              title,
              style: TextStyle(
                color: isSelected
                    ? (isLight ? Colors.green.shade800 : Colors.white)
                    : textColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected
                    ? Colors.green.withValues(alpha: 0.8)
                    : (isLight ? Colors.black54 : Colors.white38),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Scanning feedback follows the actual Gemini request. The slowly advancing
/// bar is an *estimate* until the API reports completion (100%). This avoids
/// claiming precise upload or inference progress the Gemini API does not give.
class _ResumeAnalysisDialog extends StatelessWidget {
  const _ResumeAnalysisDialog({required this.progress});

  final ValueListenable<double> progress;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 22),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: ValueListenableBuilder<double>(
              valueListenable: progress,
              builder: (context, value, _) {
                final complete = value >= 1.0;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9F5EF),
                        borderRadius: BorderRadius.circular(19),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(17),
                        child: Icon(
                          complete
                              ? Icons.check_circle_rounded
                              : Icons.document_scanner_rounded,
                          size: 36,
                          color: const Color(0xFF236349),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      complete
                          ? 'Resume scan completed'
                          : 'Reading your resume',
                      style: const TextStyle(
                        color: Color(0xFF17352B),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      complete
                          ? 'Your extracted information is ready for review in the NSRP form.'
                          : 'Securely extracting information for your applicant profile.',
                      style: const TextStyle(
                        color: Color(0xFF52675D),
                        fontSize: 13,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 23),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(end: value),
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeOutCubic,
                      builder: (context, animated, _) => ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LinearProgressIndicator(
                          value: animated,
                          minHeight: 11,
                          backgroundColor: const Color(0xFFE3EDE7),
                          color: const Color(0xFF20835F),
                          semanticsLabel: complete
                              ? 'Resume scan complete'
                              : 'Resume scan in progress',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          complete ? 'Complete' : 'Analyzing document',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF236349),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          complete ? '100%' : 'Working…',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF52675D),
                          ),
                        ),
                      ],
                    ),
                    if (!complete) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Progress is estimated until the AI service responds. Please keep this page open.',
                        style: TextStyle(
                          color: Color(0xFF778C81),
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
