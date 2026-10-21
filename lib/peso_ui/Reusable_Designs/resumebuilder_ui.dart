import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../peso_services/applicant_draft_service.dart';
import '../../peso_services/peso_api_client.dart';
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
  bool _draftSyncRunning = false;
  Timer? _draftRetryTimer;
  String? _lastSyncedDraftAt;
  bool _builderFinished = false;
  Map<String, dynamic>? _nextDraft;
  final Color _primary = const Color(0xFF2E7D32);

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    _draftRetryTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (mounted && !_builderFinished && !_draftSyncRunning) unawaited(_retryEncryptedDraft());
    });

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

  void _postToWorkspace(Map<String, dynamic> payload) {
    if (kIsWeb) {
      postReactWorkspaceMessage(payload);
    } else {
      final message = <String, dynamic>{'source': 'peso-flutter', ...payload};
      _controller.runJavaScript(
        'window.postMessage(' + jsonEncode(jsonEncode(message)) + ', "*");',
      );
    }
  }

  Future<void> _restoreDraft() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    var remote = <String, dynamic>{};
    try {
      final response = await PesoApiClient.getProfile();
      final profile = response['profile'];
      if (profile is Map && profile['resumeData'] is Map) {
        final data = profile['resumeData'] as Map;
        if (data['pendingDraft'] is Map) {
          remote = Map<String, dynamic>.from(data['pendingDraft'] as Map);
        }
      }
    } catch (_) {
      // An offline device may still have an encrypted draft.
    }
    final local = await ApplicantDraftService.read(uid, 'resume');
    final chosen = ApplicantDraftService.newest(remote, local);
    if (!mounted || _builderFinished) return;
    _postToWorkspace({'event': 'resume-prefill', 'ownerUid': uid,
      'formData': chosen});
    if (local != null && local.isNotEmpty) {
      _nextDraft = chosen;
      if (!_draftSyncRunning) unawaited(_drainDrafts());
    }
  }

  Future<void> _retryEncryptedDraft() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    final local = await ApplicantDraftService.read(uid, 'resume');
    if (!mounted || _builderFinished || local == null || local.isEmpty ||
        local['draftUpdatedAt'] == _lastSyncedDraftAt) return;
    _queueDraft(local);
  }

  void _queueDraft(Map<String, dynamic> draft) {
    if (_builderFinished) return;
    _nextDraft = draft;
    if (!_draftSyncRunning) unawaited(_drainDrafts());
  }

  Future<void> _drainDrafts() async {
    _draftSyncRunning = true;
    try {
      while (!_builderFinished && _nextDraft != null) {
        final draft = _nextDraft!;
        _nextDraft = null;
        final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
        _postToWorkspace({'event': 'draft-sync-status', 'state': 'Saving'});
        try {
          await ApplicantDraftService.write(uid, 'resume', draft);
        } catch (_) {
          _postToWorkspace({'event': 'draft-sync-status', 'state': 'Sync Failed'});
          continue;
        }
        if (_builderFinished) break;
        try {
          await ApplicantDraftService.sync('resume', draft);
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
      if (decoded is Map && decoded['status'] == 'ready' &&
          decoded['kind'] == 'resume_builder') {
        unawaited(_restoreDraft());
      } else if (decoded is Map && decoded['status'] == 'draft' &&
          decoded['kind'] == 'resume_builder' && decoded['formData'] is Map) {
        _queueDraft(Map<String, dynamic>.from(decoded['formData'] as Map));
      } else if (decoded is Map && decoded['status'] == 'completed') {
        _builderFinished = true;
        _nextDraft = null;
        // Do not discard the encrypted draft until the backend confirms that
        // the finished PDF AND form fields were persisted successfully.
        widget.onComplete(Map<String, dynamic>.from(decoded));
      }
    } catch (error) {
      debugPrint('[REACT BRIDGE] Ignored invalid resume payload: $error');
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
