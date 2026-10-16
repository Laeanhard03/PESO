/**
 * Sends a structured React workspace result back to Flutter.
 * Native WebViews expose window.FlutterBridge. Flutter Web hosts this app in
 * an iframe, so it receives the same payload via postMessage instead.
 */
export function sendToFlutter(payload) {
  const message = {
    ...payload,
    source: 'peso-react-workspace',
  };

  if (window.FlutterBridge && typeof window.FlutterBridge.postMessage === 'function') {
    window.FlutterBridge.postMessage(JSON.stringify(message));
    return true;
  }

  if (window.parent && window.parent !== window) {
    // The Flutter parent validates the sender origin and payload source.
    window.parent.postMessage(JSON.stringify(message), '*');
    return true;
  }

  return false;
}
