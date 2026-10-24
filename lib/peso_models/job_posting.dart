/// Shared category and lifecycle rules for Admin and the job-seeker feed.
class PesoJobCategories {
  PesoJobCategories._();

  static const String walkInApplication = 'walk_in_application';
  static const String localRecruitmentActivity = 'local_recruitment_activity';
  static const String seap = 'seap';
  static const String gip = 'gip';
  static const String all = 'all';

  static const List<String> choices = <String>[
    walkInApplication,
    localRecruitmentActivity,
    seap,
    gip,
  ];

  static String label(String? category) {
    switch (category) {
      case walkInApplication:
        return 'Walk-in Application';
      case localRecruitmentActivity:
        return 'Local Recruitment Activity';
      case seap:
        return 'SEAP Program';
      case gip:
        return 'Government Internship Program (GIP)';
      default:
        return 'Other Job Posting';
    }
  }

  static String labelWithShortName(String? category) =>
      category == localRecruitmentActivity
          ? 'Local Recruitment Activity (LRA)'
          : label(category);

  /// The end of the scheduled recruitment day in Asia/Manila wins. Legacy
  /// records use their Philippine publication day, never a rolling 24 hours.
  static DateTime? effectiveExpiryAt(Map<String, dynamic> job) {
    final category = job['category']?.toString();
    if (category == walkInApplication) return null;
    final rawExpiry = job['expiresAt'];
    if (rawExpiry != null && rawExpiry.toString().trim().isNotEmpty) {
      final parsed = DateTime.tryParse(rawExpiry.toString());
      if (parsed != null) return parsed.toLocal();
    }
    if (category != localRecruitmentActivity) return null;
    if (job['isPublicPdfListing'] == true &&
        job['recruitmentDate'] == null && job['recruitmentEndDate'] == null) {
      return null;
    }
    final scheduled = DateTime.tryParse(
      (job['recruitmentEndDate'] ?? job['recruitmentDate'] ?? '').toString());
    final created = DateTime.tryParse(job['createdAt']?.toString() ?? '');
    final philippineDay = scheduled ?? created?.toUtc().add(const Duration(hours: 8));
    if (philippineDay == null) return null;
    return DateTime.utc(philippineDay.year, philippineDay.month,
      philippineDay.day, 15, 59, 59, 999).toLocal();
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
    if (const <String>{walkInApplication, seap, gip}
        .contains(job['category']?.toString())) {
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
