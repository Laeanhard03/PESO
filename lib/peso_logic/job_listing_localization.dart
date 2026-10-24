/// Read-only display localization for standard PESO notice boilerplate.
/// Employer qualifications, source names and numbers are NEVER modified.
/// A verified server translation (if available) takes precedence.
String localizedJobHeading(String heading, String language) {
  if (language == 'English') return heading;
  final values = <String, List<String>>{
    'Role Description': [
      'Paglalarawan ng Trabaho',
      'Job Details at Paglalarawan',
    ],
    'EXPLORE OPPORTUNITIES': [
      'TUKLASIN ANG MGA OPORTUNIDAD',
      'EXPLORE MGA JOB OPPORTUNITIES',
    ],
    'RECOMMENDED FOR YOUR INTERESTS': [
      'MGA TRABAHONG KAUGNAY NG IYONG INTERES',
      'RECOMMENDED JOBS PARA SA IYO',
    ],
    'SEARCH RESULTS': ['MGA RESULTA NG PAGHAHANAP', 'JOB SEARCH RESULTS'],
    'No automatic expiration': [
      'Walang awtomatikong pag-expire',
      'Walang automatic expiry',
    ],
    'Not stated in source': [
      'Hindi nakasaad sa dokumento',
      'Walang nakalagay sa source',
    ],
    'Unreadable': ['Hindi malinaw sa dokumento', 'Hindi mabasa sa source'],
    'Walk-in Application': ['Personal na aplikasyon', 'Walk-in Application'],
    'Local Recruitment Activity': [
      'Lokal na aktibidad sa pagre-recruit',
      'Local Recruitment Activity',
    ],
    'Local Recruitment Activity (LRA)': [
      'Lokal na recruitment (LRA)',
      'Local Recruitment Activity (LRA)',
    ],
    'SEAP Program': ['Programa ng SEAP', 'SEAP Program'],
    'Government Internship Program (GIP)': [
      'Government Internship Program (GIP)',
      'Government Internship Program (GIP)',
    ],
    'All jobs': ['Lahat ng trabaho', 'All jobs'],
    'Your career workspace': [
      'Iyong lugar para sa paghahanap ng trabaho',
      'Your career space',
    ],
    'All categories': ['Lahat ng kategorya', 'All categories'],
    'Filtered opportunities': [
      'Mga napiling oportunidad',
      'Filtered job opportunities',
    ],
    'Your interests': ['Ayon sa iyong interes', 'Para sa interests mo'],
    'New posting': ['Bagong anunsiyo', 'New posting'],
    'Varies by role': ['Depende sa posisyon', 'Depende sa role'],
    'Multiple roles': ['Iba-ibang posisyon', 'Multiple roles'],
  };
  final valuesForHeading = values[heading];
  if (valuesForHeading == null) return heading;
  return valuesForHeading[language == 'Tagalog' ? 0 : 1];
}

String localizedNoticeTitle(String source, String language) {
  if (language == 'English') return source;
  if (language == 'Tagalog') {
    return source.replaceAll(
      RegExp('NOW HIRING', caseSensitive: false),
      'NAGHAHANAP NG MGA EMPLEYADO',
    );
  }
  return source.replaceAll(
    RegExp('NOW HIRING', caseSensitive: false),
    'HIRING NG MGA EMPLEYADO',
  );
}

/// Translate only fixed template wording when live Gemini translation is
/// unavailable. Do not insert unverified translations into any source data.
String localizedNoticeDescription(String original, String language) {
  if (language == 'English') return original;
  final replacements = <String, List<String>>{
    'Walk-in applicant opportunity from the agency compilation.': [
      'May walk-in na oportunidad para sa aplikante mula sa opisyal na compilation ng ahensiya.',
      'May walk-in application opportunity mula sa official agency compilation.',
    ],
    'Local recruitment activity from the agency compilation.': [
      'Lokal na gawaing pang-recruitment mula sa opisyal na compilation ng ahensiya.',
      'Local recruitment activity mula sa official agency compilation.',
    ],
    'Roles read from this notice:': [
      'Mga posisyong nakalista sa anunsiyo:',
      'Mga listed na trabaho sa notice:',
    ],
    'Location as stated:': [
      'Lokasyon ayon sa dokumento:',
      'Location ayon sa source:',
    ],
    'Contact as stated:': [
      'Kontak ayon sa dokumento:',
      'Contact ayon sa source:',
    ],
    'This card groups the roles on the employer’s own notice; a role card exists for each one.':
        [
          'Pinagsama sa anunsiyong ito ang mga posisyon ng employer. May hiwalay na card para sa bawat trabaho.',
          'Naka-group dito ang mga role mula sa employer notice. May sariling card ang bawat position.',
        ],
    'This card was read automatically from the agency’s own compilation PDF.': [
      'Awtomatikong nabasa ang anunsiyong ito mula sa opisyal na PDF ng ahensiya.',
      'Automatically nabasa ang notice mula sa official agency PDF.',
    ],
    'Current availability is not confirmed by that compilation: contact PESO Montalban to verify the opening before travelling or applying.':
        [
          'Hindi kumpirmado kung bukas pa ang posisyon. Makipag-ugnayan muna sa PESO Montalban bago pumunta o mag-apply.',
          'Hindi confirmed na open pa ang role; check muna sa PESO Montalban bago pumunta o mag-apply.',
        ],
    'Salary and vacancy counts are only shown when the source states them.': [
      'Ipinapakita lamang ang sahod at bilang ng bakante kung nakasaad sa dokumento.',
      'Salary at vacancy count ay makikita lang kung nasa source document.',
    ],
    'Role-specific qualifications differ; consult the cited pages in the official source PDF.':
        [
          'Magkakaiba ang kwalipikasyon ng bawat posisyon. Suriin ang mga pahinang tinukoy sa opisyal na PDF.',
          'Iba-iba ang qualifications ng roles. Tingnan ang cited pages sa official PDF.',
        ],
    'Confirm current availability, location, schedule and requirements with PESO Montalban before applying.':
        [
          'Kumpirmahin ang bakante, lokasyon, iskedyul at mga kailangan sa PESO Montalban bago mag-apply.',
          'I-confirm muna ang availability, location, schedule at requirements sa PESO Montalban bago mag-apply.',
        ],
  };
  var result = original;
  for (final entry in replacements.entries) {
    result = result.replaceAll(
      entry.key,
      entry.value[language == 'Tagalog' ? 0 : 1],
    );
  }
  return result;
}
