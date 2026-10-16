import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../peso_services/auth_service.dart';
import '../Admin/admin_ui.dart';
import '../User/user_ui.dart';

class LoginForm extends StatefulWidget {
  final Color pesoGreen;
  final bool isLight;
  final VoidCallback onSwitchToRegister;

  const LoginForm({
    super.key,
    required this.pesoGreen,
    required this.isLight,
    required this.onSwitchToRegister,
  });

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : widget.pesoGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
    if (error is StateError || error is ArgumentError) return error.toString().replaceFirst('Bad state: ', '').replaceFirst('Invalid argument(s): ', '');
    return 'Something went wrong. Please try again. ($error)';
  }

  Future<void> _loginUser() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      _showMessage('Email and password are required.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthService.signInWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );
      await _openUserArea();
    } catch (error) {
      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await AuthService.signInWithGoogle();
      await _openUserArea();
    } catch (error) {
      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithSms() async {
    final phoneController = TextEditingController(text: '+63');
    final phone = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign in with SMS'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter your mobile number. Include the country code.'),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                hintText: '+639171234567',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, phoneController.text.trim()),
            child: const Text('Send code'),
          ),
        ],
      ),
    );
    phoneController.dispose();
    if (phone == null || phone.trim().isEmpty || !mounted) return;

    final normalizedPhone = AuthService.normalizePhoneNumber(phone);
    setState(() => _isLoading = true);
    try {
      await AuthService.sendPhoneCode(normalizedPhone);

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.phoneNumber == normalizedPhone) {
        await AuthService.ensureUserProfile(currentUser, phoneNumber: normalizedPhone);
        await _openUserArea();
        return;
      }

      if (!mounted) return;
      final codeController = TextEditingController();
      final smsCode = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Enter verification code'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Enter the code sent to $normalizedPhone.'),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                autofocus: true,
                maxLength: 8,
                decoration: const InputDecoration(
                  labelText: 'SMS code',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, codeController.text.trim()),
              child: const Text('Verify and sign in'),
            ),
          ],
        ),
      );
      codeController.dispose();
      if (smsCode == null || smsCode.isEmpty || !mounted) return;

      await AuthService.confirmPhoneCode(smsCode);
      await _openUserArea();
    } catch (error) {
      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      _showMessage('Password reset instructions were sent if the account exists.', isError: false);
    } catch (error) {
      _showMessage(_friendlyError(error));
    }
  }

  Future<void> _openUserArea() async {
    if (!mounted) return;
    final role = await AuthService.getCurrentUserRole();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => role == 'admin'
            ? const AdminDashboard()
            : const UserProfile(),
      ),
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
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: textColor),
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
              style: TextStyle(color: subtitleColor, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: _isLoading ? null : _loginUser,
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.pesoGreen,
            padding: const EdgeInsets.symmetric(vertical: 22),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
              : const Text('Secure Login', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.25))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('OR CONTINUE WITH', style: TextStyle(color: subtitleColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
            Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.25))),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _loginWithGoogle,
                icon: const Icon(Icons.g_mobiledata, size: 28),
                label: const Text('Google'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                  padding: const EdgeInsets.symmetric(vertical: 17),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _loginWithSms,
                icon: const Icon(Icons.sms_outlined, size: 20),
                label: const Text('SMS Code'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                  padding: const EdgeInsets.symmetric(vertical: 17),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Don't have an account? ", style: TextStyle(color: Colors.white70, fontSize: 15)),
            GestureDetector(
              onTap: widget.onSwitchToRegister,
              child: Text('Register Here', style: TextStyle(color: Colors.greenAccent[400], fontWeight: FontWeight.bold, fontSize: 15)),
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
    final Color fieldBg = widget.isLight ? Colors.grey.shade100 : Colors.white.withValues(alpha: 0.05);
    final Color borderColor = widget.isLight ? Colors.grey.shade300 : Colors.white.withValues(alpha: 0.1);
    final Color textColor = widget.isLight ? Colors.black87 : Colors.white;
    final Color hintColor = widget.isLight ? Colors.black38 : Colors.white38;

    return TextField(
      controller: controller,
      obscureText: isPassword && _obscurePassword,
      keyboardType: isPassword ? TextInputType.visiblePassword : TextInputType.emailAddress,
      style: TextStyle(color: textColor, fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: hintColor),
        prefixIcon: icon != null ? Icon(icon, color: hintColor, size: 22) : null,
        filled: true,
        fillColor: fieldBg,
        contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: borderColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: borderColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: widget.pesoGreen, width: 2)),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: hintColor),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              )
            : null,
      ),
      onSubmitted: isPassword ? (_) => _loginUser() : null,
    );
  }
}
