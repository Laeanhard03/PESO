import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../peso_services/app_toast.dart';

import '../../peso_services/auth_service.dart';
import '../../peso_services/peso_role_policy.dart';
import '../Admin/admin_ui.dart';
import '../User/user_ui.dart';

class LoginForm extends StatefulWidget {
  final Color pesoGreen;
  final bool isLight;
  final VoidCallback onSwitchToRegister;

  /// Optional test seam for an unresolved browser popup.
  final Future<void> Function()? googleSignIn;
  final ValueChanged<String>? onEmailVerificationRequired;

  const LoginForm({
    super.key,
    required this.pesoGreen,
    required this.isLight,
    required this.onSwitchToRegister,
    this.googleSignIn,
    this.onEmailVerificationRequired,
  });

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _googlePending = false;
  int _googleRequestId = 0;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = true}) {
    if (!mounted) return;
    isError
        ? AppToast.error(context, message)
        : AppToast.success(context, message);
  }

  String _friendlyError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          return 'The email/phone or password is incorrect.';
        case 'email-already-in-use':
          return 'An account already exists for that email address.';
        case 'invalid-email':
          return 'Enter a valid email address.';
        case 'weak-password':
          return 'Choose a stronger password (at least 6 characters).';
        case 'too-many-requests':
          return 'Too many attempts. Please wait and try again later.';
        case 'invalid-phone-number':
          return 'Enter a valid phone number in international format.';
        case 'invalid-verification-code':
          return 'That SMS verification code is incorrect.';
        case 'account-exists-with-different-credential':
          return 'This email uses another sign-in method. Try that method first.';
        case 'popup-closed-by-user':
        case 'web-context-cancelled':
          return 'Sign-in was cancelled.';
      }
      return error.message ?? 'Authentication failed. Please try again.';
    }
    if (error is StateError || error is ArgumentError)
      return error
          .toString()
          .replaceFirst('Bad state: ', '')
          .replaceFirst('Invalid argument(s): ', '');
    return 'Something went wrong. Please try again. ($error)';
  }

  Future<void> _loginUser() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      _showMessage('Email and password are required.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final credential = await AuthService.signInWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (credential.user != null && !credential.user!.emailVerified) {
        widget.onEmailVerificationRequired?.call(
          credential.user!.email ?? _emailController.text.trim(),
        );
        return;
      }
      if (credential.user != null) {
        await AuthService.ensureUserProfile(credential.user!);
      }
      await _openUserArea();
    } catch (error) {
      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _cancelGoogle() {
    if (!_googlePending) return;
    ++_googleRequestId;
    setState(() {
      _googlePending = false;
      _isLoading = false;
    });
    _showMessage('Google sign-in cancelled. You can try again or use email.');
  }

  Future<void> _loginWithGoogle() async {
    if (_isLoading) return;
    final requestId = ++_googleRequestId;
    setState(() {
      _isLoading = true;
      _googlePending = true;
    });
    try {
      await (widget.googleSignIn?.call() ?? AuthService.signInWithGoogle());
      // Closing or cancelling the popup must not navigate later.
      if (!mounted || requestId != _googleRequestId) return;
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.emailVerified) {
        widget.onEmailVerificationRequired?.call(user.email ?? '');
        return;
      }
      if (user != null) await AuthService.ensureUserProfile(user);
      await _openUserArea();
    } catch (error) {
      if (mounted && requestId == _googleRequestId) {
        _showMessage(_friendlyError(error));
      }
    } finally {
      if (mounted && requestId == _googleRequestId) {
        setState(() {
          _isLoading = false;
          _googlePending = false;
        });
      }
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage('Enter your email address first.');
      return;
    }
    try {
      await AuthService.sendPasswordReset(email);
      _showMessage(
        'Password reset instructions were sent if the account exists.',
        isError: false,
      );
    } catch (error) {
      _showMessage(_friendlyError(error));
    }
  }

  Future<void> _openUserArea() async {
    if (!mounted) return;

    // Firebase proves identity; the authenticated PESO API resolves the
    // MongoDB application role. If that lookup fails, AuthService fails
    // closed to a regular-user role.
    final role = await AuthService.getCurrentUserRole();
    if (!mounted) return;

    if (shouldOpenAdminArea(role)) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboard()),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const UserProfile()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color textColor = Colors.white;
    final Color subtitleColor = Colors.white70;

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
        _buildModernTextField(
          'Email Address',
          Icons.email_outlined,
          false,
          controller: _emailController,
        ),
        const SizedBox(height: 20),
        _buildModernTextField(
          'Password',
          Icons.lock_outline,
          true,
          controller: _passwordController,
        ),
        const SizedBox(height: 5),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _isLoading ? null : _forgotPassword,
            child: Text(
              'Forgot Password?',
              style: TextStyle(
                color: subtitleColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: _isLoading ? null : _loginUser,
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.pesoGreen,
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
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Divider(color: Colors.white.withValues(alpha: 0.25)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'OR CONTINUE WITH',
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
            Expanded(
              child: Divider(color: Colors.white.withValues(alpha: 0.25)),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _isLoading ? null : _loginWithGoogle,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
              minimumSize: const Size(0, 56),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              alignment: Alignment.center,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Row(
              key: const ValueKey<String>('google-sign-in-content'),
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.g_mobiledata, size: 30),
                const SizedBox(width: 8),
                const Text('Google'),
              ],
            ),
          ),
        ),
        if (_googlePending) ...[
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _cancelGoogle,
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Cancel Google sign-in / unlock form'),
            style: TextButton.styleFrom(foregroundColor: Colors.orangeAccent),
          ),
        ],
        const SizedBox(height: 30),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 4,
          runSpacing: 4,
          children: [
            const Text(
              "Don't have an account? ",
              style: TextStyle(color: Colors.white70, fontSize: 15),
            ),
            GestureDetector(
              onTap: widget.onSwitchToRegister,
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

  Widget _buildModernTextField(
    String hint,
    IconData? icon,
    bool isPassword, {
    TextEditingController? controller,
  }) {
    final Color fieldBg = widget.isLight
        ? Colors.grey.shade100
        : Colors.white.withValues(alpha: 0.05);
    final Color borderColor = widget.isLight
        ? Colors.grey.shade300
        : Colors.white.withValues(alpha: 0.1);
    final Color textColor = widget.isLight ? Colors.black87 : Colors.white;
    final Color hintColor = widget.isLight ? Colors.black38 : Colors.white38;

    return TextField(
      controller: controller,
      obscureText: isPassword && _obscurePassword,
      keyboardType: isPassword
          ? TextInputType.visiblePassword
          : TextInputType.emailAddress,
      style: TextStyle(color: textColor, fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: hintColor),
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
          borderSide: BorderSide(color: widget.pesoGreen, width: 2),
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
      onSubmitted: isPassword ? (_) => _loginUser() : null,
    );
  }
}
