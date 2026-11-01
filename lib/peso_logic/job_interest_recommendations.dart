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
  final goEvidence = <String, Map<dynamic, dynamic>>{
    for (final row in rawGo.whereType<Map>())
      if (row['jobId']?.toString().isNotEmpty == true)
        row['jobId'].toString(): row,
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
    final requirementText =
        (job['reqs'] is List
                ? (job['reqs'] as List).join(' ')
                : job['requirements'] is List
                ? (job['requirements'] as List).join(' ')
                : '')
            .toLowerCase();
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
        .length
        .clamp(0, 5);
    final jobId = job['id']?.toString() ?? '';
    final model = goEvidence[jobId];
    final rawDiscoveryRank = model?['opportunityRank'];
    final discoveryRank =
        rawDiscoveryRank is num &&
            rawDiscoveryRank >= 0 &&
            rawDiscoveryRank <= 100
        ? rawDiscoveryRank.toInt()
        : 0;
    final opportunityPathway = model?['opportunityPathway']?.toString() ?? '';
    final trainingPathway =
        opportunityPathway == 'training_pathway' && discoveryRank > 0;
    final transferableCareer =
        opportunityPathway == 'transferable_skills' && discoveryRank > 0;
    final rawScore = model?['score'];
    final matchedFields = model?['matchedOccupationFields'];
    final recordedGaps = model?['missingMandatory'];
    final hasKnownGap = recordedGaps is List && recordedGaps.isNotEmpty;
    final supportedRoleEvidence =
        model?['assessmentBasis'] == 'role_attributed_requirements' &&
        (model?['roleCriteriaCount'] is num) &&
        (model!['roleCriteriaCount'] as num) > 0 &&
        (model['confidence'] == 'medium' || model['confidence'] == 'moderate');
    final validScore = rawScore is num && rawScore >= 0 && rawScore <= 100;
    // These are occupation-model scores, not probabilities of being hired.
    // Do not promote uncertain job-title clues to numeric "matches".
    final modelScore = supportedRoleEvidence && !hasKnownGap && validScore
        ? rawScore
        : null;
    final careerFieldToExplore =
        matchedFields is List &&
        matchedFields.isNotEmpty &&
        !supportedRoleEvidence;
    // Job-specific posts come first; employer-wide notices are not a career
    // recommendation just because they mention many unrelated positions.
    final notice = job['aiListingKind'] == 'notice';
    final hasInterest = matchedFamilies.isNotEmpty || directMatch;
    final priority =
        (hasInterest ? 100 : 0) +
        (directMatch ? 35 : 0) +
        (verifiedSkills * 8) +
        (careerFieldToExplore ? 10 : 0) +
        (discoveryRank / 2).round() +
        (modelScore != null ? (modelScore / 4).round() : 0) -
        (notice ? 35 : 0);

    prepared.add((
      index: index,
      priority: priority,
      job: <String, dynamic>{
        ...job,
        'suggestedForInterest':
            (hasInterest ||
                verifiedSkills > 0 ||
                modelScore != null ||
                careerFieldToExplore ||
                trainingPathway ||
                transferableCareer) &&
            !notice,
        if ((hasInterest ||
                verifiedSkills > 0 ||
                modelScore != null ||
                careerFieldToExplore ||
                trainingPathway ||
                transferableCareer) &&
            !notice)
          'suggestionReason': matchedFamilies.isNotEmpty
              ? 'This job is related to the work you want to do.'
              : directMatch
              ? 'This job is similar to the work you want.'
              : verifiedSkills > 0
              ? 'You listed skills that may help with this job. Check the details.'
              : trainingPathway
              ? 'The job title says trainee or helper. Ask PESO what you need.'
              : transferableCareer
              ? 'Skills you listed may help with this job. Ask PESO what it needs.'
              : 'This job may interest you. Check the details before applying.',
        if (trainingPathway && !notice) 'trainingPathway': true,
        if (transferableCareer && !notice) 'transferableCareer': true,
        if (careerFieldToExplore && !notice) 'careerFieldToExplore': true,
        if (hasKnownGap && !notice) 'roleRequirementsToReview': true,
        // The model score affects ordering, but is not a hiring percentage.
        // Job cards show a plain explanation instead of a numeric "match".
      },
    ));
  }
  prepared.sort((a, b) {
    final compared = b.priority.compareTo(a.priority);
    return compared != 0 ? compared : a.index.compareTo(b.index);
  });
  return prepared.map((entry) => entry.job).toList();
}
