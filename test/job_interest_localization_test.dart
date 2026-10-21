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
          {'jobId': 'a', 'score': 72},
          {'jobId': 'b', 'score': -10},
        ],
      },
    );
    expect(ready.first['match'], 72);
    expect(ready.last.containsKey('match'), isFalse);
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
