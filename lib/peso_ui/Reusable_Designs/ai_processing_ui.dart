import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../peso_services/app_toast.dart';

import '../../peso_logic/peso_ai_engine.dart';
import '../../peso_logic/onboarding_ai_evidence.dart';
import '../../peso_models/profile_artifact.dart';
import '../../peso_services/auth_service.dart';
import '../../peso_services/onboarding_draft_sync.dart';
import '../../peso_services/applicant_draft_service.dart';
import '../../peso_services/profile_artifact_service.dart';
import '../User/user_ui.dart';

typedef OnboardingSourceSaver = Future<void> Function({
  Map<String, dynamic>? resumeData,
  Map<String, dynamic>? pesoFormData,
  String? onboardingText,
});

typedef OnboardingExtractor = Future<Map<String, dynamic>> Function({
  required List<ProfileArtifactInput> artifacts,
  String? rawText,
  bool persist,
});

/// Injectable task-specific dependencies; widget tests never access auth or
/// network services. The production pathway keeps the existing API calls.
class AIProcessingServices {
  const AIProcessingServices({
    required this.saveSources,
    required this.saveDocuments,
    required this.extractProfile,
  });

  final OnboardingSourceSaver saveSources;
  final Future<ProfileArtifactSaveResult> Function(List<ProfileArtifactInput>)
  saveDocuments;
  final OnboardingExtractor extractProfile;

  factory AIProcessingServices.live() => AIProcessingServices(
    saveSources: AuthService.saveOnboardingData,
    saveDocuments: ProfileArtifactService.saveArtifacts,
    // POST /api/ai/profile already writes verified extraction metadata.
    // Do not duplicate that write via the legacy PATCH endpoint.
    extractProfile: PesoAIEngine.generateProfile,
  );
}

class AIProcessingOutcome {
  const AIProcessingOutcome({
    required this.aiProfile,
    required this.extractionUnavailable,
    required this.sourceSaved,
    required this.warnings,
  });
  final Map<String, dynamic>? aiProfile;
  final bool extractionUnavailable;
  final bool sourceSaved;
  final List<String> warnings;
}

class AIProcessingScreen extends StatefulWidget {
  final List<ProfileArtifactInput> artifacts;
  final AIProcessingServices? services;
  final Widget Function(BuildContext, AIProcessingOutcome)? profilePageBuilder;
  final String? rawTextData;
  final Map<String, dynamic> resumeData;
  final Map<String, dynamic> pesoFormData;

  const AIProcessingScreen({
    super.key,
    this.artifacts = const <ProfileArtifactInput>[],
    this.rawTextData,
    this.resumeData = const <String, dynamic>{},
    this.pesoFormData = const <String, dynamic>{},
    this.services,
    this.profilePageBuilder,
  });

  @override
  State<AIProcessingScreen> createState() => _AIProcessingScreenState();
}

class _AIProcessingScreenState extends State<AIProcessingScreen>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _pulseController;
  late AnimationController _orbitController;
  late AnimationController _ambientController;
  Timer? _thoughtTimer;
  bool _isFinishing = false;
  String? _errorMessage;

  int _thoughtIndex = 0;

  final List<String> _aiThoughts = const [
    'Getting your profile workspace ready...',
    'Reading your resume and NSRP details...',
    'Collecting skills, education, and experience...',
    'Finding strengths across your background...',
    'Connecting related information across documents...',
    'Preparing your professional summary...',
    'Bringing profile sections together...',
    'Almost ready - polishing your profile...',
    'Your AI profile is ready.',
  ];

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 65),
    );

    _processData();
  }

  void _startThoughtCycle() {
    _thoughtTimer?.cancel();
    _thoughtTimer = Timer.periodic(const Duration(milliseconds: 2600), (_) {
      if (!mounted || _thoughtIndex >= _aiThoughts.length - 1) return;
      setState(() {
        _thoughtIndex = (_thoughtIndex + 1) % (_aiThoughts.length - 1);
      });
    });
  }

  Future<void> _processData() async {
    try {
      _progressController.forward(from: 0);
      _startThoughtCycle();
      await Future<void>.delayed(const Duration(milliseconds: 450));

      // Persist React's structured source data first so a temporary Gemini
      // outage cannot make a completed resume or NSRP form disappear.
      final services = widget.services ?? AIProcessingServices.live();
      final persistenceWarnings = <String>[];
      var sourceSaved = false;
      var sourceConfirmedOnServer = false;
      try {
        await services.saveSources(
          resumeData: widget.resumeData,
          pesoFormData: widget.pesoFormData,
          onboardingText: widget.rawTextData,
        );
        sourceSaved = true;
        sourceConfirmedOnServer = true;
      } on OnboardingDraftQueuedException {
        sourceSaved = true;
        persistenceWarnings.add(
          'Your form is encrypted on this device and will sync when the connection returns.',
        );
      } on OnboardingDraftConflictException {
        persistenceWarnings.add(
          'Another device changed these form fields. Your local draft is preserved for review.',
        );
      } catch (error) {
        persistenceWarnings.add(
          'Form data could not be saved. Check your connection and save again.',
        );
        debugPrint('[PROFILE] Source save unavailable (${error.runtimeType}).');
      }

      // PDFs/images are stored privately in MongoDB GridFS through the PESO API.
      // Private document bytes must be stored before invoking Gemini.
      var documentsSaved = widget.artifacts.isEmpty;
      try {
        final artifactResult = await services.saveDocuments(widget.artifacts);
        persistenceWarnings.addAll(artifactResult.warnings);
        documentsSaved = artifactResult.warnings.isEmpty &&
            artifactResult.records.length == widget.artifacts.length;
      } catch (error) {
        persistenceWarnings.add(
          'Document files could not be saved. Please retry their upload.',
        );
        debugPrint('[PROFILE] Document save unavailable (${error.runtimeType}).');
      }

      // Remove encrypted resume/NSRP backups only after the server has
      // confirmed both the source record and all attached documents.
      if (sourceConfirmedOnServer && documentsSaved && widget.services == null &&
          Firebase.apps.isNotEmpty) {
        final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
        if (uid.isNotEmpty) {
          try {
            await ApplicantDraftService.clear(uid, 'resume');
            await ApplicantDraftService.clear(uid, 'nsrp');
          } catch (_) {
            // A storage cleanup failure does not invalidate persisted source.
          }
        }
      }

      // Always keep completed source forms. A failed Gemini call must never
      // strand a registered account or create an empty/fabricated AI profile.
      // Only explicitly job-relevant, non-identifier fields are sent as text.
      final safeEvidence = buildOnboardingAiEvidence(
        resumeData: widget.resumeData,
        pesoFormData: widget.pesoFormData,
        onboardingText: widget.rawTextData,
      );
      Map<String, dynamic>? finalAiData;
      var extractionUnavailable = false;
      try {
        if (!sourceSaved || !documentsSaved) {
          throw StateError(
              'Source input or documents must be saved before AI extraction.');
        }
        final extracted = await services.extractProfile(
          artifacts: widget.artifacts,
          rawText: safeEvidence,
          persist: true,
        );
        if (extracted.isEmpty) {
          throw const FormatException('No verified extraction available');
        }
        // The authenticated extraction route persisted this result and its
        // source-verification metadata atomically before responding.
        finalAiData = extracted;
        debugPrint('[PESO AI] Profile extraction completed.');
      } catch (error) {
        extractionUnavailable = true;
        debugPrint(
          '[PESO AI] Extraction unavailable (${error.runtimeType}); continuing with source forms.',
        );
      }

      _thoughtTimer?.cancel();
      if (!mounted) return;
      setState(() => _thoughtIndex = _aiThoughts.length - 1);
      _progressController.duration = const Duration(milliseconds: 450);
      await _progressController.forward(from: _progressController.value);
      if (!mounted) return;
      setState(() => _isFinishing = true);
      final outcome = AIProcessingOutcome(
        aiProfile: finalAiData,
        extractionUnavailable: extractionUnavailable,
        sourceSaved: sourceSaved,
        warnings: List<String>.unmodifiable(persistenceWarnings),
      );
      final noticeOverlay = Overlay.of(context, rootOverlay: true);
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              widget.profilePageBuilder?.call(context, outcome) ??
              UserProfile(
                newRegistration: true,
                aiProfileData: finalAiData,
                initialResumeData: widget.resumeData,
                initialPesoFormData: widget.pesoFormData,
                initialOnboardingText: widget.rawTextData,
                retryArtifacts: widget.artifacts,
                aiExtractionUnavailable: extractionUnavailable,
                onboardingSourcesSaved: sourceSaved,
              ),
          transitionDuration: const Duration(milliseconds: 520),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOut,
                ),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.97, end: 1).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                  child: child,
                ),
              ),
        ),
      );

      if (extractionUnavailable || persistenceWarnings.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          AppToast.showInOverlay(
            noticeOverlay,
            !sourceSaved
                ? 'Your form is available on this screen, but saving it failed. Please retry saving after your connection recovers.'
                : extractionUnavailable
                ? 'Your source forms are saved. AI extraction is unavailable; you can continue using your profile and retry later.'
                : 'Your profile is ready, but some documents or details need to be saved again.',
            kind: AppToastKind.warning,
            duration: const Duration(seconds: 10),
          );
        });
      }
    } catch (error) {
      _thoughtTimer?.cancel();
      debugPrint(
        '[PESO AI] Unexpected onboarding UI failure (${error.runtimeType}).',
      );
      if (!mounted) return;
      _progressController.stop();
      setState(() {
        _errorMessage = 'The profile could not be generated right now. Please check your connection and try again.';
      });
      AppToast.error(
        context,
        'Your profile could not be generated right now. Check your connection and try again.',
        duration: const Duration(seconds: 8),
      );
    }
  }

  @override
  void dispose() {
    _thoughtTimer?.cancel();
    _progressController.dispose();
    _pulseController.dispose();
    _orbitController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color pesoGreen = const Color(0xFF2E7D32);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < 600;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ambientController,
              builder: (context, child) {
                final t = _ambientController.value;
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(-1 + t * 0.55, -1),
                      end: Alignment(1 - t * 0.4, 1),
                      colors: [
                        Color.lerp(Colors.black, const Color(0xFF093820), t)!,
                        const Color(0xFF030A06),
                        Color.lerp(
                          const Color(0xFF03150B),
                          const Color(0xFF064328),
                          t,
                        )!,
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            left: -100,
            top: 30,
            child: _AmbientGlow(
              animation: _ambientController,
              size: 280,
              color: const Color(0xFF00C853),
            ),
          ),
          Positioned(
            right: -120,
            bottom: -70,
            child: _AmbientGlow(
              animation: _ambientController,
              size: 330,
              color: const Color(0xFF00BFA5),
              reverse: true,
            ),
          ),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  width: screenWidth < 600 ? screenWidth - 32 : 500,
                  padding: EdgeInsets.all(compact ? 20 : 50),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AIAbsorbingOrb(
                        pulseAnimation: _pulseController,
                        orbitAnimation: _orbitController,
                        primary: pesoGreen,
                        compact: compact,
                      ),
                      SizedBox(height: compact ? 22 : 28),
                      Text(
                        _errorMessage != null
                            ? 'We hit a connection snag'
                            : _isFinishing
                            ? 'Welcome to JobKonek!'
                            : 'Building your AI profile',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 24 : 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        _errorMessage != null
                            ? 'Please check your connection and try again.'
                            : _isFinishing
                            ? 'Your account is ready. Choose your preferred language and explore opportunities.'
                            : 'Turning your submitted details into a clearer picture of your skills and experience.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.68),
                          fontSize: compact ? 13 : 14,
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: compact ? 24 : 30),
                      AnimatedBuilder(
                        animation: _progressController,
                        builder: (context, child) {
                          return Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: _isFinishing
                                      ? 1.0
                                      : (_progressController.value * 0.92)
                                            .clamp(0.0, 0.92)
                                            .toDouble(),
                                  minHeight: 8,
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.1,
                                  ),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        Colors.greenAccent,
                                      ),
                                ),
                              ),
                              const SizedBox(height: 15),
                              Text(
                                '${_isFinishing ? 100 : (_progressController.value * 92).floor().clamp(0, 92)}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 30),
                      Container(
                        height: 50,
                        alignment: Alignment.center,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          transitionBuilder:
                              (Widget child, Animation<double> animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0.0, 0.5),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                          child: Text(
                            _errorMessage ?? _aiThoughts[_thoughtIndex],
                            key: ValueKey<String>(
                              _errorMessage ?? _thoughtIndex.toString(),
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                              fontStyle: FontStyle.italic,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AIAbsorbingOrb extends StatelessWidget {
  final Animation<double> pulseAnimation;
  final Animation<double> orbitAnimation;
  final Color primary;
  final bool compact;

  const AIAbsorbingOrb({
    super.key,
    required this.pulseAnimation,
    required this.orbitAnimation,
    required this.primary,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final dimension = compact ? 150.0 : 176.0;
    return SizedBox(
      key: const ValueKey<String>('ai-absorbing-orb'),
      width: dimension,
      height: dimension,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: dimension * 0.88,
            height: dimension * 0.88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
            ),
          ),
          RotationTransition(
            key: const ValueKey<String>('ai-orbiting-particles'),
            turns: orbitAnimation,
            child: SizedBox(
              width: dimension * 0.86,
              height: dimension * 0.86,
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: _OrbParticle(
                      color: const Color(0xFFB9F6CA),
                      size: 9,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _OrbParticle(
                      color: const Color(0xFF64FFDA),
                      size: 7,
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: _OrbParticle(color: Colors.white, size: 5),
                  ),
                ],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: pulseAnimation,
            builder: (context, child) {
              final t = pulseAnimation.value;
              return Transform.scale(
                scale: 0.94 + t * 0.09,
                child: Container(
                  width: dimension * 0.54,
                  height: dimension * 0.54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [primary, const Color(0xFF064323)],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.23),
                      width: 1.3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E676)
                            .withValues(alpha: 0.14 + t * 0.3),
                        blurRadius: 22 + t * 20,
                        spreadRadius: 2 + t * 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.psychology_alt_rounded,
                    color: Colors.white,
                    size: compact ? 42 : 50,
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: dimension * 0.12,
            right: dimension * 0.17,
            child: Icon(
              Icons.auto_awesome_rounded,
              size: compact ? 16 : 20,
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
          Positioned(
            left: dimension * 0.12,
            bottom: dimension * 0.15,
            child: const Icon(
              Icons.blur_on_rounded,
              size: 17,
              color: Color(0xFF64FFDA),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrbParticle extends StatelessWidget {
  final Color color;
  final double size;

  const _OrbParticle({required this.color, required this.size});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color,
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.65),
          blurRadius: 10,
          spreadRadius: 1,
        ),
      ],
    ),
  );
}

class _AmbientGlow extends StatelessWidget {
  final Animation<double> animation;
  final Color color;
  final double size;
  final bool reverse;

  const _AmbientGlow({
    required this.animation,
    required this.color,
    required this.size,
    this.reverse = false,
  });

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    builder: (context, child) {
      final t = animation.value;
      return Transform.translate(
        offset: Offset(
          (reverse ? -1 : 1) * t * 34,
          (reverse ? 1 : -1) * t * 24,
        ),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.025 + t * 0.025),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.08 + t * 0.06),
                blurRadius: 100,
                spreadRadius: 30,
              ),
            ],
          ),
        ),
      );
    },
  );
}
