/// Shared category and lifecycle rules for Admin and the job-seeker feed.
class PesoJobCategories {
  PesoJobCategories._();

  static const String walkInApplication = 'walk_in_application';
  static const String localRecruitmentActivity = 'local_recruitment_activity';
  static const String all = 'all';

  static const List<String> choices = <String>[
    walkInApplication,
    localRecruitmentActivity,
  ];

  static String label(String? category) {
    switch (category) {
      case walkInApplication:
        return 'Walk-in Application';
      case localRecruitmentActivity:
        return 'Local Recruitment Activity';
      default:
        return 'Other Job Posting';
    }
  }

  static String labelWithShortName(String? category) =>
      category == localRecruitmentActivity
          ? 'Local Recruitment Activity (LRA)'
          : label(category);

  /// Stored server expiration wins. Legacy LRA records without expiresAt use
  /// createdAt + 24 hours as a compatibility fallback. Walk-in never expires.
  static DateTime? effectiveExpiryAt(Map<String, dynamic> job) {
    final category = job['category']?.toString();
    if (category == walkInApplication) return null;
    final rawExpiry = job['expiresAt'];
    if (rawExpiry != null && rawExpiry.toString().trim().isNotEmpty) {
      final parsed = DateTime.tryParse(rawExpiry.toString());
      if (parsed != null) return parsed.toLocal();
    }
    if (category != localRecruitmentActivity) return null;
    final rawCreatedAt = job['createdAt'];
    if (rawCreatedAt == null) return null;
    return DateTime.tryParse(rawCreatedAt.toString())
        ?.toLocal()
        .add(const Duration(hours: 24));
  }

  static bool isVisible(Map<String, dynamic> job, {DateTime? now}) {
    final status = job['status']?.toString();
    if (status != null && status.isNotEmpty && status != 'active') return false;

    final current = now ?? DateTime.now();
    final category = job['category']?.toString();
    final expiry = effectiveExpiryAt(job);

    // LRA visibility is time-limited. Missing/corrupt timestamps are not a
    // reason to accidentally make a recruitment event permanent.
    if (category == localRecruitmentActivity) {
      return expiry != null && expiry.isAfter(current);
    }
    if (category == walkInApplication) return true;
    return expiry == null || expiry.isAfter(current);
  }

  static String expiryText(Map<String, dynamic> job, {DateTime? now}) {
    if (job['category']?.toString() == walkInApplication) {
      return 'No automatic expiration';
    }
    final expiry = effectiveExpiryAt(job);
    if (expiry == null) return 'Expiration not available';
    final current = now ?? DateTime.now();
    if (!expiry.isAfter(current)) return 'Expired';
    final remaining = expiry.difference(current);
    if (remaining.inHours >= 1) return 'Expires in ${remaining.inHours}h';
    final minutes = remaining.inMinutes < 1 ? 1 : remaining.inMinutes;
    return 'Expires in ${minutes}m';
  }
}
