import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../peso_services/auth_service.dart';
import '../Landingpage/landingpage_ui.dart';
import 'admin_excel_live_preview.dart';

/// Bookmarkable private live spreadsheet route. A link carries no bearer
/// token or applicant data. Firebase authenticates a visitor; the PESO API
/// independently verifies the MongoDB administrator role on every data call.
class AdminLiveApplicantsPage extends StatefulWidget {
  const AdminLiveApplicantsPage({super.key});

  @override
  State<AdminLiveApplicantsPage> createState() =>
      _AdminLiveApplicantsPageState();
}

class _AdminLiveApplicantsPageState extends State<AdminLiveApplicantsPage> {
  late Future<bool> _authorized;
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signingIn = false;
  String? _signInError;

  @override
  void initState() {
    super.initState();
    _authorized = _verify();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<bool> _verify() async {
    try {
      final auth = FirebaseAuth.instance;
      // A newly opened tab can emit null before browser auth is rehydrated.
      // Never treat an unverified local browser flag as authorization.
      final restored = await auth
          .authStateChanges()
          .where((user) => user != null)
          .first
          .timeout(
            const Duration(seconds: 6),
            onTimeout: () => auth.currentUser,
          );
      if (restored == null && auth.currentUser == null) return false;
      return await AuthService.getCurrentUserRole() == 'admin';
    } catch (_) {
      return false;
    }
  }

  Future<void> _authorizeSignIn(
    Future<UserCredential> Function() signIn,
  ) async {
    if (_signingIn || !mounted) return;
    setState(() {
      _signingIn = true;
      _signInError = null;
    });
    try {
      final credentials = await signIn();
      if (credentials.user == null) {
        throw StateError('No Firebase identity was returned.');
      }
      final allowed = await AuthService.getCurrentUserRole() == 'admin';
      if (!mounted) return;
      if (allowed) {
        _password.clear();
        setState(() {
          _signInError = null;
          _authorized = Future<bool>.value(true);
        });
      } else {
        setState(() {
          _signInError =
              'This account is not authorized to view the private register. '
              'Sign in with a PESO administrator account.';
        });
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _signInError = switch (error.code) {
          'wrong-password' ||
          'invalid-credential' ||
          'user-not-found' => 'The email or password is incorrect.',
          'popup-closed-by-user' || 'cancelled-popup-request' =>
            'Google sign-in was cancelled. You can try again.',
          'popup-blocked' =>
            'Allow sign-in popups for this site and try again.',
          'too-many-requests' =>
            'Too many sign-in attempts. Please retry later.',
          _ => 'Could not sign in. Check your administrator account and retry.',
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _signInError =
            'Could not verify your administrator access. '
            'Check the PESO API connection and try again.';
      });
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  Future<void> _signInWithEmail() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _signInError = 'Enter your admin email and password.');
      return;
    }
    await _authorizeSignIn(
      () => FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      ),
    );
  }

  Future<void> _signInWithGoogle() => _authorizeSignIn(() {
    final provider = GoogleAuthProvider()
      ..addScope('email')
      ..setCustomParameters({'prompt': 'select_account'});
    return kIsWeb
        ? FirebaseAuth.instance.signInWithPopup(provider)
        : FirebaseAuth.instance.signInWithProvider(provider);
  });

  Widget _buildLogin() => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AutofillGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    color: Color(0xFF236349),
                    size: 36,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Administrator sign-in required',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This live applicant register is private. '
                    'Sign in with your PESO administrator account to continue.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _email,
                    enabled: !_signingIn,
                    autofillHints: const [AutofillHints.username],
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Administrator email',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    enabled: !_signingIn,
                    autofillHints: const [AutofillHints.password],
                    obscureText: true,
                    onSubmitted: (_) => _signInWithEmail(),
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_signInError != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _signInError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _signingIn ? null : _signInWithEmail,
                    icon: _signingIn
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.verified_user_outlined),
                    label: const Text('Unlock live applicant register'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _signingIn ? null : _signInWithGoogle,
                    icon: const Icon(Icons.account_circle_outlined),
                    label: const Text('Continue with Google'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _signingIn
                        ? null
                        : () => Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const LandingPage(),
                            ),
                          ),
                    child: const Text('Return to PESO'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF0F6F2),
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: const Text('PESO Live Applicant Spreadsheet'),
      leading: IconButton(
        tooltip: 'Return to PESO',
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LandingPage()),
        ),
      ),
    ),
    body: FutureBuilder<bool>(
      future: _authorized,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data != true) return _buildLogin();
        return const Center(child: AdminExcelLivePreview());
      },
    ),
  );
}
