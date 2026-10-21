import 'package:flutter/material.dart';

/// Visible only while the authenticated trained-model request is in flight.
/// This indeterminate indicator never invents a percentage or a decision.
class JobMatchProgressOverlay extends StatelessWidget {
  const JobMatchProgressOverlay({super.key, required this.jobTitle});

  final String jobTitle;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: ModalBarrier(color: Color(0xA6000000), dismissible: false),
        ),
        Positioned.fill(
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: Material(
                    color: Colors.white,
                    elevation: 20,
                    borderRadius: BorderRadius.circular(24),
                    child: Padding(
                      padding: const EdgeInsets.all(26),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.auto_awesome_rounded,
                            size: 31,
                            color: Color(0xFF236349),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'PESO Mini-AI is checking your qualifications',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF17352B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            jobTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF52675D),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 22),
                          const Row(
                            children: [
                              SizedBox(
                                width: 36,
                                height: 36,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: Color(0xFF236349),
                                  semanticsLabel: 'Evaluating qualifications',
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  'Comparing your saved qualifications with the requirements of this specific role...',
                                  style: TextStyle(
                                    height: 1.4,
                                    color: Color(0xFF354C42),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'This is guidance only, not an automatic hiring decision. You can still send your application to PESO.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: Color(0xFF667B70),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A supportive, transparent, non-disqualifying career-readiness report.
class ReadinessReportCard extends StatelessWidget {
  const ReadinessReportCard({
    super.key,
    required this.data,
    this.onSubmitApplication,
    this.onEditQualifications,
    this.onEditPersonalInfo,
    this.onRecheck,
    this.submitting = false,
  });

  final Map<String, dynamic> data;
  final VoidCallback? onSubmitApplication;
  final VoidCallback? onEditQualifications;
  final VoidCallback? onEditPersonalInfo;
  final VoidCallback? onRecheck;
  final bool submitting;

  Widget _qualificationBanner(Map<String, dynamic> report) {
    final rawMatch = report['modelMatch'];
    final model = rawMatch is Map ? rawMatch : null;
    final status = report['aiMatchingStatus']?.toString() ?? 'unavailable';
    String heading;
    String explanation;
    String eyebrow;
    IconData icon;
    Color background;
    Color border;
    Color foreground;

    final storedFeedback = report['jobFeedback'];
    final feedback = storedFeedback is Map ? storedFeedback['feedback'] : null;
    final resultStatus = feedback is Map
        ? feedback['status']?.toString()
        : null;
    if (model != null &&
        (resultStatus == 'match' || resultStatus == 'no_match')) {
      final isMatch = resultStatus == 'match';
      eyebrow = 'YOUR JOB MATCH RESULT';
      heading = isMatch ? 'Good Match!' : 'Not a Match Yet';
      explanation = isMatch
          ? 'Congratulations! Your saved skills and experience relate to this job. PESO will confirm the exact qualifications.'
          : 'Your current skills do not closely match this job yet, or your profile does not show a listed requirement. Explore other jobs or still apply through PESO.';
      icon = isMatch
          ? Icons.check_circle_outline_rounded
          : Icons.lightbulb_outline_rounded;
      background = isMatch ? const Color(0xFFE8F4EB) : const Color(0xFFFFF4DF);
      border = isMatch ? const Color(0xFFC9E4D2) : const Color(0xFFE9CE91);
      foreground = isMatch ? const Color(0xFF236349) : const Color(0xFF79500E);
    } else if (model != null) {
      final missing = model['missingMandatory'];
      final hasGaps = missing is List && missing.isNotEmpty;
      final readiness = (model['readiness'] ?? '').toString().toLowerCase();
      final confidence = (model['confidence'] ?? '').toString().toLowerCase();
      eyebrow = 'TRAINED MODEL CHECK COMPLETE';
      if (hasGaps) {
        heading = 'Potential qualification gaps to review';
        explanation =
            'The model flagged ${missing.length} requirement(s) for confirmation. This is not a rejection: you can still apply through PESO.';
        icon = Icons.fact_check_outlined;
        background = const Color(0xFFFFF4DF);
        border = const Color(0xFFE9CE91);
        foreground = const Color(0xFF79500E);
      } else if (confidence == 'low' &&
          (model['assessmentBasis'] == 'job_title_clues_only' ||
              model['assessmentBasis'] == 'occupation_category_clues_only' ||
              model['assessmentBasis'] == 'job_details_unverified')) {
        heading = model['assessmentBasis'] == 'job_title_clues_only'
            ? 'Job-title skills comparison completed'
            : model['assessmentBasis'] == 'occupation_category_clues_only'
            ? 'Occupation-category comparison completed'
            : 'Job reviewed — employer details need confirmation';
        explanation = 'The AI checked this role and your saved qualifications. Without clearly attributable employer criteria, it shows job-specific guidance instead of an unsupported numerical score. You can still apply.';
        icon = Icons.info_outline_rounded;
        background = const Color(0xFFE9F2F8);
        border = const Color(0xFFC5DAE8);
        foreground = const Color(0xFF245374);
      } else if (confidence == 'low' ||
          readiness.contains('more information')) {
        heading = 'More information needed';
        explanation = 'Your saved qualifications or the job requirements are incomplete. PESO can help verify them; you can still submit your application.';
        icon = Icons.info_outline_rounded;
        background = const Color(0xFFE9F2F8);
        border = const Color(0xFFC5DAE8);
        foreground = const Color(0xFF245374);
      } else if (readiness.contains('strong qualification alignment') ||
          readiness.contains('strong occupation-category similarity')) {
        final occupationOnly = model['occupationTaxonomy'] == 'ISCO-08';
        heading = occupationOnly
            ? 'Relevant occupation-category similarity'
            : 'Promising qualification alignment';
        explanation = occupationOnly
            ? 'Your saved career categories relate to this type of work. This does not prove that you meet the employer requirements, and PESO must verify them.'
            : 'The trained model found encouraging alignment. PESO and the employer still need to confirm the requirements.';
        icon = Icons.check_circle_outline_rounded;
        background = const Color(0xFFE8F4EB);
        border = const Color(0xFFC9E4D2);
        foreground = const Color(0xFF236349);
      } else {
        heading = 'Some qualifications align';
        explanation = 'You have relevant experience or skills worth discussing. Additional training or evidence may help, and you can still apply through PESO.';
        icon = Icons.assignment_turned_in_outlined;
        background = const Color(0xFFEAF2F8);
        border = const Color(0xFFC5DAE8);
        foreground = const Color(0xFF245374);
      }
    } else {
      eyebrow = 'READINESS PREVIEW ONLY';
      icon = Icons.info_outline_rounded;
      background = const Color(0xFFFFF4DF);
      border = const Color(0xFFE9CE91);
      foreground = const Color(0xFF79500E);
      if (status == 'needs_recheck') {
        eyebrow = 'PROFILE UPDATED';
        heading = 'Your qualifications were saved';
        explanation = 'Recheck this job with your updated details. Any earlier AI result is no longer shown as current; you may still apply through PESO.';
      } else if (status == 'notice') {
        heading = 'Choose an individual role for AI matching';
        explanation = 'This is a multi-role hiring notice rather than a specific position. Select a named job opening for an AI check, or still send your application to PESO.';
      } else if (status == 'no_live_jobs') {
        heading = 'This posting cannot be scored right now';
        explanation = 'No eligible active individual role was available for the trained model. PESO can confirm the opening and consider your application.';
      } else if (status == 'missing_job') {
        heading = 'Job details need confirmation';
        explanation = 'The selected job could not be identified for an AI check. Your questionnaire is saved, and you can still contact PESO.';
      } else if (status == 'incomplete') {
        heading = 'AI check returned no verified result';
        explanation = 'The model did not return a usable result for this specific role. No qualification decision was made; you can still apply through PESO.';
      } else if (const <String>{
        'unauthenticated',
        'invalid_or_expired_token',
        'missing_bearer_token',
      }.contains(report['aiMatchingProblem'])) {
        heading = 'Sign in again to use AI matching';
        explanation = 'The authenticated qualification check could not proceed. Your questionnaire preview is still available and PESO can review your application.';
      } else if (report['aiMatchingProblem'] == 'api_unreachable') {
        heading = 'PESO Mini-AI could not be reached';
        explanation = 'The qualification service is not connected right now. No failure was assigned to you; you can still apply through PESO.';
      } else {
        heading = 'AI check unavailable — you can still apply';
        explanation = 'A trained-model qualification result was not confirmed. This preview uses your answers only; PESO can review your application directly.';
      }
    }

    return Semantics(
      container: true,
      child: Container(
        key: const Key('qualification_status_banner'),
        width: double.infinity,
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(17),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: foreground, size: 27),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eyebrow,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 11,
                      letterSpacing: 0.7,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    heading,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    explanation,
                    style: TextStyle(
                      color: foreground,
                      height: 1.45,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static List<String> _lines(Object? raw) => raw is List
      ? raw
            .map((entry) => entry.toString().trim())
            .where((entry) => entry.isNotEmpty)
            .toList(growable: false)
      : const <String>[];

  Widget _section(
    String heading,
    IconData icon,
    Color accent,
    List<String> lines,
  ) {
    if (lines.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBF9),
        border: Border.all(color: const Color(0xFFDCE9E1)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  heading,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF17352B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 17,
                    color: accent,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      line,
                      style: const TextStyle(
                        color: Color(0xFF40564B),
                        height: 1.5,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _label(String key) {
    const labels = <String, String>{
      'experience': 'Related experience',
      'workLocation': 'Preferred work location',
      'availability': 'Start date',
      'schedule': 'Work schedule',
      'skills': 'Task familiarity',
      'interview': 'Interview readiness',
      'driverLicense': 'Driving license',
      'certificate': 'Certifications',
      'officeTools': 'Office and digital skills',
      'customerService': 'Customer service',
      'handsOn': 'Hands-on skills',
      'support': 'Desired support',
      'preference': 'Career priorities',
    };
    return labels[key] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final rawAnswers = data['answers'];
    final answers = rawAnswers is Map
        ? Map<String, dynamic>.from(rawAnswers)
        : const <String, dynamic>{};
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 18 : 30),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD5E6DA)),
        borderRadius: BorderRadius.circular(25),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0E173F30),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              Chip(
                avatar: Icon(
                  Icons.auto_awesome_outlined,
                  size: 18,
                  color: Color(0xFF236349),
                ),
                label: Text('Career readiness'),
                backgroundColor: Color(0xFFEAF5ED),
                side: BorderSide(color: Color(0xFFD5E8DB)),
              ),
              Chip(
                label: Text('No pass or fail'),
                backgroundColor: Color(0xFFF4F7F4),
                side: BorderSide(color: Color(0xFFDDE7DF)),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            data['job']?.toString() ?? 'Job opportunity',
            style: TextStyle(
              fontSize: compact ? 22 : 29,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF17352B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            data['company']?.toString() ?? 'Employer',
            style: const TextStyle(color: Color(0xFF52675D), fontSize: 14),
          ),
          const SizedBox(height: 18),
          _qualificationBanner(data),
          if (data['jobFeedback'] is Map) ...[
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final detail = Map<String, dynamic>.from(
                  data['jobFeedback'] as Map,
                );
                final evidence = detail['feedback'];
                if (evidence is! Map) return const SizedBox.shrink();
                final explanation = Map<String, dynamic>.from(evidence);
                final rawRelated = detail['recommendations'];
                final related = rawRelated is List
                    ? rawRelated.whereType<Map>().take(3).toList()
                    : <Map>[];
                return Container(
                  key: const Key('saved-gemini-job-explanation'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F8F7),
                    border: Border.all(color: const Color(0xFFDCE8E1)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        explanation['headline']?.toString() ??
                            'Your evaluation summary',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        explanation['explanation']?.toString() ?? '',
                        style: const TextStyle(fontSize: 13, height: 1.5),
                      ),
                      if (explanation['explanationSource'] == 'gemini') ...[
                        const SizedBox(height: 6),
                        const Text(
                          'Explained by Gemini from your saved Go evaluation.',
                          style: TextStyle(
                            color: Color(0xFF607369),
                            fontSize: 11,
                          ),
                        ),
                      ],
                      if (related.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'Related openings to explore',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        ...related.map(
                          (job) => Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(
                              '• ${job['title']?.toString() ?? 'Related job'} — ${job['company']?.toString() ?? 'Employer'}',
                              style: const TextStyle(fontSize: 12, height: 1.4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'These are related career fields, not guaranteed eligibility.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF617269),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
          if (onEditQualifications != null &&
              (data['modelMatch'] is! Map ||
                  (data['modelMatch'] as Map)['confidence'] == 'low' ||
                  ((data['modelMatch'] as Map)['missingMandatory'] is List &&
                      ((data['modelMatch'] as Map)['missingMandatory'] as List)
                          .isNotEmpty))) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const Key('edit_nsrp_from_readiness'),
                  onPressed: onEditQualifications,
                  icon: const Icon(Icons.edit_note_outlined),
                  label: const Text('Update NSRP career details'),
                ),
                if (onEditPersonalInfo != null)
                  OutlinedButton.icon(
                    onPressed: onEditPersonalInfo,
                    icon: const Icon(Icons.person_outline),
                    label: const Text('Edit personal information'),
                  ),
                if (onRecheck != null)
                  TextButton.icon(
                    key: const Key('recheck_saved_job'),
                    onPressed: onRecheck,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Recheck this job'),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 17),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE8F4EB), Color(0xFFF8FCF8)],
              ),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOUR PATH FORWARD',
                  style: TextStyle(
                    color: Color(0xFF236349),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  data['message']?.toString() ??
                      'Here are some possible next steps.',
                  style: const TextStyle(color: Color(0xFF354C42), height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (data['modelMatch'] is Map) ...[
            Builder(
              builder: (context) {
                final match = Map<String, dynamic>.from(
                  data['modelMatch'] as Map,
                );
                final basis = match['assessmentBasis']?.toString() ?? '';
                final matchedOccupations = _lines(
                  match['matchedOccupationFields'],
                ).map((s) => s.replaceAll('_', ' ')).toList();
                final occupationIdeas = _lines(
                  match['occupationFieldsToExplore'],
                ).map((s) => s.replaceAll('_', ' ')).toList();
                final matchedClues = _lines(match['matchedTitleClues'])
                    .map((skill) => skill.replaceAll('_', ' '))
                    .toList();
                final exploreClues = _lines(match['skillsToExplore'])
                    .map((skill) => skill.replaceAll('_', ' '))
                    .toList();
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F7F2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFD5E8DB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'OCCUPATION & ROLE COMPARISON',
                        style: TextStyle(
                          color: Color(0xFF236349),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (match['confidence']?.toString().toLowerCase() ==
                          'low') ...[
                        const Text(
                          'Partial comparison completed — review available evidence',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF245374),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'The job and your saved qualifications were checked. A numeric score is withheld because specific requirements or applicant evidence still need verification. Relevant skills and actionable review items are shown below. This is not a failed qualification, and you can still apply.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: Color(0xFF52675D),
                          ),
                        ),
                        if (basis == 'job_title_clues_only' ||
                            basis == 'occupation_category_clues_only' ||
                            basis == 'job_details_unverified') ...[
                          const SizedBox(height: 10),
                          Text(
                            basis == 'job_title_clues_only' ||
                                    basis == 'occupation_category_clues_only'
                                ? 'Evidence available: general occupation-category or job-title clues only. These are guidance, NOT employer-confirmed qualification requirements.'
                                : 'Evidence available: job title only. No reliably attributable role requirements or recognizable skill clues were found.',
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.45,
                              color: Color(0xFF52675D),
                            ),
                          ),
                          if (matchedClues.isNotEmpty) ...[
                            const SizedBox(height: 9),
                            Text(
                              'Skills in your profile related to this title: ${matchedClues.join(', ')}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                          if (exploreClues.isNotEmpty) ...[
                            const SizedBox(height: 7),
                            Text(
                              'Possible skills to explore: ${exploreClues.join(', ')}. These are not confirmed employer requirements.',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ],
                      ] else ...[
                        Text(
                          '${match['score'] ?? '—'}/100 — ${match['readiness'] ?? 'Needs review'}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Evidence confidence: ${match['confidence'] ?? 'unknown'}. '
                          'The number reflects occupational similarity from taxonomy-trained examples; it does not establish hiring eligibility, licenses, or employment probability.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF52675D),
                          ),
                        ),
                      ],
                      if (matchedOccupations.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Relevant occupation categories from your saved NSRP/resume: ${matchedOccupations.join(', ')}',
                          style: const TextStyle(fontSize: 13, height: 1.45),
                        ),
                      ],
                      if (occupationIdeas.isNotEmpty) ...[
                        const SizedBox(height: 9),
                        Text(
                          'Occupation fields to explore: ${occupationIdeas.join(', ')}. These are not mandatory employer qualifications.',
                          style: const TextStyle(fontSize: 13, height: 1.45),
                        ),
                      ],
                      if (match['missingSkills'] is List &&
                          (match['missingSkills'] as List).isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 9),
                          child: Text(
                            'Skills to consider: ${(match['missingSkills'] as List).join(', ')}',
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
          ],
          _section(
            'What you already bring',
            Icons.stars_rounded,
            const Color(0xFF236349),
            _lines(data['strengths']),
          ),
          _section(
            'Areas worth building',
            Icons.tips_and_updates_outlined,
            const Color(0xFF92611D),
            _lines(data['improvements']),
          ),
          _section(
            'Your practical next steps',
            Icons.route_outlined,
            const Color(0xFF236349),
            _lines(data['nextSteps']),
          ),
          _section(
            'Requirements to confirm with the employer',
            Icons.fact_check_outlined,
            const Color(0xFF315E76),
            _lines(data['requirements']),
          ),
          if (answers.isNotEmpty)
            Material(
              color: Colors.transparent,
              child: ExpansionTile(
                title: const Text(
                  'Review my questionnaire answers',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text('${answers.length} answers recorded'),
                children: [
                  for (final entry in answers.entries)
                    ListTile(
                      dense: true,
                      title: Text(_label(entry.key)),
                      subtitle: Text(entry.value?.toString() ?? ''),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          if (data['applicationSubmitted'] == true)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFFE7F4EC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFC9E4D2)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.mark_email_read_outlined,
                    color: Color(0xFF236349),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Application received by PESO. Await staff or employer review; this does not guarantee selection.',
                      style: TextStyle(
                        color: Color(0xFF17352B),
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (onSubmitApplication != null)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: submitting ? null : onSubmitApplication,
                icon: submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(
                  submitting
                      ? 'Submitting to PESO...'
                      : answers.length < 10
                      ? 'Continue application: 10 PESO questions'
                      : 'Submit application to PESO',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF236349),
                  minimumSize: const Size(0, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            data['modelMatch'] is Map
                ? 'The occupational similarity model was trained on broad taxonomy examples, not real hiring outcomes. PESO must confirm employer requirements; this is never an automatic hiring decision.'
                : data['aiMatchingStatus'] == 'needs_recheck'
                ? 'Your qualifications have changed; recheck this job when ready. PESO can still review your application.'
                : 'The trained matching result was unavailable or incomplete. This informational readiness preview is not a hiring decision.',
            style: TextStyle(
              color: Color(0xFF667B70),
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
