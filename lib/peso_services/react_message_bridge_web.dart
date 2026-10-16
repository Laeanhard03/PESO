import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

final StreamController<String> _controller = StreamController<String>.broadcast();
bool _isListening = false;

Stream<String> get reactBridgeMessages {
  if (!_isListening) {
    _isListening = true;
    html.window.onMessage.listen(_handleMessage);
  }
  return _controller.stream;
}

void _handleMessage(html.MessageEvent event) {
  // The dev workspace runs on Vite's configured localhost port. Validate the
  // sender instead of accepting arbitrary postMessage payloads from any site.
  final origin = Uri.tryParse(event.origin);
  final trustedLocalOrigin = origin != null &&
      origin.port == 5173 &&
      (origin.host == 'localhost' ||
          origin.host == '127.0.0.1' ||
          origin.host == '[::1]' ||
          origin.host == '::1');
  if (!trustedLocalOrigin) return;

  final Object? data = event.data;
  if (data is String) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map && decoded['source'] == 'peso-react-workspace') {
        _controller.add(data);
      }
    } on FormatException {
      // Ignore unrelated messages and malformed payloads.
    }
    return;
  }

  if (data is Map && data['source'] == 'peso-react-workspace') {
    _controller.add(jsonEncode(data));
  }
}
