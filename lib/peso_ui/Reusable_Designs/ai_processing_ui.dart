import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../peso_logic/peso_ai_engine.dart';
import '../../peso_models/profile_artifact.dart';
import '../../peso_services/auth_service.dart';
import '../../peso_services/profile_artifact_service.dart';
import '../User/user_ui.dart';

class AIProcessingScreen extends StatefulWidget {
  final List<ProfileArtifactInput> artifacts;
  final String? rawTextData;
  final Map<String, dynamic> resumeData;
  final Map<String, dynamic> pesoFormData;

  const AIProcessingScreen({
    super.key,
    this.artifacts = const <ProfileArtifactInput>[],
    this.rawTextData,
    this.resumeData = const <String, dynamic>{},
    this.pesoFormData = const <String, dynamic>{},
  });

  @override
  State<AIProcessingScreen> createState() => _AIProcessingScreenState();
}

class _AIProcessingScreenState extends State<AIProcessingScreen>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _pulseController;

  int _thoughtIndex = 0;

  final List<String> _aiThoughts = [
    "Initializing gemini-3.6-flash engine...",
    "Scanning document structure and formatting...",
    "Extracting core competencies and technical skills...",
    "Calculating estimated years of professional experience...",
    "Drafting bilingual professional bio (Tagalog/English)...",
    "Formatting data for DOLE SPRS compliance...",
    "Bypassing heavy server traffic... please wait...",
    "Re-establishing secure API connection...",
    "Finalizing AI Profile (Almost there)...",
  ];

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    );

    _processData();
  }

  void _nextThought() {
    if (mounted && _thoughtIndex < _aiThoughts.length - 1) {
      setState(() => _thoughtIndex++);
    }
  }

  Future<void> _processData() async {
    try {
      _progressController.forward();
      await Future<void>.delayed(const Duration(milliseconds: 700));
      _nextThought();

      // Persist React's structured source data first so a temporary Gemini
      // outage cannot make a completed resume or NSRP form disappear.
      final persistenceWarnings = <String>[];
      try {
        await AuthService.saveOnboardingData(
          resumeData: widget.resumeData,
          pesoFormData: widget.pesoFormData,
          onboardingText: widget.rawTextData,
        );
      } catch (error) {
        persistenceWarnings.add('Form/profile source data could not be saved: $error');
        debugPrint('[PROFILE] Source data could not be saved: $error');
      }

      // PDFs/images are stored in private Cloud Storage; Firestore stores only
      // file metadata and the Storage path. Keep going if Storage is not ready.
      try {
        final artifactResult = await ProfileArtifactService.saveArtifacts(widget.artifacts);
        persistenceWarnings.addAll(artifactResult.warnings);
      } catch (error) {
        persistenceWarnings.add('Document files could not be saved: $error');
        debugPrint('[PROFILE] Document file save failed: $error');
      }

      // Run AI after the form and document have been saved. Only an original
      // uploaded resume is sent as binary; Resume Builder fields are sent as
      // edited text, and the NSRP PDF is excluded for identifier privacy.
      final apiTask = PesoAIEngine.generateProfile(
        artifacts: widget.artifacts,
        rawText: widget.rawTextData,
      );
      _cycleThoughtsRepeatedly();
      final finalAiData = await apiTask;
      debugPrint('[PESO AI] Profile extraction complete.');

      try {
        await AuthService.saveAiProfile(finalAiData);
      } catch (error) {
        persistenceWarnings.add('AI profile could not be saved to Firestore: $error');
        debugPrint('[PROFILE] AI profile could not be saved: $error');
      }

      if (!mounted) return;
      setState(() => _thoughtIndex = _aiThoughts.length - 1);
      _progressController.duration = const Duration(milliseconds: 400);
      await _progressController.forward(from: _progressController.value);

      final messenger = ScaffoldMessenger.of(context);
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              UserProfile(aiProfileData: finalAiData),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );

      if (persistenceWarnings.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                'AI profile generated, but some data/files were not saved:\n${persistenceWarnings.join('\n')}',
              ),
              backgroundColor: Colors.orange.shade800,
              duration: const Duration(seconds: 10),
            ),
          );
        });
      }
    } catch (error, stackTrace) {
      debugPrint('[PESO AI] Processing failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      _progressController.stop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AI processing failed: $error'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  void _cycleThoughtsRepeatedly() async {
    while (mounted && _progressController.isAnimating) {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted || !_progressController.isAnimating) return;

      if (_thoughtIndex < 5) {
        _nextThought();
      } else if (_thoughtIndex >= 5 && _thoughtIndex < _aiThoughts.length - 2) {
        _nextThought();
      } else {
        setState(() {
          _thoughtIndex = _thoughtIndex == 6 ? 7 : 6;
        });
      }
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color pesoGreen = const Color(0xFF2E7D32);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.black,
                  pesoGreen.withValues(alpha: 0.2),
                  Colors.black,
                ],
              ),
            ),
          ),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  width: 500,
                  padding: const EdgeInsets.all(50),
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
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Container(
                            padding: const EdgeInsets.all(25),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: pesoGreen.withValues(
                                alpha: 0.1 + (_pulseController.value * 0.2),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: pesoGreen.withValues(
                                    alpha: _pulseController.value * 0.5,
                                  ),
                                  blurRadius: 30,
                                  spreadRadius: 10,
                                ),
                              ],
                              border: Border.all(
                                color: pesoGreen.withValues(alpha: 0.5),
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.psychology,
                              size: 60,
                              color: Colors.greenAccent,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 40),
                      AnimatedBuilder(
                        animation: _progressController,
                        builder: (context, child) {
                          return Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: _progressController.value,
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
                                '${(_progressController.value * 100).toInt()}%',
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
                            _aiThoughts[_thoughtIndex],
                            key: ValueKey<int>(_thoughtIndex),
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
