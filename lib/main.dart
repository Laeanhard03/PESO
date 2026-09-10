import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'peso_ui/landingpage_ui.dart';

void main() async {
  // Ensure Flutter bindings are initialized before calling native code
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase with YOUR actual project credentials
  await Supabase.initialize(
    url: 'https://eatrigghcxogthtafxkn.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVhdHJpZ2doY3hvZ3RodGFmeGtuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgzNTEzOTUsImV4cCI6MjEwMzkyNzM5NX0.-6O7eUrBAsHH8p_oekNwEXkZrGKHgqAP4QvgeMfHMO0',
  );

  runApp(const PesoApp());
}

// Global variable to quickly access Supabase anywhere in your app
final supabase = Supabase.instance.client;

class PesoApp extends StatelessWidget {
  const PesoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PESO Prototype',
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
