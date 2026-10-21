import 'dart:typed_data';

import 'package:flutter/material.dart';

class ProfilePdfView extends StatelessWidget {
  const ProfilePdfView({super.key, required this.bytes});
  final Uint8List bytes;
  @override
  Widget build(BuildContext context) => const Center(
    child: Text('Open or download the PDF using your browser to preview it.'),
  );
}

class ProfilePdfDownload {
  static Future<bool> save(Uint8List bytes, String fileName) async => false;
}
