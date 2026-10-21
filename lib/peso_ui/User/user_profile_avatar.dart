import 'dart:typed_data';

import 'package:flutter/material.dart';

/// A private profile picture or a local, license-free avatar preset.
/// Photos are fetched only through PESO's authenticated owner-only API.
const pesoAvatarStyles = <String>['leaf', 'briefcase', 'sun', 'person'];

IconData pesoAvatarIcon(String value) {
  switch (value) {
    case 'leaf':
      return Icons.spa_rounded;
    case 'briefcase':
      return Icons.work_rounded;
    case 'sun':
      return Icons.wb_sunny_rounded;
    default:
      return Icons.person_rounded;
  }
}

class PesoProfileAvatar extends StatelessWidget {
  const PesoProfileAvatar({
    super.key,
    this.style = 'person',
    this.photoBytes,
    this.radius = 26,
  });
  final String style;
  final Uint8List? photoBytes;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final photo =
        style == 'photo' && photoBytes != null && photoBytes!.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFDBF0E1),
      foregroundColor: const Color(0xFF236349),
      backgroundImage: photo ? MemoryImage(photoBytes!) : null,
      child: photo ? null : Icon(pesoAvatarIcon(style), size: radius * 1.1),
    );
  }
}
