import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../peso_services/applicant_draft_service.dart';
import '../../peso_services/peso_api_client.dart';
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
  final String? verifiedResumeSex;

  const PesoRegistrationWizard({
    super.key,
    required this.onComplete,
    this.initialValues = const <String, String>{},
    this.savedFormData = const <String, dynamic>{},
    this.verifiedResumeSex,
  });

  @override
  State<PesoRegistrationWizard> createState() => _PesoRegistrationWizardState();
}

class _PesoRegistrationWizardState extends State<PesoRegistrationWizard> {
  late final WebViewController _controller;
  StreamSubscription<String>? _webMessageSubscription;
  bool _isLoading = true;
  bool _draftSyncRunning = false;
  Timer? _draftRetryTimer;
  String? _lastSyncedDraftAt;
  bool _formFinished = false;
  Map<String, dynamic>? _nextDraft;
  final Color _primary = const Color(0xFF2E7D32);

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    _draftRetryTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (mounted && !_formFinished && !_draftSyncRunning) unawaited(_retryEncryptedDraft());
    });

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

  void _postToWorkspace(Map<String, dynamic> payload) {
    final message = <String, dynamic>{'source': 'peso-flutter', ...payload};
    if (kIsWeb) {
      postReactWorkspaceMessage(payload);
    } else {
      _controller.runJavaScript(
        'window.postMessage(' + jsonEncode(jsonEncode(message)) + ', "*");',
      );
    }
  }

  Future<void> _restoreDraft() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    final saved = widget.savedFormData;
    final remote = saved['pendingDraft'] is Map
        ? Map<String, dynamic>.from(saved['pendingDraft'] as Map)
        : <String, dynamic>{};
    final local = await ApplicantDraftService.read(uid, 'nsrp');
    final pending = ApplicantDraftService.newest(remote, local);
    final completedAt = DateTime.tryParse(saved['completedAt']?.toString() ?? '');
    final pendingAt = DateTime.tryParse(pending['draftUpdatedAt']?.toString() ?? '');
    final restorePending = pending.isNotEmpty &&
        (completedAt == null || (pendingAt != null && pendingAt.isAfter(completedAt)));
    final data = restorePending ? pending : saved;
    if (!mounted) return;
    _postToWorkspace(<String, dynamic>{
      'event': 'nsrp-prefill',
      'ownerUid': uid,
      'formData': data,
      'verifiedResumeSex': widget.verifiedResumeSex,
    });
    if (restorePending && (local != null && local.isNotEmpty)) {
      _nextDraft = pending;
      if (!_draftSyncRunning) unawaited(_drainDrafts());
    }
  }

  Future<void> _retryEncryptedDraft() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    final local = await ApplicantDraftService.read(uid, 'nsrp');
    if (!mounted || _formFinished || local == null || local.isEmpty ||
        local['draftUpdatedAt'] == _lastSyncedDraftAt) return;
    _queueDraft(local);
  }

  void _queueDraft(Map<String, dynamic> draft) {
    if (_formFinished) return;
    _nextDraft = draft;
    if (!_draftSyncRunning) unawaited(_drainDrafts());
  }

  Future<void> _drainDrafts() async {
    _draftSyncRunning = true;
    try {
      while (!_formFinished && _nextDraft != null) {
        final draft = _nextDraft!;
        _nextDraft = null;
        final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
        _postToWorkspace({'event': 'draft-sync-status', 'state': 'Saving'});
        try {
          await ApplicantDraftService.write(uid, 'nsrp', draft);
        } catch (_) {
          _postToWorkspace({'event': 'draft-sync-status', 'state': 'Sync Failed'});
          continue;
        }
        if (_formFinished) break;
        try {
          await ApplicantDraftService.sync('nsrp', draft);
          _lastSyncedDraftAt = draft['draftUpdatedAt']?.toString();
          _postToWorkspace({'event': 'draft-sync-status', 'state': 'Saved'});
        } on PesoApiException catch (error) {
          _postToWorkspace({'event': 'draft-sync-status',
            'state': error.statusCode == 0 ? 'Offline Draft' : 'Sync Failed'});
        } catch (_) {
          _postToWorkspace({'event': 'draft-sync-status', 'state': 'Sync Failed'});
        }
      }
    } finally {
      _draftSyncRunning = false;
    }
  }

  void _handleBridgePayload(String rawMessage) {
    try {
      final decoded = jsonDecode(rawMessage);
      if (decoded is Map &&
          decoded['status'] == 'ready' &&
          decoded['kind'] == 'nsrp_form') {
        unawaited(_restoreDraft());
      } else if (decoded is Map && decoded['status'] == 'draft' &&
          decoded['kind'] == 'nsrp_form' && decoded['formData'] is Map) {
        _queueDraft(Map<String, dynamic>.from(decoded['formData'] as Map));
      } else if (decoded is Map && decoded['status'] == 'completed' &&
          decoded['kind'] == 'nsrp_form') {
        _formFinished = true;
        _nextDraft = null;
        // Do not discard the encrypted draft until the backend confirms that
        // the finished PDF AND form fields were persisted successfully.
        widget.onComplete(Map<String, dynamic>.from(decoded));
      }
    } catch (error) {
      debugPrint('[REACT BRIDGE] Ignored invalid NSRP payload: $error');
    }
  }

  @override
  void dispose() {
    _draftRetryTimer?.cancel();
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
