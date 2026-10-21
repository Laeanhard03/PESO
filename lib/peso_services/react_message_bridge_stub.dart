import 'dart:async';

/// Non-web platforms receive messages through WebView's JavaScript channel.
Stream<String> get reactBridgeMessages => const Stream<String>.empty();

void postReactWorkspaceMessage(Map<String, dynamic> payload) {}
void postReactNsrpPrefill(Map<String, dynamic> formData) {}
