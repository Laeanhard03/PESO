import 'package:flutter/foundation.dart'; // Required for kIsWeb
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PesoRegistrationWizard extends StatefulWidget {
  final VoidCallback onComplete;

  const PesoRegistrationWizard({super.key, required this.onComplete});

  @override
  State<PesoRegistrationWizard> createState() => _PesoRegistrationWizardState();
}

class _PesoRegistrationWizardState extends State<PesoRegistrationWizard> {
  late final WebViewController _controller;
  bool _isLoading = true;

  // PESO Theme Palette
  final Color _primary = const Color(0xFF2E7D32);

  @override
  void initState() {
    super.initState();

    // 1. Initialize the controller globally
    _controller = WebViewController();

    // 2. Only apply these features if running on Mobile (Android/iOS)
    if (!kIsWeb) {
      _controller
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFFF8FAFC))
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (String url) {
              if (mounted) setState(() => _isLoading = false);
            },
          ),
        )
        ..addJavaScriptChannel(
          'FlutterBridge',
          onMessageReceived: (JavaScriptMessage message) {
            if (message.message == 'completed') {
              widget.onComplete();
            }
          },
        );
    } else {
      // On Web, simply dismiss the loader after a short delay
      // since NavigationDelegate isn't supported.
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _isLoading = false);
      });
    }

    // 3. Load the URL (Supported on both Web and Mobile)
    _controller.loadRequest(Uri.parse('http://localhost:5173'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.assignment_ind, color: _primary, size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              'NSRP Form 1 (React Engine)',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          // Fallback button ONLY for Chrome testing to manually skip the form
          if (kIsWeb)
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: TextButton.icon(
                onPressed: widget.onComplete,
                icon: Icon(Icons.fast_forward, color: _primary),
                label: Text(
                  'Skip (Web Test)',
                  style: TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Center(
              child: CircularProgressIndicator(color: _primary, strokeWidth: 3),
            ),
        ],
      ),
    );
  }
}
