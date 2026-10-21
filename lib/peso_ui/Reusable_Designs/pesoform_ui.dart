import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../peso_services/react_message_bridge.dart';

class PesoRegistrationWizard extends StatefulWidget {
  final ValueChanged<Map<String, dynamic>> onComplete;

  /// Registration values inherited by NSRP Form 1. They are appended to the
  /// React workspace URL as query parameters so the form's name, email, and
  /// cellphone fields start with the registered applicant's details.
  final Map<String, String> initialValues;
  final Map<String, dynamic> savedFormData;

  const PesoRegistrationWizard({
    super.key,
    required this.onComplete,
    this.initialValues = const <String, String>{},
    this.savedFormData = const <String, dynamic>{},
  });

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
      _webMessageSubscription = reactBridgeMessages.listen(
        _handleBridgePayload,
      );
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

    _controller.loadRequest(_buildWorkspaceUri());
  }

  /// The React NSRP form reads these inherited registration values from the
  /// query string; an empty map keeps the original plain URL.
  Uri _buildWorkspaceUri() {
    final query = <String, String>{};
    widget.initialValues.forEach((key, value) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) query[key] = trimmed;
    });
    // Local development uses Vite. The hosted Flutter build configures /nsrp/
    // on the same domain, avoiding a second Vercel frontend and stale origins.
    const configuredUrl = String.fromEnvironment(
      'PESO_NSRP_WORKSPACE_URL',
      defaultValue: '',
    );
    final base = configuredUrl.trim().isEmpty
        ? Uri.parse('http://localhost:5173/')
        : Uri.base.resolve(configuredUrl.trim());
    if (!const ['http', 'https'].contains(base.scheme) || base.host.isEmpty) {
      throw const FormatException('Invalid NSRP workspace URL.');
    }
    return query.isEmpty ? base : base.replace(queryParameters: query);
  }

  void _handleBridgePayload(String rawMessage) {
    try {
      final decoded = jsonDecode(rawMessage);
      if (decoded is Map &&
          decoded['status'] == 'ready' &&
          decoded['kind'] == 'nsrp_form' &&
          widget.savedFormData.isNotEmpty) {
        if (kIsWeb) {
          postReactNsrpPrefill(widget.savedFormData);
        } else {
          final json = jsonEncode(<String, dynamic>{
            'source': 'peso-flutter',
            'event': 'nsrp-prefill',
            'formData': widget.savedFormData,
          });
          _controller.runJavaScript(
            ['window.postMessage(', jsonEncode(json), ', "*");'].join(),
          );
        }
      } else if (decoded is Map && decoded['status'] == 'completed') {
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
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(compact ? 6 : 8),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  color: Colors.white,
                  child: Image.asset(
                    'lib/assets/peso_form_icon.png',
                    width: compact ? 14 : 18,
                    height: compact ? 20 : 26,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'NSRP Form 1 | Registration & Updates',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w900,
                  fontSize: compact ? 14 : 18,
                ),
              ),
            ),
          ],
        ),
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
