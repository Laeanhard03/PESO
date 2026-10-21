import 'package:url_launcher/url_launcher.dart';

class DocumentPopup {
  static DocumentPopup? open() => null;
  Future<bool> navigate(Uri uri) => launchUrl(
    uri,
    mode: LaunchMode.platformDefault,
    webOnlyWindowName: '_blank',
  );
  void close() {}
}

class DocumentPopupFallback {
  Future<bool> navigate(Uri uri) => launchUrl(
    uri,
    mode: LaunchMode.platformDefault,
    webOnlyWindowName: '_blank',
  );
}
