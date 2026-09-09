import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ResumeBuilderWizard extends StatefulWidget {
  final VoidCallback onComplete;

  const ResumeBuilderWizard({super.key, required this.onComplete});

  @override
  State<ResumeBuilderWizard> createState() => _ResumeBuilderWizardState();
}

class _ResumeBuilderWizardState extends State<ResumeBuilderWizard> {
  late final WebViewController _controller;
  bool _isLoading = true;

  // Theme Palette
  final Color _primary = const Color(0xFF2E7D32);

  @override
  void initState() {
    super.initState();

    _controller = WebViewController();

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
            // Wait for the 'completed' message from your React button
            if (message.message == 'completed') {
              widget.onComplete();
            }
          },
        );
    } else {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _isLoading = false);
      });
    }

    // We assume you map the resume builder in React to '/resume'
    _controller.loadRequest(Uri.parse('http://localhost:5173/resume'));
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
              child: Icon(Icons.auto_awesome_mosaic, color: _primary, size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              'Dynamic Resume Editor',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
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
