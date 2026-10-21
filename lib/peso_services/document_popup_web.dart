import 'package:url_launcher/url_launcher.dart';

import 'dart:html' as html;

class DocumentPopup {
  DocumentPopup._(this._tab);
  final html.WindowBase _tab;
  static DocumentPopup? open() {
    final tab = html.window.open('', '_blank');
    return DocumentPopup._(tab);
  }

  Future<bool> navigate(Uri uri) async {
    try {
      _tab.location.href = uri.toString();
      return true;
    } catch (_) {
      close();
      return false;
    }
  }

  void close() {
    try {
      _tab.close();
    } catch (_) {}
  }
}

class DocumentPopupFallback {
  Future<bool> navigate(Uri uri) => launchUrl(
    uri,
    mode: LaunchMode.platformDefault,
    webOnlyWindowName: '_blank',
  );
}
