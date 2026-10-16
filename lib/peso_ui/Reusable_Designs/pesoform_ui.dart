import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../peso_services/react_message_bridge.dart';

class PesoRegistrationWizard extends StatefulWidget {
  final ValueChanged<Map<String, dynamic>> onComplete;

  const PesoRegistrationWizard({super.key, required this.onComplete});

  @override
  State<PesoRegistrationWizard> createState() => _PesoRegistrationWizardState();
}

class _PesoRegistrationWizardState extends State<PesoRegistrationWizard> {
  late final WebViewController _controller;
  StreamSubscription<String>? _webMessageSubscription;
  bool _isLoading = true;
  final Color _primary = const Color(0xFF2E7D32);

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();

    if (kIsWeb) {
      // webview_flutter_web is iframe-backed and does not support native
      // JavaScript channels. Listen for validated postMessage events instead.
      _webMessageSubscription = reactBridgeMessages.listen(_handleBridgePayload);
      Future<void>.delayed(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _isLoading = false);
      });
    } else {
      _controller
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFFF8FAFC))
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              if (mounted) setState(() => _isLoading = false);
            },
          ),
        )
        ..addJavaScriptChannel(
          'FlutterBridge',
          onMessageReceived: (JavaScriptMessage message) =>
              _handleBridgePayload(message.message),
        );
    }

    _controller.loadRequest(Uri.parse('http://localhost:5173'));
  }

  void _handleBridgePayload(String rawMessage) {
    try {
      final decoded = jsonDecode(rawMessage);
      if (decoded is Map && decoded['status'] == 'completed') {
        widget.onComplete(Map<String, dynamic>.from(decoded));
      }
    } catch (error) {
      debugPrint('[REACT BRIDGE] Ignored invalid NSRP payload: $error');
    }
  }

  @override
  void dispose() {
    _webMessageSubscription?.cancel();
    super.dispose();
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
          if (kIsWeb)
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: TextButton.icon(
                onPressed: () => widget.onComplete({
                  'status': 'completed',
                  'source': 'peso-react-workspace',
                  'kind': 'nsrp_form',
                  'data': '',
                  'aiText': '',
                  'formData': {'documentType': 'NSRP Form 1', 'entries': <dynamic>[]},
                }),
                icon: Icon(Icons.fast_forward, color: _primary),
                label: Text(
                  'Skip (Web Test)',
                  style: TextStyle(color: _primary, fontWeight: FontWeight.bold),
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
            Center(child: CircularProgressIndicator(color: _primary, strokeWidth: 3)),
        ],
      ),
    );
  }
}
