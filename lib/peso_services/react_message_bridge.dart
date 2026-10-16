import 'react_message_bridge_stub.dart'
    if (dart.library.html) 'react_message_bridge_web.dart' as implementation;

/// Stream of JSON payloads sent by the React workspace iframe on Flutter Web.
/// Native WebViews use the FlutterBridge JavaScript channel instead.
Stream<String> get reactBridgeMessages => implementation.reactBridgeMessages;
