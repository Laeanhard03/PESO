// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_interop';

import 'package:web/web.dart' as web;

final StreamController<String> _controller =
    StreamController<String>.broadcast();
bool _isListening = false;

const _configuredWorkspaceUrl = String.fromEnvironment(
  'PESO_NSRP_WORKSPACE_URL',
  defaultValue: '',
);

/// Only the configured NSRP origin and (for a frame) its exact path are trusted.
bool _isTrustedWorkspaceUri(Uri? uri, {bool checkPath = false}) {
  if (uri == null ||
      !const ['http', 'https'].contains(uri.scheme) ||
      uri.host.isEmpty) {
    return false;
  }
  final configuredString = _configuredWorkspaceUrl.trim();
  if (configuredString.isNotEmpty) {
    final configured = Uri.tryParse(configuredString);
    if (configured == null ||
        !const ['http', 'https'].contains(configured.scheme) ||
        configured.host.isEmpty ||
        uri.origin != configured.origin) {
      return false;
    }
    if (!checkPath) return true;
    final configuredPath = configured.path.isEmpty ? '/' : configured.path;
    return uri.path == configuredPath ||
        (configuredPath == '/' && uri.path == '/resume');
  }
  // Backwards-compatible local Vite server. Public builds must configure a
  // reachable NSRP workspace URL instead of relying on visitor localhost.
  return uri.port == 5173 &&
      const ['localhost', '127.0.0.1', '::1'].contains(uri.host);
}

Iterable<html.IFrameElement> _trustedWorkspaceFrames() sync* {
  for (final element in html.document.querySelectorAll('iframe')) {
    if (element is! html.IFrameElement) continue;
    if (_isTrustedWorkspaceUri(
      Uri.tryParse(element.src ?? ''),
      checkPath: true,
    )) {
      yield element;
    }
  }
}

Stream<String> get reactBridgeMessages {
  if (!_isListening) {
    _isListening = true;
    // package:web exposes the native window reference. Dart's legacy
    // dart:html wrappers are not guaranteed to compare equal even when the
    // underlying JavaScript WindowProxy is exactly the same instance.
    web.window.addEventListener(
      'message',
      ((web.Event event) => _handleMessage(event as web.MessageEvent)).toJS,
    );
  }
  return _controller.stream;
}

void _handleMessage(web.MessageEvent event) {
  if (!_isTrustedWorkspaceUri(Uri.tryParse(event.origin))) return;
  final source = event.source;
  if (source == null) return;

  // Check the sender window as well as its origin. An arbitrary iframe on a
  // trusted host must not be allowed to submit or impersonate the NSRP form.
  final frames = web.document.querySelectorAll('iframe');
  var fromWorkspace = false;
  for (var index = 0; index < frames.length; index++) {
    final node = frames.item(index);
    if (node == null) continue;
    final iframe = node as web.HTMLIFrameElement;
    if (!_isTrustedWorkspaceUri(Uri.tryParse(iframe.src), checkPath: true)) {
      continue;
    }
    if (jsIdentical(iframe.contentWindow, source)) {
      fromWorkspace = true;
      break;
    }
  }
  if (!fromWorkspace) return;

  final Object? data = event.data?.dartify();
  if (data is String) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map && decoded['source'] == 'peso-react-workspace') {
        _controller.add(data);
      }
    } on FormatException {
      // Ignore unrelated and malformed postMessage payloads.
    }
  } else if (data is Map && data['source'] == 'peso-react-workspace') {
    _controller.add(jsonEncode(data));
  }
}

/// Transfer private fields only to the selected workspace at an exact origin.
void postReactNsrpPrefill(Map<String, dynamic> formData) {
  final json = jsonEncode(<String, dynamic>{
    'source': 'peso-flutter',
    'event': 'nsrp-prefill',
    'formData': formData,
  });
  for (final frame in _trustedWorkspaceFrames()) {
    final uri = Uri.tryParse(frame.src ?? '');
    if (uri == null) continue;
    frame.contentWindow?.postMessage(json, uri.origin);
  }
}
