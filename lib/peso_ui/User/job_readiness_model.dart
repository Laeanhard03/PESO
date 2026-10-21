/// Deterministic, non-disqualifying prototype for a future trained AI engine.
/// This is not an automated hiring decision or an employer's assessment.
class JobReadinessQuestion {
  const JobReadinessQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    required this.guidance,
  });

  final String id;
  final String prompt;
  final List<String> options;
  final String guidance;
}

String _jobHaystack(Map<String, dynamic> job) {
  final reqs = job['reqs'];
  return [
    job['title']?.toString() ?? '',
    job['industry']?.toString() ?? '',
    job['description']?.toString() ?? '',
    if (reqs is List) ...reqs.map((value) => value.toString()),
  ].join(' ').toLowerCase();
}

List<JobReadinessQuestion> questionsForJob(Map<String, dynamic> job) {
  final haystack = _jobHaystack(job);
  final location = (job['location'] ?? 'this workplace').toString();
  final locationLabel = location.length > 65 ? 'the job location' : location;
  final driving = RegExp(
    r'driv|truck|motor|vehicle|delivery|rider|operator|bulldozer|heavy equipment',
  ).hasMatch(haystack);
  final certificate = RegExp(
    r'tesda|ncii|nc ii|nc iii|certificate|license|electrician|welder|plumb|health|nurs|engineer|mechanic|technician|operator',
  ).hasMatch(haystack);
  final office = RegExp(
    r'office|account|cashier|encoder|computer|information technology|data|software|assistant|administrat|clerk',
  ).hasMatch(haystack);
  final service = RegExp(
    r'customer|sales|retail|food|hospitality|front desk|reception',
  ).hasMatch(haystack);

  final questions = <JobReadinessQuestion>[
    const JobReadinessQuestion(
      id: 'experience',
      prompt: 'How much related work experience do you have?',
      guidance: 'New workers and career shifters are welcome to continue.',
      options: [
        'Just starting',
        'Less than 1 year',
        '1–2 years',
        '3–5 years',
        'More than 5 years',
        'Prefer not to say',
      ],
    ),
    JobReadinessQuestion(
      id: 'workLocation',
      prompt: 'Would you be comfortable working in $locationLabel?',
      guidance: 'Your preference helps identify practical next steps.',
      options: const [
        'Yes, I can commute',
        'Yes, if relocation is possible',
        'I prefer nearby opportunities',
        'I need more information',
      ],
    ),
    const JobReadinessQuestion(
      id: 'availability',
      prompt: 'When would you ideally be ready to start?',
      guidance: 'Your answer is an indication, not a commitment.',
      options: [
        'Immediately',
        'Within 2 weeks',
        'Within a month',
        'Flexible / not yet decided',
      ],
    ),
    const JobReadinessQuestion(
      id: 'schedule',
      prompt: 'Which work schedule would suit you?',
      guidance: 'Choose your preference; availability does not determine a pass or fail.',
      options: [
        'Regular daytime',
        'Shifting hours',
        'Weekends when needed',
        'Flexible / need to discuss',
      ],
    ),
    const JobReadinessQuestion(
      id: 'skills',
      prompt: 'How familiar are you with the main tasks of this position?',
      guidance: 'Honest answers help you plan any training.',
      options: [
        'I have performed them at work',
        'I have practiced in training or school',
        'I know the basics',
        'I would like to learn',
      ],
    ),
    const JobReadinessQuestion(
      id: 'interview',
      prompt: 'Would you be comfortable attending an employer interview?',
      guidance: 'Preparation and practice can make interviews easier.',
      options: [
        'Yes',
        'Yes, with some preparation',
        'I would like interview coaching',
      ],
    ),
  ];

  if (driving) {
    questions.add(
      const JobReadinessQuestion(
        id: 'driverLicense',
        prompt: 'What driving license do you currently hold?',
        guidance:
            'Some driving or equipment roles require specific license classes.',
        options: [
          'Professional license',
          'Non-professional license',
          'Student permit',
          'None yet',
          'Not sure what is required',
        ],
      ),
    );
  }
  if (certificate) {
    questions.add(
      const JobReadinessQuestion(
        id: 'certificate',
        prompt: 'Do you have a relevant trade certificate, NC qualification, or professional license?',
        guidance: 'You can still receive an upskilling plan without one.',
        options: [
          'Yes, current',
          'In progress',
          'Not yet',
          'Unsure which certificate is needed',
        ],
      ),
    );
  }
  if (office) {
    questions.add(
      const JobReadinessQuestion(
        id: 'officeTools',
        prompt: 'How comfortable are you with the tools used in this role?',
        guidance:
            'Examples may include office software, spreadsheets, or computers.',
        options: [
          'Confident / experienced',
          'Basic knowledge',
          'Currently learning',
          'I would need training',
        ],
      ),
    );
  } else if (service) {
    questions.add(
      const JobReadinessQuestion(
        id: 'customerService',
        prompt: 'What experience do you have communicating with customers or clients?',
        guidance: 'School and volunteer experience can also be relevant.',
        options: [
          'At work',
          'Through school or volunteering',
          'Limited experience',
          'I would like to learn',
        ],
      ),
    );
  } else if (!driving) {
    questions.add(
      const JobReadinessQuestion(
        id: 'handsOn',
        prompt: 'Have you practiced the hands-on tasks expected for this work?',
        guidance:
            'Informal experience and training can count toward preparation.',
        options: ['At work', 'Through training', 'A little', 'Not yet'],
      ),
    );
  }
  // Keep up to two truly job-specific items so every category receives the
  // same ten-question minimum without dropping the applicant's preferences.
  if (questions.length > 8) questions.removeRange(8, questions.length);
  questions.add(
    const JobReadinessQuestion(
      id: 'support',
      prompt: 'What support would help you move forward?',
      guidance: 'Choose the area you would most like help with.',
      options: [
        'Skills training',
        'Resume and documents',
        'Interview preparation',
        'Finding suitable jobs',
        'No support needed now',
      ],
    ),
  );
  questions.add(
    const JobReadinessQuestion(
      id: 'preference',
      prompt: 'What matters most to you in your next job?',
      guidance: 'Your priorities help inform your own decisions.',
      options: [
        'Stable hours',
        'Opportunities to learn',
        'Salary and benefits',
        'Location and commute',
        'Long-term career growth',
      ],
    ),
  );
  const additional = <JobReadinessQuestion>[
    JobReadinessQuestion(
      id: 'roleRequirements',
      prompt: 'Have you reviewed the published requirements for this position?',
      guidance: 'PESO can clarify any unclear employer requirements.',
      options: [
        'Yes, and I understand them',
        'Yes, but I need clarification',
        'I need help reviewing them',
        'The posting did not provide enough details',
      ],
    ),
    JobReadinessQuestion(
      id: 'workArrangement',
      prompt: 'What work arrangement could you consider?',
      guidance: 'Preferences are passed to PESO and are not used to change your AI score.',
      options: [
        'Full-time on-site',
        'Part-time or flexible',
        'Remote or hybrid if available',
        'Open to discussing options',
      ],
    ),
    JobReadinessQuestion(
      id: 'learning',
      prompt: 'Are you interested in additional training for this occupation?',
      guidance: 'PESO can recommend development opportunities, if available.',
      options: [
        'Yes, short training',
        'Yes, certification program',
        'Only if employer provided',
        'Not sure yet',
      ],
    ),
  ];
  for (final q in additional) {
    if (questions.length >= 10) break;
    questions.add(q);
  }
  assert(questions.length == 10);
  return questions.toList(growable: false);
}

Map<String, dynamic> buildJobReadinessReport(
  Map<String, dynamic> job,
  Map<String, String> answers,
) {
  // AI evaluation happens before the optional MRQ, with an empty answer set.
  // Do not manufacture any strengths or claim the applicant has stated
  // preferences when no questionnaire has been completed.
  if (answers.isEmpty) {
    return <String, dynamic>{
      'status': 'readiness',
      'previewOnly': false,
      'jobId': job['id']?.toString() ?? '',
      'job': job['title']?.toString() ?? 'Position',
      'company': job['company']?.toString() ?? 'Employer',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'answers': <String, String>{},
      'strengths': <String>[],
      'improvements': <String>[],
      'nextSteps': <String>[
        'Review the independent AI category comparison.',
        'If you wish to continue, answer the 10 optional PESO application questions.',
      ],
      'requirements': job['reqs'] is List
          ? (job['reqs'] as List).map((x) => x.toString()).take(6).toList()
          : <String>[],
      'message': 'The model checks only your saved NSRP/resume evidence. No application screening questions are used for matching.',
    };
  }
  final experience = answers['experience'] ?? '';
  final skills = answers['skills'] ?? '';
  final strengths = <String>[];
  final growth = <String>[];
  final nextSteps = <String>[];

  if (experience == 'Just starting' || experience == 'Less than 1 year') {
    growth.add(
      'Build practical experience through short training, projects, or supervised work.',
    );
  } else if (experience != 'Prefer not to say' && experience.isNotEmpty) {
    strengths.add('You have related experience to discuss with an employer.');
  }
  if (skills.contains('performed') || skills.contains('practiced')) {
    strengths.add(
      'You can share examples of relevant tasks you have already practiced.',
    );
  } else {
    growth.add(
      'Practice the core tasks from the job description and record examples of your work.',
    );
  }
  if (answers['availability'] == 'Immediately' ||
      answers['availability'] == 'Within 2 weeks') {
    strengths.add('You indicated a near-term availability to begin work.');
  }
  if (answers['workLocation'] == 'I prefer nearby opportunities') {
    growth.add('Confirm the commute or explore similar roles closer to home.');
  }
  if (answers['workLocation'] == 'I need more information') {
    nextSteps.add(
      'Ask PESO or the employer about the exact job location and work arrangement.',
    );
  }
  if (answers.containsKey('driverLicense')) {
    if (answers['driverLicense'] == 'Professional license') {
      strengths.add(
        'You indicated that you hold a professional driving license.',
      );
    } else {
      growth.add(
        'Check the required driving-license class or heavy-equipment permit before applying.',
      );
    }
  }
  if (answers.containsKey('certificate')) {
    if (answers['certificate'] == 'Yes, current') {
      strengths.add('You indicated you hold a relevant current certification.');
    } else {
      growth.add(
        'Check whether this role requires an NC certificate, TESDA training, or professional license.',
      );
    }
  }
  if (answers['officeTools'] == 'Basic knowledge' ||
      answers['officeTools'] == 'Currently learning' ||
      answers['officeTools'] == 'I would need training') {
    growth.add(
      'Build confidence with the tools and software mentioned in this posting.',
    );
  }
  if (answers['interview'] != 'Yes') {
    nextSteps.add(
      'Practice explaining your skills and experience before your next interview.',
    );
  }
  if (strengths.isEmpty) {
    strengths.add(
      'You have already taken a useful step by identifying your work preferences and readiness.',
    );
  }
  if (growth.isEmpty) {
    growth.add(
      'Review the employer requirements and prepare evidence of your skills and experience.',
    );
  }
  nextSteps.add(
    'Review the actual job requirements and prepare your resume and supporting documents.',
  );
  final support = answers['support'];
  if (support != null && support != 'No support needed now') {
    nextSteps.add('Consider requesting support with: $support');
  }
  nextSteps.add(
    'Contact PESO or the employer to confirm vacancy status and the next application step.',
  );

  final requirements = job['reqs'] is List
      ? (job['reqs'] as List)
            .map((v) => v.toString().trim())
            .where((v) => v.isNotEmpty)
            .take(6)
            .toList()
      : <String>[];

  return <String, dynamic>{
    'status': 'readiness',
    'previewOnly': true,
    'jobId': job['id']?.toString() ?? '',
    'job': job['title']?.toString() ?? 'Position',
    'company': job['company']?.toString() ?? 'Employer',
    'createdAt': DateTime.now().toUtc().toIso8601String(),
    'answers': Map<String, String>.from(answers),
    'strengths': strengths,
    'improvements': growth,
    'nextSteps': nextSteps,
    'requirements': requirements,
    'message': 'Every job seeker has a path forward. This is an informational readiness preview based on your own answers, not a hiring decision or trained AI result. Your answers have not been sent to an employer.',
  };
}
