import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../peso_services/peso_api_client.dart';
import '../../peso_services/peso_auth_session.dart';

/// Client-safe error for the Admin Gemini key manager. Never contains a
/// submitted key or raw provider response.
class GeminiKeyApiException implements Exception {
  const GeminiKeyApiException(this.statusCode, this.code, this.message);

  final int statusCode;
  final String code;
  final String message;

  @override
  String toString() => message;
}

/// Injectable contract makes the Admin editor testable without Firebase,
/// a running server, or real provider API calls.
abstract interface class GeminiKeyManagementApi {
  Future<Map<String, dynamic>> listKeys();

  Future<Map<String, dynamic>> createKey({
    required String label,
    required String apiKey,
  });

  Future<Map<String, dynamic>> updateKey(
    String id, {
    String? label,
    String? apiKey,
  });

  Future<Map<String, dynamic>> setKeyEnabled(
    String id, {
    required bool enabled,
  });

  Future<Map<String, dynamic>> deleteKey(String id);

  Future<Map<String, dynamic>> testKey(String id);
}

/// Uses the current PESO session provider, including Firebase and the
/// server-managed SMS session without persisting any API-key text locally.
class PesoGeminiKeyAdminApi implements GeminiKeyManagementApi {
  const PesoGeminiKeyAdminApi({
    http.Client? client,
    Future<String?> Function()? tokenProvider,
  }) : _clientOverride = client,
       _tokenProviderOverride = tokenProvider;

  static final http.Client _defaultClient = http.Client();
  final http.Client? _clientOverride;
  final Future<String?> Function()? _tokenProviderOverride;

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final token =
        await (_tokenProviderOverride?.call() ??
            PesoAuthSession.getBearerToken());
    if (token == null || token.isEmpty) {
      throw const GeminiKeyApiException(
        401,
        'authentication_required',
        'Sign in again before managing Gemini keys.',
      );
    }

    final base = Uri.parse(PesoApiClient.baseUrl);
    final allowedScheme =
        base.scheme == 'https' ||
        (base.scheme == 'http' &&
            <String>{'localhost', '127.0.0.1', '10.0.2.2'}.contains(base.host));
    if (!base.hasAuthority || !allowedScheme) {
      throw const GeminiKeyApiException(
        0,
        'invalid_api_origin',
        'Gemini keys can only be sent to the configured trusted PESO API.',
      );
    }
    final uri = base.replace(
      path: '${base.path.replaceFirst(RegExp(r'/$'), '')}$path',
    );
    final request = http.Request(method, uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json';
    // Browser Fetch rejects GET/HEAD requests with a body. Keep the
    // transport bodyless for read/delete methods; serialize only explicit
    // write payloads so listKeys() can refresh after a successful key save.
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    late final http.Response response;
    try {
      response = await (_clientOverride ?? _defaultClient)
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 25));
    } catch (_) {
      throw const GeminiKeyApiException(
        0,
        'gemini_key_api_unreachable',
        'The PESO API could not be reached. Check that the local API is running.',
      );
    }

    Map<String, dynamic> payload = <String, dynamic>{};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) payload = Map<String, dynamic>.from(decoded);
    } catch (_) {
      // Never display a raw upstream body to the user.
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final status = response.statusCode;
      final code = payload['error']?.toString() ?? 'gemini_key_request_failed';
      final message = status == 401
          ? 'Your sign-in session expired. Sign in again.'
          : status == 403
          ? 'Administrator access is required for Gemini key management.'
          : status == 503
          ? 'Gemini key management is not ready. Check secure API configuration.'
          : status == 400
          ? 'Check the label, submitted key, or confirmation and try again.'
          : 'Gemini key management failed (HTTP $status).';
      throw GeminiKeyApiException(status, code, message);
    }
    return payload;
  }

  @override
  Future<Map<String, dynamic>> listKeys() =>
      _send('GET', '/api/admin/gemini-keys');

  @override
  Future<Map<String, dynamic>> createKey({
    required String label,
    required String apiKey,
  }) => _send(
    'POST',
    '/api/admin/gemini-keys',
    body: <String, dynamic>{'label': label, 'apiKey': apiKey},
  );

  @override
  Future<Map<String, dynamic>> updateKey(
    String id, {
    String? label,
    String? apiKey,
  }) {
    final body = <String, dynamic>{
      ...?(label == null ? null : <String, dynamic>{'label': label}),
      ...?(apiKey == null || apiKey.isEmpty
          ? null
          : <String, dynamic>{'apiKey': apiKey}),
    };
    return _send(
      'PUT',
      '/api/admin/gemini-keys/${Uri.encodeComponent(id)}',
      body: body,
    );
  }

  @override
  Future<Map<String, dynamic>> setKeyEnabled(
    String id, {
    required bool enabled,
  }) => _send(
    'PATCH',
    '/api/admin/gemini-keys/${Uri.encodeComponent(id)}/status',
    body: <String, dynamic>{'enabled': enabled},
  );

  @override
  Future<Map<String, dynamic>> deleteKey(String id) =>
      _send('DELETE', '/api/admin/gemini-keys/${Uri.encodeComponent(id)}');

  @override
  Future<Map<String, dynamic>> testKey(String id) => _send(
    'POST',
    '/api/admin/gemini-keys/${Uri.encodeComponent(id)}/test',
    body: const <String, dynamic>{'confirm': true},
  );
}

class GeminiApiKeyManagementSection extends StatefulWidget {
  const GeminiApiKeyManagementSection({super.key, GeminiKeyManagementApi? api})
    : api = api ?? const PesoGeminiKeyAdminApi();

  final GeminiKeyManagementApi api;

  @override
  State<GeminiApiKeyManagementSection> createState() =>
      _GeminiApiKeyManagementSectionState();
}

class _GeminiApiKeyManagementSectionState
    extends State<GeminiApiKeyManagementSection> {
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();

  List<Map<String, dynamic>> _keys = <Map<String, dynamic>>[];
  bool _loading = true;
  bool _saving = false;
  bool _obscureKey = true;
  bool _managedPoolActivated = false;
  bool? _legacyFallbackConfigured;
  Map<String, dynamic>? _modelQuota;
  String _activeModel = 'Gemini';
  String? _error;
  String? _notice;
  String? _editingId;
  Timer? _healthTimer;

  @override
  void initState() {
    super.initState();
    _reload();
    _healthTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted && !_loading && !_saving) _reload();
    });
  }

  @override
  void dispose() {
    _healthTimer?.cancel();
    _labelController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  String _safeError(Object error, String submittedKey) {
    final String message = error is GeminiKeyApiException
        ? error.message
        : 'The operation could not be completed. Please retry.';
    if (submittedKey.isNotEmpty && message.contains(submittedKey)) {
      return 'The operation failed. The submitted key has not been displayed.';
    }
    return message;
  }

  Future<void> _reload() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final response = await widget.api.listKeys();
      final rawKeys = response['keys'];
      final safeKeys = rawKeys is List
          ? rawKeys
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .where(
                  (item) =>
                      item['id'] is String &&
                      item['label'] is String &&
                      item['maskedSuffix'] is String,
                )
                .toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _keys = safeKeys;
        _managedPoolActivated = response['managedPoolActivated'] == true;
        _activeModel = response['model']?.toString() ?? 'Gemini';
        _modelQuota = response['modelQuota'] is Map
            ? Map<String, dynamic>.from(response['modelQuota'] as Map)
            : null;
        _legacyFallbackConfigured = response['legacyFallbackConfigured'] is bool
            ? response['legacyFallbackConfigured'] as bool
            : null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _safeError(error, _keyController.text);
      });
    }
  }

  void _clearForm() {
    _labelController.clear();
    _keyController.clear();
    _editingId = null;
    _obscureKey = true;
  }

  Future<void> _saveKey() async {
    final label = _labelController.text.trim();
    final submittedKey = _keyController.text;
    if (label.isEmpty || (_editingId == null && submittedKey.trim().isEmpty)) {
      setState(() {
        _error = 'Enter a key label and API key before saving.';
        _notice = null;
      });
      return;
    }
    if (submittedKey.trim().isNotEmpty &&
        RegExp(r'[\r\n]').hasMatch(submittedKey)) {
      setState(() {
        _error = 'The API key must be a single line.';
        _notice = null;
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _notice = null;
    });
    try {
      final response = _editingId == null
          ? await widget.api.createKey(label: label, apiKey: submittedKey)
          : await widget.api.updateKey(
              _editingId!,
              label: label,
              apiKey: submittedKey.trim().isEmpty ? null : submittedKey,
            );
      if (response['ok'] != true) {
        throw const GeminiKeyApiException(
          502,
          'invalid_response',
          'The PESO API did not confirm the key change.',
        );
      }
      if (!mounted) return;
      setState(() {
        _clearForm();
        _saving = false;
        _notice = 'Key saved securely. Only masked metadata is shown below.';
      });
      await _reload();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _safeError(error, submittedKey);
      });
    } finally {
      // Do not retain the submitted key text in this widget after any outcome.
      _keyController.clear();
    }
  }

  void _beginEdit(Map<String, dynamic> key) {
    setState(() {
      _editingId = key['id']?.toString();
      _labelController.text = key['label']?.toString() ?? '';
      _keyController.clear();
      _obscureKey = true;
      _error = null;
      _notice = 'Enter a replacement key, or leave the key field empty to keep the current key.';
    });
  }

  Future<void> _toggleKey(Map<String, dynamic> key, bool enabled) async {
    final id = key['id'].toString();
    try {
      await widget.api.setKeyEnabled(id, enabled: enabled);
      if (!mounted) return;
      setState(() {
        _error = null;
        _notice = enabled ? 'Key enabled.' : 'Key disabled.';
      });
      await _reload();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _safeError(error, ''));
    }
  }

  Future<void> _removeKey(Map<String, dynamic> key) async {
    final id = key['id'].toString();
    final label = key['label']?.toString() ?? 'this key';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Gemini API Key?'),
        content: Text(
          'Remove "$label" from the managed pool? Its encrypted value will be deleted, and this action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: Key('gemini-key-confirm-delete-$id'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove Key'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.api.deleteKey(id);
      if (!mounted) return;
      if (_editingId == id) _clearForm();
      setState(() {
        _error = null;
        _notice = 'Key removed from the managed pool.';
      });
      await _reload();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _safeError(error, ''));
    }
  }

  Future<void> _testKey(Map<String, dynamic> key) async {
    final id = key['id'].toString();
    final label = key['label']?.toString() ?? 'this key';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Test Gemini API Key?'),
        content: Text(
          'This sends one small connectivity request to Google for "$label". It may consume API quota or incur usage charges. It will not automatically retry. Continue only if you understand this cost and quota risk.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: Key('gemini-key-confirm-test-$id'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send One Test Request'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _saving = true;
      _error = null;
      _notice = null;
    });
    try {
      final response = await widget.api.testKey(id);
      final result = response['test'];
      if (response['ok'] != true || result is! Map) {
        throw const GeminiKeyApiException(
          502,
          'invalid_test_response',
          'The PESO API returned an invalid key-test result.',
        );
      }
      final passed = result['passed'] == true;
      final category = result['category']?.toString() ?? 'unknown';
      final retry = result['retryAfterSeconds'];
      if (!mounted) return;
      setState(() {
        _notice = passed
            ? 'Key test passed. Key contents remain hidden.'
            : 'Key test failed ($category).'
                  '${retry is int ? ' Retry after about $retry seconds.' : ''}';
        _saving = false;
      });
      await _reload();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _safeError(error, '');
      });
    }
  }

  String _healthLabel(Map<String, dynamic> key) {
    final health = key['health']?.toString() ?? 'unknown';
    final enabled = key['enabled'] == true;
    if (!enabled) return 'Disabled';
    final quotaUntil = DateTime.tryParse(key['quotaUntil']?.toString() ?? '');
    if (quotaUntil != null && quotaUntil.isAfter(DateTime.now())) {
      final metric = key['quotaMetric']?.toString() ?? 'quota';
      return '$metric exhausted';
    }
    switch (health) {
      case 'ready':
        return 'Ready';
      case 'cooling_down':
        return 'Cooling down';
      case 'attention_required':
        return 'Needs attention';
      case 'configuration_error':
        return 'Configuration error';
      default:
        return 'Status unknown';
    }
  }

  String _dateLabel(dynamic value) {
    if (value == null) return 'Never';
    final date = DateTime.tryParse(value.toString());
    if (date == null) return 'Unknown';
    final local = date.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        return SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Padding(
                padding: EdgeInsets.all(compact ? 12 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Gemini API Keys',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Refresh key status',
                          onPressed: _loading || _saving ? null : _reload,
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Manage server-side Gemini keys. Status refreshes every 45 seconds. Actual limits are per Google Cloud project and model, not per key; project quota cannot be bypassed by key rotation.',
                    ),
                    const SizedBox(height: 16),
                    _buildConfigurationBanner(theme),
                    if (_modelQuota != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        key: const Key('gemini-project-quota-warning'),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E4),
                          border: Border.all(color: const Color(0xFFEBC28A)),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              color: Color(0xFF8C490C),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '$_activeModel: ${_modelQuota!['metric'] ?? 'Quota'} rate limit observed. '
                                'Retry after ${_dateLabel(_modelQuota!['quotaUntil'])}. '
                                '${_modelQuota!['scope'] == 'daily' ? 'Daily quota resets at midnight Pacific Time (3:00 PM PHT during daylight time, 4:00 PM otherwise).' : 'Availability depends on the provider reset and current usage.'}',
                                style: const TextStyle(
                                  color: Color(0xFF6D3910),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      _messageBox(_error!, isError: true),
                    ],
                    if (_notice != null) ...[
                      const SizedBox(height: 12),
                      _messageBox(_notice!, isError: false),
                    ],
                    const SizedBox(height: 20),
                    _buildEditor(compact),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Managed Keys',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text('${_keys.length} keys'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(28),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_keys.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No managed keys saved yet. The environment fallback remains eligible until the first managed key is saved.',
                          ),
                        ),
                      )
                    else
                      ..._keys.map(_buildKeyCard),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildConfigurationBanner(ThemeData theme) {
    final detail = _managedPoolActivated
        ? 'Managed pool is active. Only enabled, eligible managed keys are used.'
        : _legacyFallbackConfigured == true
        ? 'Legacy environment key is currently eligible until you save the first managed key.'
        : _legacyFallbackConfigured == false
        ? 'No legacy environment key is configured. Save at least one managed key to enable Gemini.'
        : 'Managed pool has not been activated. Legacy fallback status is not available yet.';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined),
          const SizedBox(width: 10),
          Expanded(child: Text(detail)),
        ],
      ),
    );
  }

  Widget _buildEditor(bool compact) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 14 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _editingId == null ? 'Add API Key' : 'Edit Managed Key',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('gemini-key-label-field'),
              controller: _labelController,
              enabled: !_saving,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Key label',
                hintText: 'e.g. Main project key',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('gemini-key-value-field'),
              controller: _keyController,
              enabled: !_saving,
              obscureText: _obscureKey,
              autocorrect: false,
              enableSuggestions: false,
              maxLength: 512,
              decoration: InputDecoration(
                labelText: _editingId == null
                    ? 'Gemini API key'
                    : 'Replacement key (optional)',
                hintText: _editingId == null
                    ? 'Enter key — it will be encrypted by the server'
                    : 'Leave blank to keep the existing key',
                helperText: 'Sent only to the trusted PESO API; never stored in this device or displayed in the key list.',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _obscureKey ? 'Show key input' : 'Hide key input',
                  onPressed: () => setState(() => _obscureKey = !_obscureKey),
                  icon: Icon(
                    _obscureKey
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.end,
              children: [
                if (_editingId != null)
                  OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () => setState(() {
                            _clearForm();
                            _notice = null;
                            _error = null;
                          }),
                    child: const Text('Cancel Edit'),
                  ),
                FilledButton.icon(
                  onPressed: _saving ? null : _saveKey,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _editingId == null ? Icons.add : Icons.save_outlined,
                        ),
                  label: Text(
                    _saving
                        ? 'Saving...'
                        : (_editingId == null ? 'Save Key' : 'Save Changes'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyCard(Map<String, dynamic> key) {
    final id = key['id'].toString();
    final enabled = key['enabled'] == true;
    final status = _healthLabel(key);
    final cooldown = key['cooldownUntil'];
    final quotaUntil = DateTime.tryParse(key['quotaUntil']?.toString() ?? '');
    final exhausted = quotaUntil != null && quotaUntil.isAfter(DateTime.now());
    return Card(
      key: Key('gemini-key-card-$id'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Text(
                  key['label']?.toString() ?? 'Unnamed key',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(key['maskedSuffix']?.toString() ?? '••••'),
                Chip(label: Text(status)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                Text('Last used: ${_dateLabel(key['lastUsedAt'])}'),
                Text('Last tested: ${_dateLabel(key['lastTestedAt'])}'),
                if (key['lastErrorCategory'] != null)
                  Text('Last error: ${key['lastErrorCategory']}'),
                if (cooldown != null)
                  Text('Cooldown until: ${_dateLabel(cooldown)}'),
                if (exhausted)
                  Text(
                    'Model: ${key['quotaModel'] ?? 'unknown'}; ${key['quotaScope'] == 'daily'
                        ? 'Daily quota (resets midnight Pacific)'
                        : key['quotaScope'] == 'minute'
                        ? 'Per-minute quota'
                        : 'Quota limit detected'}; retry after ${_dateLabel(key['quotaUntil'])}',
                    style: const TextStyle(
                      color: Colors.deepOrange,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (key['lastQuotaAt'] != null && !exhausted)
                  Text(
                    'Last observed quota limit: ${_dateLabel(key['lastQuotaAt'])}',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: enabled,
                      onChanged: _saving
                          ? null
                          : (value) => _toggleKey(key, value),
                    ),
                    const Text('Enabled'),
                  ],
                ),
                OutlinedButton.icon(
                  key: Key('gemini-key-test-$id'),
                  onPressed: _saving ? null : () => _testKey(key),
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('Test Key'),
                ),
                OutlinedButton.icon(
                  onPressed: _saving ? null : () => _beginEdit(key),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
                OutlinedButton.icon(
                  key: Key('gemini-key-delete-$id'),
                  onPressed: _saving ? null : () => _removeKey(key),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageBox(String message, {required bool isError}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError
            ? Colors.red.withValues(alpha: .08)
            : Colors.green.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isError
              ? Colors.red.withValues(alpha: .30)
              : Colors.green.withValues(alpha: .30),
        ),
      ),
      child: Text(message),
    );
  }
}
