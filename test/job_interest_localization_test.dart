import 'package:flutter_test/flutter_test.dart';
import 'package:peso_prototype/peso_logic/job_interest_recommendations.dart';
import 'package:peso_prototype/peso_logic/job_listing_localization.dart';

void main() {
  test(
    'IT, mall and restaurant interests prioritize matching real role cards',
    () {
      final jobs = <Map<String, dynamic>>[
        {
          'id': 'construction',
          'title': 'NOW HIRING — JCRCC',
          'aiListingKind': 'notice',
        },
        {
          'id': 'barista',
          'title': 'Barista — Cafe Montalban',
          'aiListingKind': 'role',
        },
        {
          'id': 'cashier',
          'title': 'Mall Cashier — Local Retailer',
          'aiListingKind': 'role',
        },
        {
          'id': 'tech',
          'title': 'IT Technical Support — Tech Shop',
          'aiListingKind': 'role',
        },
        {
          'id': 'welder',
          'title': 'Welder — Construction',
          'aiListingKind': 'role',
        },
      ];
      final sorted = rankJobOpportunities(
        jobs,
        preferredOccupations: 'IT, mall, restaurant',
        sourceSupportedSkills: ['MS Excel'],
      );
      final ids = sorted.take(3).map((item) => item['id']).toSet();
      expect(ids, {'barista', 'cashier', 'tech'});
      expect(sorted.last['id'], 'construction');
      expect(sorted.first['suggestedForInterest'], isTrue);
      expect(sorted.where((item) => item['match'] != null), isEmpty);
    },
  );

  test('Go qualification scores appear only from ready, validated results', () {
    final jobs = <Map<String, dynamic>>[
      {'id': 'a', 'title': 'Cashier', 'aiListingKind': 'role'},
      {'id': 'b', 'title': 'Carpenter', 'aiListingKind': 'role'},
    ];
    final pending = rankJobOpportunities(
      jobs,
      preferredOccupations: 'mall',
      goMatching: {
        'status': 'unavailable',
        'results': [
          {'jobId': 'a', 'score': 98},
        ],
      },
    );
    expect(pending.first['id'], 'a');
    expect(pending.first.containsKey('match'), isFalse);
    final ready = rankJobOpportunities(
      jobs,
      preferredOccupations: 'mall',
      goMatching: {
        'status': 'ready',
        'results': [
          {
            'jobId': 'a',
            'score': 72,
            'confidence': 'moderate',
            'assessmentBasis': 'role_attributed_requirements',
            'roleCriteriaCount': 2,
            'missingMandatory': [],
          },
          {'jobId': 'b', 'score': -10},
        ],
      },
    );
    expect(ready.first['match'], 72);
    expect(ready.last.containsKey('match'), isFalse);
  });

  test(
    'low-confidence 100/100 is an exploration clue, never a numeric match',
    () {
      final roles = <Map<String, dynamic>>[
        {'id': 'unverified', 'title': 'Warehouseman', 'aiListingKind': 'role'},
        {'id': 'verified', 'title': 'Sales Clerk', 'aiListingKind': 'role'},
      ];
      final ranked = rankJobOpportunities(
        roles,
        preferredOccupations: '',
        goMatching: {
          'status': 'ready',
          'results': [
            {
              'jobId': 'unverified',
              'score': 100,
              'confidence': 'low',
              'assessmentBasis': 'occupation_category_clues_only',
              'roleCriteriaCount': 0,
              'matchedOccupationFields': ['logistics_warehouse'],
              'missingMandatory': [],
            },
            {
              'jobId': 'verified',
              'score': 75,
              'confidence': 'moderate',
              'assessmentBasis': 'role_attributed_requirements',
              'roleCriteriaCount': 2,
              'matchedOccupationFields': ['sales_retail'],
              'missingMandatory': [],
            },
          ],
        },
      );
      expect(ranked.length, 2);
      expect(ranked.first['id'], 'verified');
      final tentative = ranked.singleWhere((j) => j['id'] == 'unverified');
      expect(tentative.containsKey('match'), isFalse);
      expect(tentative['careerFieldToExplore'], true);
      expect(tentative['suggestedForInterest'], true);
      expect(
        tentative['suggestionReason'],
        contains('employer qualifications need verification'),
      );
    },
  );

  test('AI career discovery promotes newcomer training and skill transfer without percent badges', () {
    final roles = <Map<String, dynamic>>[
      {'id': 'engineer', 'title': 'Civil Engineer', 'aiListingKind': 'role'},
      {'id': 'trainee', 'title': 'Production Trainee', 'aiListingKind': 'role'},
      {'id': 'waiter', 'title': 'Service Waiter', 'aiListingKind': 'role'},
    ];
    final beginner = rankJobOpportunities(
      roles,
      preferredOccupations: '',
      goMatching: {
        'status': 'ready',
        'results': [
          {
            'jobId': 'engineer',
            'score': 6,
            'opportunityRank': 0,
            'opportunityPathway': 'explore',
          },
          {
            'jobId': 'trainee',
            'score': 6,
            'opportunityRank': 24,
            'opportunityPathway': 'training_pathway',
          },
        ],
      },
    );
    expect(beginner.first['id'], 'trainee');
    expect(beginner.first['trainingPathway'], true);
    expect(beginner.first.containsKey('match'), false);
    expect(
      beginner.first['suggestionReason'],
      contains('confirm entry requirements'),
    );

    final skilled = rankJobOpportunities(
      roles,
      preferredOccupations: '',
      goMatching: {
        'status': 'ready',
        'results': [
          {
            'jobId': 'waiter',
            'score': 1,
            'confidence': 'low',
            'assessmentBasis': 'occupation_category_clues_only',
            'roleCriteriaCount': 0,
            'opportunityRank': 14,
            'opportunityPathway': 'transferable_skills',
          },
        ],
      },
    );
    final waiter = skilled.firstWhere((item) => item['id'] == 'waiter');
    expect(waiter['transferableCareer'], true);
    expect(waiter['suggestedForInterest'], true);
    expect(waiter.containsKey('match'), false);
  });

  test('non-matching preferences do not create vacancies or percentages', () {
    final data = <Map<String, dynamic>>[
      {'id': 'j1', 'title': 'Road Construction', 'aiListingKind': 'role'},
    ];
    final ranked = rankJobOpportunities(
      data,
      preferredOccupations: 'restaurant, mall',
    );
    expect(ranked.length, 1);
    expect(ranked.first['suggestedForInterest'], isFalse);
    expect(ranked.first.containsKey('match'), isFalse);
    expect(
      recognizedJobInterests('restaurant, mall, IT'),
      containsAll(['IT', 'Mall / Retail', 'Restaurant / Food']),
    );
  });

  test('saved NSRP/resume skill evidence ranks only real existing jobs', () {
    final ranked = rankJobOpportunities(
      <Map<String, dynamic>>[
        {
          'id': 'construction',
          'title': 'Mason',
          'aiListingKind': 'role',
          'reqs': ['Concrete mixing'],
        },
        {
          'id': 'office',
          'title': 'Office Assistant',
          'aiListingKind': 'role',
          'reqs': ['Microsoft Excel and computer literacy'],
        },
      ],
      preferredOccupations: '',
      sourceSupportedSkills: ['Microsoft Excel'],
    );
    expect(ranked.map((job) => job['id']).toList(), ['office', 'construction']);
    expect(ranked.first['suggestedForInterest'], true);
    expect(ranked.first['suggestionReason'], contains('NSRP/resume'));
    expect(
      ranked.every((job) => !job.containsKey('match')),
      true,
      reason: 'profile interest ranking must not fabricate Go scores',
    );
  });

  test('localized UI shows correct Tagalog/Taglish without mutating source', () {
    const original = 'NOW HIRING — JCRCC';
    expect(
      localizedNoticeTitle(original, 'Tagalog'),
      startsWith('NAGHAHANAP NG MGA EMPLEYADO'),
    );
    expect(
      localizedNoticeTitle(original, 'Taglish'),
      startsWith('HIRING NG MGA EMPLEYADO'),
    );
    expect(localizedNoticeTitle(original, 'English'), original);
    expect(
      localizedJobHeading('Role Description', 'Tagalog'),
      'Paglalarawan ng Trabaho',
    );
    expect(
      localizedJobHeading('Unreadable', 'Tagalog'),
      'Hindi malinaw sa dokumento',
    );
    const body =
        'Walk-in applicant opportunity from the agency compilation. Roles read from this notice: WELDER. TESDA NC II.';
    final output = localizedNoticeDescription(body, 'Taglish');
    expect(output, contains('walk-in application opportunity'));
    expect(output, contains('WELDER. TESDA NC II.'));
    expect(body, contains('Roles read from this notice:'));
  });
}
