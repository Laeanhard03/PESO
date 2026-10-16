import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';

import '../../peso_models/profile_artifact.dart';

// UI Imports from other directories
import '../Landingpage/landingpage_ui.dart';
import '../Reusable_Designs/reusable_ui.dart';
import '../Reusable_Designs/pesoform_ui.dart';
import '../Reusable_Designs/resumebuilder_ui.dart';
import '../Reusable_Designs/ai_processing_ui.dart';

// Sibling UI Imports
import 'login_ui.dart';
import 'register_ui.dart';

enum AuthView { login, register, onboarding }

class AuthPage extends StatefulWidget {
  final bool initialIsLogin;
  const AuthPage({super.key, this.initialIsLogin = true});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;
  late AuthView _currentView;

  String _selectedResumeType = 'upload'; // 'upload' or 'build'

  @override
  void initState() {
    super.initState();
    _currentView = widget.initialIsLogin ? AuthView.login : AuthView.register;

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

  Future<void> _completeOnboarding() async {
    final navigator = Navigator.of(context);
    if (_selectedResumeType == 'build') {
      final artifacts = <ProfileArtifactInput>[];
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (context) => ResumeBuilderWizard(
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
                    onComplete: (pesoPayload) {
                      final pesoFormData = _asStringMap(pesoPayload['formData']);
                      final pesoText = _aiTextFromPayload(pesoPayload);
                      final pesoArtifact = ProfileArtifactInput.fromBridgePayload(
                        pesoPayload['artifact'],
                      );
                      if (pesoArtifact != null) artifacts.add(pesoArtifact);

                      final supplementalText = <String>[
                        if (resumeText.isNotEmpty) '--- RESUME BUILDER ---\n$resumeText',
                        if (pesoText.isNotEmpty) '--- NSRP FORM (sensitive ID numbers removed) ---\n$pesoText',
                      ].join('\n\n');

                      navigator.pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => AIProcessingScreen(
                            artifacts: List<ProfileArtifactInput>.unmodifiable(artifacts),
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

      if (mounted) {
        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (context) => PesoRegistrationWizard(
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
                      artifacts: List<ProfileArtifactInput>.unmodifiable(artifacts),
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

  @override
  Widget build(BuildContext context) {
    final Color pesoGreen = const Color(0xFF2E7D32);

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
                    duration: const Duration(milliseconds: 500),
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
    bool isLogin = _currentView == AuthView.login;
    bool isLight = !isLogin;

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        minHeight: MediaQuery.of(context).size.height - 90,
      ),
      decoration: const BoxDecoration(
        color: Colors.black,
        image: DecorationImage(
          image: CachedNetworkImageProvider(
            'https://images.unsplash.com/photo-1497215728101-856f4ea42174?ixlib=rb-4.0.3&auto=format&fit=crop&w=1200&q=80',
          ),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.black.withValues(alpha: 0.95),
              pesoGreen.withValues(alpha: 0.5),
            ],
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 80),
        child: Stack(
          alignment: Alignment.center,
          children: [
            IgnorePointer(
              ignoring: !isLogin,
              child: AnimatedOpacity(
                opacity: isLogin ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 400),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 550,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: pesoGreen.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: pesoGreen.withValues(alpha: 0.5),
                            ),
                          ),
                          child: const Text(
                            'PESO MONTALBAN DIGITAL',
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 25),
                        const Text(
                          'Your Gateway to\nLocal Opportunities.',
                          style: TextStyle(
                            fontSize: 54,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 25),
                        const Text(
                          'Log in to discover AI-matched local job opportunities, view your skill qualification analysis, or access your TESDA upskilling action plans. Built exclusively for Montalban residents.',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white70,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            AnimatedAlign(
              alignment: isLogin ? Alignment.centerRight : Alignment.center,
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutExpo,
              child: AnimatedSize(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOutCubic,
                alignment: Alignment.topCenter,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: isLogin ? 480 : 580,
                      padding: const EdgeInsets.all(45),
                      decoration: BoxDecoration(
                        color: isLight
                            ? Colors.white.withValues(alpha: 0.95)
                            : Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: isLight
                              ? Colors.grey.shade300
                              : Colors.white.withValues(alpha: 0.15),
                          width: 1.5,
                        ),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: Container(
                          key: ValueKey<AuthView>(_currentView),
                          child: _buildCurrentAuthView(pesoGreen, isLight),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
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
        );
      case AuthView.register:
        return RegisterForm(
          pesoGreen: pesoGreen,
          isLight: isLight,
          onSwitchToLogin: () => setState(() => _currentView = AuthView.login),
          onProceedToOnboarding: () =>
              setState(() => _currentView = AuthView.onboarding),
        );
      case AuthView.onboarding:
        return _buildOnboardingView(pesoGreen, isLight);
    }
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
                'Upload PDF',
                'Let AI parse your existing file',
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
