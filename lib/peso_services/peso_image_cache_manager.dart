import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Shared disk cache for remote imagery. Cached files are retained for a year
/// unless the platform clears app storage or the user removes the app data.
class PesoImageCacheManager {
  PesoImageCacheManager._();

  static final CacheManager instance = CacheManager(
    Config(
      'pesoJobKonekImages',
      stalePeriod: const Duration(days: 365),
      maxNrOfCacheObjects: 500,
    ),
  );

  /// Public, built-in images used by the landing, sign-in, gallery and sample
  /// job screens. Download in the background so these sections can work after
  /// the first successful online launch.
  static const List<String> _knownRemoteImages = <String>[
    'https://images.unsplash.com/photo-1542744173-8e7e53415bb0?ixlib=rb-4.0.3&auto=format&fit=crop&w=400&q=80',
    'https://images.unsplash.com/photo-1517245386807-bb43f82c33c4?ixlib=rb-4.0.3&auto=format&fit=crop&w=400&q=80',
    'https://images.unsplash.com/photo-1528605105345-5344ea20e269?ixlib=rb-4.0.3&auto=format&fit=crop&w=400&q=80',
    'https://images.unsplash.com/photo-1556761175-4b46a572b786?ixlib=rb-4.0.3&auto=format&fit=crop&w=400&q=80',
    'https://images.unsplash.com/photo-1517048676732-d65bc937f952?ixlib=rb-4.0.3&auto=format&fit=crop&w=400&q=80',
    'https://images.unsplash.com/photo-1573164713714-d95e436ab8d6?ixlib=rb-4.0.3&auto=format&fit=crop&w=400&q=80',
    'https://images.unsplash.com/photo-1573164713988-8665fc963095?ixlib=rb-4.0.3&auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1522071820081-009f0129c71c?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1552664730-d307ca884978?ixlib=rb-4.0.3&auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1497215728101-856f4ea42174?ixlib=rb-4.0.3&auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1597872200969-2b65d56bd16b?auto=format&fit=crop&w=600&q=80',
    'https://images.unsplash.com/photo-1556761175-4b46a572b786?auto=format&fit=crop&w=600&q=80',
    'https://images.unsplash.com/photo-1522071820081-009f0129c71c?auto=format&fit=crop&w=600&q=80',
    'https://images.unsplash.com/photo-1497366216548-37526070297c?auto=format&fit=crop&w=600&q=80',
  ];

  static Future<void> preloadKnownImages() async {
    // Flutter Web uses the service worker cache; CacheManager is for native apps.
    if (kIsWeb) return;
    for (var start = 0; start < _knownRemoteImages.length; start += 3) {
      final batch = _knownRemoteImages.skip(start).take(3);
      await Future.wait(batch.map((url) async {
        try {
          await instance.downloadFile(url);
        } catch (error) {
          // Don't prevent the app from starting when an image host is offline.
          debugPrint('[IMAGE_CACHE] Could not pre-cache a public image: $error');
        }
      }));
    }
  }
}

/// Use this provider instead of the default network provider throughout the
/// app so every displayed remote image uses the same disk cache.
class PesoCachedNetworkImageProvider extends CachedNetworkImageProvider {
  PesoCachedNetworkImageProvider(String url)
      : super(url, cacheManager: PesoImageCacheManager.instance);
}
