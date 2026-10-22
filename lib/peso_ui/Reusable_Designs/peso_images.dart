import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../peso_services/peso_image_cache_manager.dart';

/// Local image files bundled with JobKonek. These survive restarts and do not
/// depend on browser cache, remote CORS, or image-host availability.
class PesoImageAssets {
  PesoImageAssets._();

  static const String heroBanner = 'lib/assets/peso_cover.jpg';
  static const String programsBanner = 'lib/assets/peso_programs_workshop.jpg';
  static const String aboutBanner = 'lib/assets/peso_about_reference.jpg';
  static const String jobDefault = 'lib/assets/peso_job_default.jpg';
  static const String jobTechnology = 'lib/assets/peso_job_technology.jpg';

  /// PESO Montalban recruitment and Mega Job Fair photographs supplied in the
  /// Google Drive reference archive (2026-10-21).
  static const List<String> gallery = <String>[
    'lib/assets/peso_gallery/peso_local_recruitment_one.jpg',
    'lib/assets/peso_gallery/peso_local_recruitment_two.jpg',
    'lib/assets/peso_gallery/peso_local_recruitment_tre.jpg',
    'lib/assets/peso_gallery/peso_local_recruitment_four.jpg',
    'lib/assets/peso_gallery/peso_local_recruitment_five.jpg',
    'lib/assets/peso_gallery/peso_local_recruitment_six.jpg',
    'lib/assets/peso_gallery/peso_mega_jobfair_m1.jpg',
    'lib/assets/peso_gallery/peso_mega_jobfair_m2.jpg',
    'lib/assets/peso_gallery/peso_mega_jobfair_m3.jpg',
    'lib/assets/peso_gallery/peso_mega_jobfair_m5.jpg',
    'lib/assets/peso_gallery/peso_mega_jobfair_m6.jpg',
    'lib/assets/peso_gallery/peso_mega_jobfair_m7.jpg',
    'lib/assets/peso_gallery/peso_mega_jobfair_m8.jpg',
    'lib/assets/peso_gallery/peso_mega_jobfair_m9.jpg',
    'lib/assets/peso_gallery/peso_mega_jobfair_m10.jpg',
    'lib/assets/peso_gallery/peso_mega_jobfair_m11.jpg',
    'lib/assets/peso_gallery/peso_mega_jobfair_m12.jpg',
    'lib/assets/peso_gallery/peso_mega_jobfair_m13.jpg',
    'lib/assets/peso_gallery/peso_mega_jobfair_m14.jpg',
    'lib/assets/peso_gallery/peso_mega_jobfair_m15.jpg',
    // Pre-existing reference photographs remain in the rotation.
    'lib/assets/peso_gallery_conference.jpg',
    'lib/assets/peso_gallery_workspace.jpg',
    'lib/assets/peso_gallery_team.jpg',
    'lib/assets/peso_gallery_meeting.jpg',
    'lib/assets/peso_gallery_event.jpg',
    'lib/assets/peso_gallery_career.jpg',
  ];

  /// Employer and partner marks supplied in the same reference archive.
  static const List<({String name, String asset})>
  partnerLogos = <({String name, String asset})>[
    (name: 'Jollibee', asset: 'lib/assets/peso_partners/JOLLIBEE LOGO.png'),
    (
      name: 'EEI Corporation',
      asset: 'lib/assets/peso_partners/EEI CORPORATION LOGO.png',
    ),
    (name: 'Savemore', asset: 'lib/assets/peso_partners/SAVEMORE.jpg'),
    (name: 'Sagility', asset: 'lib/assets/peso_partners/SAGULITIY.jpg'),
    (name: 'JRCC', asset: 'lib/assets/peso_partners/JRCC.jpg'),
    (name: 'Shopwise', asset: 'lib/assets/peso_partners/SHOPWISE.jpg'),
    (name: 'Ruder Spark', asset: 'lib/assets/peso_partners/RUDER SPARK.jpg'),
    (name: 'OmniCores', asset: 'lib/assets/peso_partners/OMNICORES.png'),
    (name: 'Robinsons', asset: 'lib/assets/peso_partners/ROBINSON.png'),
    (name: 'Excel Source', asset: 'lib/assets/peso_partners/EXCEL SOURCE.jpg'),
    (name: 'SM', asset: 'lib/assets/peso_partners/SM.png'),
    (name: 'JobNet', asset: 'lib/assets/peso_partners/joBNET.png'),
    (name: 'Puregold', asset: 'lib/assets/peso_partners/PUREGOLD.webp'),
    (name: 'Avilon', asset: 'lib/assets/peso_partners/AVILON.png'),
    (name: 'Xentro Mall', asset: 'lib/assets/peso_partners/XENTRO MALL.jpg'),
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
