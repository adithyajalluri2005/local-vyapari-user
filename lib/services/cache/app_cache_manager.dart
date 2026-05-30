import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class AppCacheManager extends CacheManager with ImageCacheManager {
  static const _key = 'lvCachedImages';

  static final AppCacheManager _instance = AppCacheManager._();
  factory AppCacheManager() => _instance;

  AppCacheManager._()
      : super(
          Config(
            _key,
            // Keep at most 150 images on disk
            maxNrOfCacheObjects: 150,
            // Evict images older than 7 days
            stalePeriod: const Duration(days: 7),
          ),
        );
}
