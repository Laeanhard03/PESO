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

  /// Neutral fallback; never suggest a stock photo belongs to an employer.
  /// An actual stored employer image takes priority in PesoNetworkImage.
  static String jobFallbackFor(Map<String, dynamic>? job) => jobDefault;
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
