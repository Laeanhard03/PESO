import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../peso_services/peso_image_cache_manager.dart';

/// Local image files bundled with JobKonek. These survive restarts and do not
/// depend on browser cache, remote CORS, or image-host availability.
class PesoImageAssets {
  PesoImageAssets._();

  static const String heroBanner = 'lib/assets/peso_hero_career.jpg';
  static const String programsBanner = 'lib/assets/peso_programs_workshop.jpg';
  static const String aboutBanner = 'lib/assets/peso_about_team.jpg';
  static const String jobDefault = 'lib/assets/peso_job_default.jpg';
  static const String jobTechnology = 'lib/assets/peso_job_technology.jpg';

  static const List<String> gallery = <String>[
    'lib/assets/peso_gallery_conference.jpg',
    'lib/assets/peso_gallery_workspace.jpg',
    'lib/assets/peso_gallery_team.jpg',
    'lib/assets/peso_gallery_meeting.jpg',
    'lib/assets/peso_gallery_event.jpg',
    'lib/assets/peso_gallery_career.jpg',
  ];

  /// Choose a bundled visual from the job's existing metadata; this changes no
  /// job data and is only a fallback when the API did not provide usable art.
  /// Stable visual variety across jobs, avoiding repeated generic office photos.
  /// All photos are bundled Pexels Free License assets; no new network request
  /// is made for every scrolled job tile. Real employer artwork takes priority.
  static String jobFallbackFor(Map<String, dynamic>? job) {
    final title = (job?['title'] ?? '').toString().toLowerCase();
    final haystack = [
      title,
      (job?['industry'] ?? '').toString().toLowerCase(),
      (job?['category'] ?? '').toString().toLowerCase(),
    ].join(' ');
    final prefix = 'lib/assets/job_photos/';
    final List<String> pool;

    if (RegExp(r'paint|spray|auto.?body|body.?shop').hasMatch(title)) {
      pool = ['painter_1.jpg', 'painter_2.jpg'];
    } else if (RegExp(r'auto.?electric|electrician|electrical|wiring')
        .hasMatch(title)) {
      pool = ['electrician_1.jpg', 'mechanic_1.jpg'];
    } else if (RegExp(
      r'bulldozer|excavat|backhoe|heavy.?equipment|grader|crane|operator|loader',
    ).hasMatch(title)) {
      pool = ['equipment_1.jpg', 'equipment_2.jpg', 'equipment_3.jpg'];
    } else if (RegExp(r'mechanic|automotive|vehicle|auto.?technician|repair')
        .hasMatch(title)) {
      pool = ['mechanic_1.jpg', 'mechanic_2.jpg'];
    } else if (RegExp(r'warehouse|forklift|logistic|inventory|stockroom')
        .hasMatch(haystack)) {
      pool = ['warehouse_1.jpg', 'warehouse_2.jpg', 'warehouse_3.jpg'];
    } else if (RegExp(
      r'construction|labor|builder|carpenter|mason|foreman|civil|site',
    ).hasMatch(haystack)) {
      pool = [
        'construction_1.jpg',
        'construction_3.jpg',
        'equipment_1.jpg',
        'equipment_2.jpg',
        'equipment_3.jpg',
      ];
    } else if (RegExp(
      r'develop|program|data|software|tech|network|computer|it support',
    ).hasMatch(haystack)) {
      pool = ['office_1.jpg', 'office_2.jpg', 'warehouse_2.jpg'];
    } else if (RegExp(
      r'account|admin|office|clerical|secretary|encoder|assistant',
    ).hasMatch(haystack)) {
      pool = ['office_1.jpg', 'office_2.jpg'];
    } else {
      pool = [
        'construction_1.jpg',
        'construction_3.jpg',
        'warehouse_1.jpg',
        'office_1.jpg',
        'office_2.jpg',
      ];
    }
    final identity = [
      (job?['id'] ?? '').toString(),
      (job?['title'] ?? '').toString(),
      (job?['company'] ?? '').toString(),
    ].join('|');
    var hash = 2166136261;
    for (final code in identity.codeUnits) {
      hash = ((hash ^ code) * 16777619) & 0x7fffffff;
    }
    return prefix + pool[hash % pool.length];
  }
}

/// Loads remote photos when supplied, but always displays a bundled local image
/// while loading and whenever the URL is blank, invalid, blocked, or offline.
/// Native platforms use the shared long-lived disk cache; web uses the browser
/// cache/service worker because cached_network_image has limited web caching.
class PesoNetworkImage extends StatelessWidget {
  const PesoNetworkImage({
    super.key,
    required this.imageUrl,
    required this.fallbackAsset,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.alignment = Alignment.center,
  });

  final String? imageUrl;
  final String fallbackAsset;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final rawUrl = imageUrl?.trim() ?? '';
    final uri = Uri.tryParse(rawUrl);
    final isPublicHttpUrl =
        uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;

    if (!isPublicHttpUrl) {
      return Image.asset(
        fallbackAsset,
        fit: fit,
        width: width,
        height: height,
        alignment: alignment,
        errorBuilder: (_, _, _) => _iconFallback(),
      );
    }

    return CachedNetworkImage(
      imageUrl: uri.toString(),
      cacheManager: kIsWeb ? null : PesoImageCacheManager.instance,
      fit: fit,
      width: width,
      height: height,
      alignment: alignment,
      placeholder: (_, _) => Image.asset(
        fallbackAsset,
        fit: fit,
        width: width,
        height: height,
        alignment: alignment,
        errorBuilder: (_, _, _) => _iconFallback(),
      ),
      errorWidget: (_, _, _) => Image.asset(
        fallbackAsset,
        fit: fit,
        width: width,
        height: height,
        alignment: alignment,
        errorBuilder: (_, _, _) => _iconFallback(),
      ),
    );
  }

  Widget _iconFallback() => const ColoredBox(
    color: Color(0xFFE8F0E7),
    child: Center(
      child: Icon(
        Icons.work_outline_rounded,
        color: Color(0xFF2E7D32),
        size: 40,
      ),
    ),
  );
}
