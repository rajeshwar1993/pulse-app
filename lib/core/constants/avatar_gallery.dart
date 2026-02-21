class AvatarGallery {
  // Pre-defined avatar seeds for consistent gallery
  static const List<String> seeds = [
    'felix',
    'aneka',
    'sam',
    'charlie',
    'alex',
    'jordan',
    'taylor',
    'morgan',
    'casey',
    'riley',
    'avery',
    'quinn',
    'sage',
    'river',
    'skyler',
  ];

  /// Generate list of avatar URLs using DiceBear API
  static List<String> getAvatarUrls() {
    return seeds
        .map((seed) =>
            'https://api.dicebear.com/7.x/avataaars/png?seed=$seed')
        .toList();
  }

  /// Get avatar URL for a specific seed
  static String getAvatarUrl(String seed) {
    return 'https://api.dicebear.com/7.x/avataaars/png?seed=$seed';
  }
}
