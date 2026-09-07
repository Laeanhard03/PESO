import 'dart:ui';

import 'package:flutter/material.dart';

import 'admin_dashboard.dart';
import 'user_profile.dart';
import 'landing_page.dart';

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
  final TextEditingController _adminCodeController =
      TextEditingController(); // Security for Admin

  // Onboarding Controllers
  final TextEditingController _bioController = TextEditingController();
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
    _bioController.dispose();
    super.dispose();
  }

  // ==========================================
  // MOCK LOGIC: REGISTRATION
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
  // MOCK LOGIC: COMPLETE ONBOARDING
  // ==========================================
  Future<void> _completeOnboarding() async {
    if (_bioController.text.isEmpty) {
      _showError('Please write a short bio to configure your AI profile.');
      return;
    }

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() => _isLoading = false);
      _routeToDashboard();
    }
  }

  // ==========================================
  // MOCK LOGIC: LOGIN
  // ==========================================
  Future<void> _loginUser() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty)
      return;

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

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        minHeight: MediaQuery.of(context).size.height - 90,
      ),
      decoration: const BoxDecoration(
        color: Colors.black,
        image: DecorationImage(
          image: NetworkImage(
            'https://images.unsplash.com/photo-1497215728101-856f4ea42174?ixlib=rb-4.0.3&auto=format&fit=crop&w=1920&q=80',
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
            // Background Text Information (Fades out when registering)
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

            // Sliding Glassmorphism Auth Card
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
                    filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                    child: Container(
                      width: isLogin ? 480 : 550,
                      padding: const EdgeInsets.all(45),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: Container(
                          key: ValueKey<AuthView>(_currentView),
                          child: _buildCurrentAuthView(pesoGreen),
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

  Widget _buildCurrentAuthView(Color pesoGreen) {
    switch (_currentView) {
      case AuthView.login:
        return _buildLoginView(pesoGreen);
      case AuthView.register:
        return _buildRegisterView(pesoGreen);
      case AuthView.onboarding:
        return _buildOnboardingView(pesoGreen);
      default:
        return const SizedBox.shrink();
    }
  }

  // ==========================================
  // 1. LOGIN VIEW
  // ==========================================
  Widget _buildLoginView(Color pesoGreen) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Welcome Back',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 5),
        const Text(
          'Access your PESO JobKonek portal',
          style: TextStyle(color: Colors.white54, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 35),

        _buildRoleSelector(pesoGreen),
        const SizedBox(height: 30),

        _buildModernTextField(
          'Email Address',
          Icons.email_outlined,
          false,
          pesoGreen,
          controller: _emailController,
        ),
        const SizedBox(height: 20),
        _buildModernTextField(
          'Password',
          Icons.lock_outline,
          true,
          pesoGreen,
          controller: _passwordController,
        ),
        const SizedBox(height: 15),

        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {},
            child: const Text(
              'Forgot Password?',
              style: TextStyle(
                color: Colors.white54,
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
  // 2. REGISTRATION VIEW
  // ==========================================
  Widget _buildRegisterView(Color pesoGreen) {
    bool isAdmin = _selectedRoleIndex == 1;

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
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Create Account',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 5),
        Text(
          isAdmin
              ? 'Secure System Admin Registration'
              : 'Step 1: Basic Information',
          style: const TextStyle(color: Colors.white54, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 30),

        _buildRoleSelector(pesoGreen),
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
            child: const Row(
              children: [
                Icon(Icons.security, color: Colors.redAccent),
                SizedBox(width: 15),
                Expanded(
                  child: Text(
                    'Authorized PESO Staff Only. Requires internal access code.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
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
          controller: _emailController,
        ),
        const SizedBox(height: 15),

        if (!isAdmin) ...[
          _buildModernTextField(
            'Phone Number',
            Icons.phone_android,
            false,
            pesoGreen,
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
                  isAdmin ? 'Register Admin' : 'Continue to AI Setup',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
        const SizedBox(height: 25),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Already have an account? ",
              style: TextStyle(color: Colors.white70, fontSize: 15),
            ),
            GestureDetector(
              onTap: () => setState(() => _currentView = AuthView.login),
              child: Text(
                'Login Here',
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
  // 3. ONBOARDING VIEW (AI Profile)
  // ==========================================
  Widget _buildOnboardingView(Color pesoGreen) {
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
        const Icon(Icons.psychology, color: Colors.greenAccent, size: 50),
        const SizedBox(height: 15),
        const Text(
          'Configure AI Profile',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        const Text(
          'Our engine requires this data to generate custom exams and accurate TESDA action plans.',
          style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 35),

        const Text(
          'Bilingual Bio (Tagalog or English)',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _bioController,
          maxLines: 4,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Ikwento ang iyong mga karanasan at soft skills... / Briefly describe your background, skills, and goals...',
            hintStyle: const TextStyle(color: Colors.white30, height: 1.5),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            contentPadding: const EdgeInsets.all(20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: pesoGreen, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 30),

        const Text(
          'Resume Data Source',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: _buildResumeChoiceCard(
                'upload',
                Icons.upload_file,
                'Upload PDF',
                'Let AI parse it',
                pesoGreen,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildResumeChoiceCard(
                'build',
                Icons.edit_document,
                'System Form',
                'Build it here',
                pesoGreen,
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
                  'Complete & Enter Dashboard',
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

  Widget _buildRoleSelector(Color pesoGreen) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          _buildRoleTab('Job Seeker', Icons.person, 0, pesoGreen),
          _buildRoleTab('IT Admin', Icons.admin_panel_settings, 1, pesoGreen),
        ],
      ),
    );
  }

  Widget _buildRoleTab(
    String title,
    IconData icon,
    int index,
    Color pesoGreen,
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
                color: isSelected ? Colors.white : Colors.white54,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white54,
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
    Color pesoGreen, {
    TextEditingController? controller,
    String? prefixText,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword && _obscurePassword,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixText: prefixText,
        prefixStyle: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        prefixIcon: icon != null
            ? Icon(icon, color: Colors.white54, size: 22)
            : null,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 20,
          horizontal: 20,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: pesoGreen, width: 2),
        ),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white54,
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
  ) {
    bool isSelected = _selectedResumeType == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedResumeType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 15),
        decoration: BoxDecoration(
          color: isSelected
              ? pesoGreen.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.03),
          border: Border.all(
            color: isSelected ? pesoGreen : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 36,
              color: isSelected ? Colors.greenAccent : Colors.white38,
            ),
            const SizedBox(height: 15),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: TextStyle(
                color: isSelected
                    ? Colors.greenAccent.withValues(alpha: 0.8)
                    : Colors.white38,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
