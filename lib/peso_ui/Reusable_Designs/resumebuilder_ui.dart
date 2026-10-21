import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../peso_services/react_message_bridge.dart';

class ResumeBuilderWizard extends StatefulWidget {
  final ValueChanged<Map<String, dynamic>> onComplete;

  /// Registration values inherited by the resume builder. They are appended to
  /// the React workspace URL as query parameters so each template starts with
  /// the applicant's own name and contact details instead of sample text.
  final Map<String, String> initialValues;

  const ResumeBuilderWizard({
    super.key,
    required this.onComplete,
    this.initialValues = const <String, String>{},
  });

  @override
  State<ResumeBuilderWizard> createState() => _ResumeBuilderWizardState();
}

class _ResumeBuilderWizardState extends State<ResumeBuilderWizard> {
  late final WebViewController _controller;
  StreamSubscription<String>? _webMessageSubscription;
  bool _isLoading = true;
  final Color _primary = const Color(0xFF2E7D32);

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();

    if (kIsWeb) {
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

  /// The React resume builder reads these inherited registration values from
  /// the query string; an empty map keeps the original plain URL.
  Uri _buildWorkspaceUri() {
    final query = <String, String>{};
    widget.initialValues.forEach((key, value) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) query[key] = trimmed;
    });
    const configuredUrl = String.fromEnvironment(
      'PESO_NSRP_WORKSPACE_URL',
      defaultValue: '',
    );
    final configured = configuredUrl.trim();
    final workspace = configured.isEmpty
        ? Uri.parse('http://localhost:5173/')
        : Uri.base.resolve(configured);
    final workspacePath = workspace.path.endsWith('/')
        ? workspace.path.substring(0, workspace.path.length - 1)
        : workspace.path;
    final base = workspace.replace(
      path: '$workspacePath/resume',
      queryParameters: query.isEmpty ? null : query,
    );
    if (!const ['http', 'https'].contains(base.scheme) || base.host.isEmpty) {
      throw const FormatException('Invalid resume workspace URL.');
    }
    return base;
  }

  void _handleBridgePayload(String rawMessage) {
    try {
      final decoded = jsonDecode(rawMessage);
      if (decoded is Map && decoded['status'] == 'completed') {
        widget.onComplete(Map<String, dynamic>.from(decoded));
      }
    } catch (error) {
      debugPrint('[REACT BRIDGE] Ignored invalid resume payload: $error');
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
              child: Icon(
                Icons.auto_awesome_mosaic,
                color: _primary,
                size: compact ? 18 : 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Dynamic Resume Editor',
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
