import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'peso_services/firebase_setup.dart';
import 'peso_ui/Landingpage/landingpage_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Don't crash the public landing page when Firebase has not been configured.
  // Authentication actions will show setup instructions until FlutterFire is run.
  try {
    if (FirebaseSetup.isConfigured) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
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
}

class PesoApp extends StatelessWidget {
  const PesoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PESO JobKonek',
      theme: ThemeData(
        primaryColor: const Color(0xFF2E7D32),
        scaffoldBackgroundColor: Colors.grey[100],
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color(0xFF2E7D32),
          secondary: const Color(0xFFFFB300),
          tertiary: const Color(0xFF1565C0),
        ),
      ),
      home: const LandingPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
