import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart'; // NEW IMPORT

import '../peso_logic/peso_ai_engine.dart'; // NEW IMPORT
import 'admin_ui.dart';
import 'user_ui.dart';
import 'landingpage_ui.dart';
import 'reusable_ui.dart';
import 'resumebuilder_ui.dart';

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
  int _selectedRoleIndex = 0; // 0: Job Seeker, 1: IT Admin
  bool _obscurePassword = true;
  bool _isLoading = false;

  // --- TEXT CONTROLLERS ---
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _adminCodeController = TextEditingController();

  // Onboarding Selection
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
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _adminCodeController.dispose();
    super.dispose();
  }

  // ==========================================
  // LOGIC: REGISTRATION
  // ==========================================
  Future<void> _registerUser() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError('Email and Password are required.');
      return;
    }

    if (_selectedRoleIndex == 1 && _adminCodeController.text != 'PESO2026') {
      _showError('Invalid System Access Code for IT Admin.');
      return;
    }

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 2)); // Simulating API

    if (mounted) {
      if (_selectedRoleIndex == 0) {
        // Job Seeker moves to AI Onboarding Phase
        setState(() {
          _currentView = AuthView.onboarding;
          _isLoading = false;
        });
      } else {
        // Admin bypasses onboarding
        setState(() => _isLoading = false);
        _routeToDashboard();
      }
    }
  }

  // ==========================================
  // LOGIC: COMPLETE ONBOARDING (Resume Flow)
  // ==========================================
  Future<void> _completeOnboarding() async {
    if (_selectedResumeType == 'build') {
      setState(() => _isLoading = true);
      await Future.delayed(const Duration(seconds: 1)); // Simulate processing

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ResumeBuilderWizard(
              onComplete: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const UserProfile()),
                );
              },
            ),
          ),
        );
      }
    } else if (_selectedResumeType == 'upload') {
      // 1. Trigger the native file picker
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true, // Ensures file bytes are loaded into memory for parsing
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() => _isLoading = true);

        try {
          final platformFile = result.files.single;

          // 2. Pass the bytes directly to Gemini
          final extractedData = await PesoAIEngine.parseResume(
            platformFile.bytes!,
            platformFile.extension ?? 'pdf',
          );

          // Print it to the debug console so you can verify it worked
          print('Extracted by Gemini: $extractedData');

          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('AI Extraction Complete! Profile populated.'),
                backgroundColor: Color(0xFF2E7D32),
              ),
            );

            // 3. Route to Profile
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const UserProfile()),
            );
          }
        } catch (e) {
          if (mounted) {
            setState(() => _isLoading = false);
            _showError('AI Parsing Failed: $e');
          }
        }
      }
    }
  }

  // ==========================================
  // LOGIC: LOGIN
  // ==========================================
  Future<void> _loginUser() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      return;
    }

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() => _isLoading = false);
      _routeToDashboard();
    }
  }

  void _routeToDashboard() {
    if (_selectedRoleIndex == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AdminDashboard()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const UserProfile()),
      );
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
    bool isLight = !isLogin; // Light mode for Register & Onboarding

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
            // Background Text Information
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
                          'Log in to take AI-generated technical exams or access your TESDA upskilling action plans. Built exclusively for Montalban residents.',
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

            // Sliding Glassmorphism Auth Card (Dynamic Light/Dark)
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
                      width: isLogin
                          ? 480
                          : 580, // Slightly wider for light mode forms
                      padding: const EdgeInsets.all(45),
                      decoration: BoxDecoration(
                        color: isLight
                            ? Colors.white.withValues(
                                alpha: 0.95,
                              ) // Light Mode Frosted
                            : Colors.black.withValues(
                                alpha: 0.7,
                              ), // Dark Mode Frosted
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: isLight
                              ? Colors.grey.shade300
                              : Colors.white.withValues(alpha: 0.15),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
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
        return _buildLoginView(pesoGreen, isLight);
      case AuthView.register:
        return _buildRegisterView(pesoGreen, isLight);
      case AuthView.onboarding:
        return _buildOnboardingView(pesoGreen, isLight);
    }
  }

  // ==========================================
  // 1. LOGIN VIEW (Dark Mode by default)
  // ==========================================
  Widget _buildLoginView(Color pesoGreen, bool isLight) {
    Color textColor = Colors.white;
    Color subtitleColor = Colors.white54;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Welcome Back',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: textColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 5),
        Text(
          'Access your PESO JobKonek portal',
          style: TextStyle(color: subtitleColor, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 35),

        _buildRoleSelector(pesoGreen, isLight),
        const SizedBox(height: 30),

        _buildModernTextField(
          'Email Address',
          Icons.email_outlined,
          false,
          pesoGreen,
          isLight,
          controller: _emailController,
        ),
        const SizedBox(height: 20),
        _buildModernTextField(
          'Password',
          Icons.lock_outline,
          true,
          pesoGreen,
          isLight,
          controller: _passwordController,
        ),
        const SizedBox(height: 15),

        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {},
            child: Text(
              'Forgot Password?',
              style: TextStyle(
                color: subtitleColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 15),

        ElevatedButton(
          onPressed: _isLoading ? null : _loginUser,
          style: ElevatedButton.styleFrom(
            backgroundColor: pesoGreen,
            padding: const EdgeInsets.symmetric(vertical: 22),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
              : const Text(
                  'Secure Login',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
        const SizedBox(height: 30),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Don't have an account? ",
              style: TextStyle(color: Colors.white70, fontSize: 15),
            ),
            GestureDetector(
              onTap: () => setState(() => _currentView = AuthView.register),
              child: Text(
                'Register Here',
                style: TextStyle(
                  color: Colors.greenAccent[400],
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // 2. REGISTRATION VIEW (Light Mode)
  // ==========================================
  Widget _buildRegisterView(Color pesoGreen, bool isLight) {
    bool isAdmin = _selectedRoleIndex == 1;
    Color textColor = isLight ? Colors.black87 : Colors.white;
    Color subtitleColor = isLight ? Colors.black54 : Colors.white54;

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
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Create Account',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: textColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 5),
        Text(
          isAdmin
              ? 'Secure System Admin Registration'
              : 'Step 1: Basic Information',
          style: TextStyle(color: subtitleColor, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 30),

        _buildRoleSelector(pesoGreen, isLight),
        const SizedBox(height: 30),

        if (isAdmin) ...[
          Container(
            padding: const EdgeInsets.all(15),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.1),
              border: Border.all(
                color: Colors.redAccent.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                const Icon(Icons.security, color: Colors.redAccent),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                    'Authorized PESO Staff Only. Requires internal access code.',
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildModernTextField(
            'System Access Code',
            Icons.key,
            true,
            pesoGreen,
            isLight,
            controller: _adminCodeController,
          ),
          const SizedBox(height: 15),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: _buildModernTextField(
                  'First Name',
                  Icons.person_outline,
                  false,
                  pesoGreen,
                  isLight,
                  controller: _firstNameController,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildModernTextField(
                  'Last Name',
                  null,
                  false,
                  pesoGreen,
                  isLight,
                  controller: _lastNameController,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
        ],

        _buildModernTextField(
          'Email Address',
          Icons.email_outlined,
          false,
          pesoGreen,
          isLight,
          controller: _emailController,
        ),
        const SizedBox(height: 15),

        if (!isAdmin) ...[
          _buildModernTextField(
            'Phone Number',
            Icons.phone_android,
            false,
            pesoGreen,
            isLight,
            controller: _phoneController,
            prefixText: '+63 ',
          ),
          const SizedBox(height: 15),
        ],

        _buildModernTextField(
          'Password',
          Icons.lock_outline,
          true,
          pesoGreen,
          isLight,
          controller: _passwordController,
        ),
        const SizedBox(height: 30),

        ElevatedButton(
          onPressed: _isLoading ? null : _registerUser,
          style: ElevatedButton.styleFrom(
            backgroundColor: pesoGreen,
            padding: const EdgeInsets.symmetric(vertical: 22),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
              : Text(
                  isAdmin
                      ? 'Register Admin'
                      : 'Continue to upload resume or create resume',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
        const SizedBox(height: 25),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Already have an account? ",
              style: TextStyle(color: subtitleColor, fontSize: 15),
            ),
            GestureDetector(
              onTap: () => setState(() => _currentView = AuthView.login),
              child: Text(
                'Login Here',
                style: TextStyle(
                  color: pesoGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // 3. ONBOARDING VIEW (Resume Builder/Uploader)
  // ==========================================
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
          onPressed: _isLoading ? null : _completeOnboarding,
          style: ElevatedButton.styleFrom(
            backgroundColor: pesoGreen,
            padding: const EdgeInsets.symmetric(vertical: 22),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
              : const Text(
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

  // --- SHARED DESIGNER UI HELPERS ---
  Widget _buildRoleSelector(Color pesoGreen, bool isLight) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isLight
            ? Colors.grey.shade200
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isLight
              ? Colors.grey.shade300
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          _buildRoleTab('Job Seeker', Icons.person, 0, pesoGreen, isLight),
          _buildRoleTab(
            'IT Admin',
            Icons.admin_panel_settings,
            1,
            pesoGreen,
            isLight,
          ),
        ],
      ),
    );
  }

  Widget _buildRoleTab(
    String title,
    IconData icon,
    int index,
    Color pesoGreen,
    bool isLight,
  ) {
    bool isSelected = _selectedRoleIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRoleIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? pesoGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: pesoGreen.withValues(alpha: 0.4),
                      blurRadius: 10,
                    ),
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? Colors.white
                    : (isLight ? Colors.black54 : Colors.white54),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : (isLight ? Colors.black87 : Colors.white54),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernTextField(
    String hint,
    IconData? icon,
    bool isPassword,
    Color pesoGreen,
    bool isLight, {
    TextEditingController? controller,
    String? prefixText,
  }) {
    Color fieldBg = isLight
        ? Colors.grey.shade100
        : Colors.white.withValues(alpha: 0.05);
    Color borderColor = isLight
        ? Colors.grey.shade300
        : Colors.white.withValues(alpha: 0.1);
    Color textColor = isLight ? Colors.black87 : Colors.white;
    Color hintColor = isLight ? Colors.black38 : Colors.white38;

    return TextField(
      controller: controller,
      obscureText: isPassword && _obscurePassword,
      style: TextStyle(color: textColor, fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: hintColor),
        prefixText: prefixText,
        prefixStyle: TextStyle(
          color: textColor,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        prefixIcon: icon != null
            ? Icon(icon, color: hintColor, size: 22)
            : null,
        filled: true,
        fillColor: fieldBg,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 20,
          horizontal: 20,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: pesoGreen, width: 2),
        ),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: hintColor,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              )
            : null,
      ),
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
