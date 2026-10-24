import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'onboarding_draft_sync.dart';
import '../peso_ui/Landingpage/landingpage_ui.dart';
import '../peso_ui/Login_register_pages/auth_ui.dart';
import '../peso_ui/Admin/admin_ui.dart';
import '../peso_ui/User/user_ui.dart';

/// The root route must wait for Firebase to hydrate persisted auth state.
/// Back within a workspace preserves Firebase authentication; only explicit logout revokes it.
class AuthSessionGate extends StatefulWidget {
  const AuthSessionGate({super.key});

  @override
  State<AuthSessionGate> createState() => _AuthSessionGateState();
}

class _AuthSessionGateState extends State<AuthSessionGate> {
  Widget? _destination;
  String? _problem;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_resolve());
  }

  Future<void> _resolve() async {
    if (!mounted) return;
    setState(() { _loading = true; _problem = null; });
    if (Firebase.apps.isEmpty) {
      if (mounted) setState(() { _destination = const LandingPage(); _loading = false; });
      return;
    }
    try {
      // authStateChanges waits for the browser's durable Firebase session to
      // initialize, unlike checking currentUser synchronously at first paint.
      final user = await FirebaseAuth.instance.authStateChanges().first
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (user == null) {
        setState(() { _destination = const LandingPage(); _loading = false; });
        return;
      }
      if (!user.emailVerified) {
        setState(() {
          _destination = const AuthPage(resumePendingVerification: true);
          _loading = false;
        });
        return;
      }
      final role = await AuthService.getCurrentUserRole();
      if (!mounted) return;
      unawaited(OnboardingDraftSync.live.resumeAfterSignIn(user.uid));
      setState(() {
        _destination = role == 'admin' ? const AdminDashboard() : const UserProfile();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Preserve Firebase credentials. Never interpret an unreachable role
      // API as a logout or as evidence that this identity is an applicant.
      setState(() {
        _problem = 'Your account is still signed in, but the PESO service could '
            'not restore your workspace. Check your connection and retry.';
        _loading = false;
      });
    }
  }

  Future<void> _switchAccount() async {
    try {
      await AuthService.signOut();
      if (!mounted) return;
      setState(() {
        _destination = const LandingPage();
        _problem = null;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _problem = 'Could not sign out. Check your connection and retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_problem == null && _destination != null) return _destination!;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_rounded, size: 44),
                const SizedBox(height: 16),
                Text(_problem ?? 'Could not restore your session.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton(onPressed: _resolve, child: const Text('Retry connection')),
                TextButton(onPressed: _switchAccount,
                    child: const Text('Sign out and use another account')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
