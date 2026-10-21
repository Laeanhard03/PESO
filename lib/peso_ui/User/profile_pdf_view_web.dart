// Web-only PDF preview. The Blob stays in this browser and is released on close.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart';

class ProfilePdfView extends StatefulWidget {
  const ProfilePdfView({super.key, required this.bytes});
  final Uint8List bytes;
  @override
  State<ProfilePdfView> createState() => _ProfilePdfViewState();
}

class _ProfilePdfViewState extends State<ProfilePdfView> {
  late String _objectUrl;
  @override
  void initState() {
    super.initState();
    _objectUrl = html.Url.createObjectUrlFromBlob(
      html.Blob(<dynamic>[widget.bytes], 'application/pdf'),
    );
  }

  @override
  void didUpdateWidget(covariant ProfilePdfView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.bytes, widget.bytes)) {
      html.Url.revokeObjectUrl(_objectUrl);
      _objectUrl = html.Url.createObjectUrlFromBlob(
        html.Blob(<dynamic>[widget.bytes], 'application/pdf'),
      );
    }
  }

  @override
  void dispose() {
    html.Url.revokeObjectUrl(_objectUrl);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView.fromTagName(
    key: ValueKey<String>(_objectUrl),
    tagName: 'iframe',
    onElementCreated: (Object element) {
      (element as html.IFrameElement)
        ..src = _objectUrl
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.border = '0'
        ..title = 'Private PDF preview';
    },
  );
}

class ProfilePdfDownload {
  static Future<bool> openForPrint(Uint8List bytes) async {
    final url = html.Url.createObjectUrlFromBlob(
      html.Blob(<dynamic>[bytes], 'application/pdf'),
    );
    try {
      // Open the authenticated bytes in the browser PDF toolbar for printing.
      html.window.open(url, '_blank');
      await Future<void>.delayed(const Duration(minutes: 1));
      return true;
    } catch (_) {
      return false;
    } finally {
      html.Url.revokeObjectUrl(url);
    }
  }

  static Future<bool> save(Uint8List bytes, String fileName) async {
    final url = html.Url.createObjectUrlFromBlob(
      html.Blob(<dynamic>[bytes], 'application/pdf'),
    );
    try {
      final anchor = html.AnchorElement(href: url)
        ..download = fileName
        ..style.display = 'none';
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      // Allow the download to start before discarding the private object URL.
      await Future<void>.delayed(const Duration(seconds: 2));
      return true;
    } catch (_) {
      return false;
    } finally {
      html.Url.revokeObjectUrl(url);
    }
  }
}
