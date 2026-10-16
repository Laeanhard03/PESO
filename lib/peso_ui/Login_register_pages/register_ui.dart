import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../peso_services/auth_service.dart';

class RegisterForm extends StatefulWidget {
  final Color pesoGreen;
  final bool isLight;
  final VoidCallback onSwitchToLogin;
  final VoidCallback onProceedToOnboarding;

  const RegisterForm({
    super.key,
    required this.pesoGreen,
    required this.isLight,
    required this.onSwitchToLogin,
    required this.onProceedToOnboarding,
  });

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
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
        case 'email-already-in-use':
          return 'An account already exists for that email address. Try logging in.';
        case 'invalid-email':
          return 'Enter a valid email address.';
        case 'weak-password':
          return 'Choose a stronger password (at least 6 characters).';
        case 'operation-not-allowed':
          return 'This sign-in method is not enabled in Firebase Authentication yet.';
        case 'popup-closed-by-user':
        case 'web-context-cancelled':
          return 'Sign-in was cancelled.';
      }
      return error.message ?? 'Registration failed. Please try again.';
    }
    if (error is StateError || error is ArgumentError) {
      return error.toString().replaceFirst('Bad state: ', '').replaceFirst('Invalid argument(s): ', '');
    }
    return 'Something went wrong. Please try again. ($error)';
  }

  Future<void> _registerUser() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (firstName.isEmpty || lastName.isEmpty || email.isEmpty || password.isEmpty) {
      _showMessage('First name, last name, email, and password are required.');
      return;
    }
    if (password.length < 6) {
      _showMessage('Password must be at least 6 characters.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthService.registerWithEmail(
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
        phoneNumber: _phoneController.text.trim().isEmpty
            ? null
            : AuthService.normalizePhoneNumber(_phoneController.text),
      );
      _showMessage('Account created. Your profile has been saved.', isError: false);
      widget.onProceedToOnboarding();
    } catch (error) {
      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _registerWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await AuthService.signInWithGoogle();
      if (mounted) widget.onProceedToOnboarding();
    } catch (error) {
      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color textColor = widget.isLight ? Colors.black87 : Colors.white;
    final Color subtitleColor = widget.isLight ? Colors.black54 : Colors.white70;
    final Color fieldBg = widget.isLight ? Colors.grey.shade100 : Colors.white.withValues(alpha: 0.05);
    final Color borderColor = widget.isLight ? Colors.grey.shade300 : Colors.white.withValues(alpha: 0.1);
    final Color hintColor = widget.isLight ? Colors.black38 : Colors.white38;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _stepIndicator(widget.pesoGreen),
            const SizedBox(width: 8),
            _stepIndicator(Colors.grey.shade300),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Create Account',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: textColor),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 5),
        Text(
          'Step 1: Your basic information',
          style: TextStyle(color: subtitleColor, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 30),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                'First Name', Icons.person_outline, _firstNameController,
                fieldBg, borderColor, textColor, hintColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(
                'Last Name', null, _lastNameController,
                fieldBg, borderColor, textColor, hintColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        _buildTextField(
          'Email Address', Icons.email_outlined, _emailController,
          fieldBg, borderColor, textColor, hintColor,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 15),
        _buildTextField(
          'Phone Number (optional)', Icons.phone_android, _phoneController,
          fieldBg, borderColor, textColor, hintColor,
          keyboardType: TextInputType.phone,
          helperText: 'Philippine numbers are automatically formatted with +63.',
        ),
        const SizedBox(height: 15),
        _buildTextField(
          'Password (at least 6 characters)', Icons.lock_outline, _passwordController,
          fieldBg, borderColor, textColor, hintColor,
          isPassword: true,
        ),
        const SizedBox(height: 28),
        ElevatedButton(
          onPressed: _isLoading ? null : _registerUser,
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.pesoGreen,
            padding: const EdgeInsets.symmetric(vertical: 22),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
              : const Text('Create Account and Continue', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 15),
        OutlinedButton.icon(
          onPressed: _isLoading ? null : _registerWithGoogle,
          icon: const Icon(Icons.g_mobiledata, size: 28),
          label: const Text('Continue with Google'),
          style: OutlinedButton.styleFrom(
            foregroundColor: textColor,
            side: BorderSide(color: borderColor),
            padding: const EdgeInsets.symmetric(vertical: 17),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 25),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Already have an account? ', style: TextStyle(color: subtitleColor, fontSize: 15)),
            GestureDetector(
              onTap: widget.onSwitchToLogin,
              child: Text('Login Here', style: TextStyle(color: widget.pesoGreen, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _stepIndicator(Color color) => Container(
        width: 30,
        height: 4,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
      );

  Widget _buildTextField(
    String hint,
    IconData? icon,
    TextEditingController controller,
    Color background,
    Color borderColor,
    Color textColor,
    Color hintColor, {
    bool isPassword = false,
    TextInputType? keyboardType,
    String? helperText,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword && _obscurePassword,
      keyboardType: keyboardType,
      style: TextStyle(color: textColor, fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: hintColor),
        helperText: helperText,
        helperStyle: TextStyle(color: hintColor, fontSize: 11),
        prefixIcon: icon != null ? Icon(icon, color: hintColor, size: 22) : null,
        filled: true,
        fillColor: background,
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
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
    );
  }
}
