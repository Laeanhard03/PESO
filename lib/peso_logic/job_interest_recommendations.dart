/// Interest-first ordering for existing verified public postings.
/// This is NOT a qualification predictor or an invented AI match percentage.
/// Go mini-AI scores are displayed only when they came from a ready inference.
const _interestFamilies = <String, List<String>>{
  'IT': <String>[
    'information technology',
    'computer',
    'software',
    'programmer',
    'developer',
    'technical support',
    'tech support',
    'web',
    'network',
    'data entry',
    'encoder',
    'it',
    'help desk',
  ],
  'Mall / Retail': <String>[
    'mall',
    'retail',
    'cashier',
    'sales associate',
    'store clerk',
    'sales crew',
    'sales staff',
    'merchandis',
    'stock clerk',
    'salesperson',
    'sales assistant',
    'shop assistant',
  ],
  'Restaurant / Food': <String>[
    'restaurant',
    'food',
    'kitchen',
    'cook',
    'chef',
    'waiter',
    'waitress',
    'barista',
    'dining',
    'service crew',
    'server',
    'food handler',
  ],
};

bool _containsPhrase(String haystack, String phrase) {
  final escaped = RegExp.escape(phrase.toLowerCase());
  return RegExp('(^|[^a-z])$escaped([^a-z]|\$)')
      .hasMatch(haystack.toLowerCase());
}

/// Stated occupational interests, from applicant-edited NSRP fields.
List<String> recognizedJobInterests(String preferred) {
  final lower = preferred.toLowerCase();
  final result = <String>[];
  for (final entry in _interestFamilies.entries) {
    if (entry.value.any((phrase) => _containsPhrase(lower, phrase)) ||
        (entry.key == 'IT' && _containsPhrase(lower, 'technology'))) {
      result.add(entry.key);
    }
  }
  return result;
}

/// Rank currently published postings without pretending a semantic match
/// indicates the applicant meets mandatory certifications/experience.
List<Map<String, dynamic>> rankJobOpportunities(
  List<Map<String, dynamic>> jobs, {
  required String preferredOccupations,
  List<String> sourceSupportedSkills = const <String>[],
  Map<String, dynamic>? goMatching,
}) {
  final interests = recognizedJobInterests(preferredOccupations);
  final rawGo =
      goMatching?['status'] == 'ready' && goMatching?['results'] is List
      ? goMatching!['results'] as List
      : const [];
  final goScores = <String, num>{
    for (final row in rawGo.whereType<Map>())
      if (row['jobId']?.toString().isNotEmpty == true &&
          row['score'] is num &&
          (row['score'] as num) >= 0 &&
          (row['score'] as num) <= 100)
        row['jobId'].toString(): row['score'] as num,
  };

  final prepared = <({int index, int priority, Map<String, dynamic> job})>[];
  for (var index = 0; index < jobs.length; index++) {
    final job = jobs[index];
    final title = (job['title'] ?? '').toString().toLowerCase();
    final roleTitle = title.split(' — ').first;
    final matchedFamilies = interests
        .where(
          (interest) => _interestFamilies[interest]!.any(
            (term) => _containsPhrase(roleTitle, term),
          ),
        )
        .toList();

    final occupationTerms = preferredOccupations
        .toLowerCase()
        .split(RegExp(r'[,;/\n]+'))
        .map((text) => text.trim())
        .where(
          (text) =>
              text.length >= 4 &&
              text != 'restaurant' &&
              text != 'mall' &&
              text != 'information technology',
        )
        .toList();
    final directMatch = occupationTerms.any(
      (phrase) => _containsPhrase(roleTitle, phrase),
    );

    final verifiedEvidence = sourceSupportedSkills
        .map((skill) => skill.trim().toLowerCase())
        .where((skill) => skill.length >= 4 && skill.length <= 90)
        .toSet();
    final requirementText = (job['reqs'] is List
        ? (job['reqs'] as List).join(' ')
        : job['requirements'] is List
        ? (job['requirements'] as List).join(' ')
        : '').toLowerCase();
    final detailText = [
      roleTitle,
      requirementText,
      (job['description'] ?? '').toString().toLowerCase().substring(
        0,
        (job['description'] ?? '').toString().length.clamp(0, 1500),
      ),
    ].join(' ');
    final verifiedSkills = verifiedEvidence
        .where((term) => _containsPhrase(detailText, term))
        .length.clamp(0, 5);
    final jobId = job['id']?.toString() ?? '';
    final modelScore = goScores[jobId];
    // Job-specific posts come first; employer-wide notices are not a career
    // recommendation just because they mention many unrelated positions.
    final notice = job['aiListingKind'] == 'notice';
    final hasInterest = matchedFamilies.isNotEmpty || directMatch;
    final priority =
        (hasInterest ? 100 : 0) +
        (directMatch ? 35 : 0) +
        (verifiedSkills * 8) +
        (modelScore != null ? (modelScore / 4).round() : 0) -
        (notice ? 35 : 0);

    prepared.add((
      index: index,
      priority: priority,
      job: <String, dynamic>{
        ...job,
        'suggestedForInterest': (hasInterest || verifiedSkills > 0) && !notice,
        if ((hasInterest || verifiedSkills > 0) && !notice)
          'suggestionReason': matchedFamilies.isNotEmpty
              ? 'Your interests: ${matchedFamilies.join(', ')}'
              : directMatch
              ? 'Your preferred occupation'
              : 'Related to the work or skills saved in your NSRP/resume',
        if (modelScore != null) 'match': modelScore.round(),
      },
    ));
  }
  prepared.sort((a, b) {
    final compared = b.priority.compareTo(a.priority);
    return compared != 0 ? compared : a.index.compareTo(b.index);
  });
  return prepared.map((entry) => entry.job).toList();
}
