import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'peso_services/firebase_setup.dart';
import 'peso_services/peso_image_cache_manager.dart';
import 'peso_ui/Landingpage/landingpage_ui.dart';
import 'peso_ui/Admin/admin_live_applicants_page.dart';
import 'peso_ui/Reusable_Designs/peso_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Don't crash the public landing page when Firebase has not been configured.
  // Authentication actions will show setup instructions until FlutterFire is run.
  try {
    if (FirebaseSetup.isConfigured) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      // Explicit opt-in for isolated browser QA only. Normal builds always
      // authenticate against the configured Firebase project.
      if (const bool.fromEnvironment('PESO_E2E_AUTH_EMULATOR') &&
          kIsWeb &&
          (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1')) {
        // Even a mistaken QA-flagged deployment must never redirect
        // production-domain authentication to the local emulator.
        await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
        // In emulator browser QA, remember a signed-in admin across tabs so
        // the private spreadsheet bookmark can recheck its server-side role.
        // No production persistence policy is changed by this test-only flag.
        await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
      }
    } else {
      debugPrint(
        '[CONFIG] Firebase placeholders detected. Run `flutterfire configure`.',
      );
    }
  } catch (error, stackTrace) {
    debugPrint('[CONFIG] Firebase initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  runApp(const PesoApp());

  // Pre-cache built-in remote imagery in the background after first paint.
  if (!kIsWeb) unawaited(PesoImageCacheManager.preloadKnownImages());
}

class PesoApp extends StatelessWidget {
  const PesoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PESO JobKonek',
      theme: PesoTheme.light,
      home: kIsWeb && Uri.base.queryParameters['liveApplicants'] == '1'
          ? const AdminLiveApplicantsPage()
          : const LandingPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
