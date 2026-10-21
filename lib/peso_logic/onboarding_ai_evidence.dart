/// Converts user-entered structured onboarding fields into a conservative,
/// job-relevant extraction prompt. Saved source forms are never rewritten.
/// Contact, protected and government-ID fields stay on the owner's form and
/// are not unnecessarily sent to Gemini.
final RegExp _jobRelevant = RegExp(
  r'\b(skill|training|education|educational|course|school|college|'
  r'university|vocational|tesda|experience|employment|occupation|'
  r'work history|employment history|certification|certificate|'
  r'qualification|professional|position held|job title|'
  r'computer|software|degree|seminar|graduat)',
  caseSensitive: false,
);

final RegExp _privateOrProtected = RegExp(
  r'\b(first name|last name|middle name|full name|birth|dob|'
  r'age|gender|sex|civil status|marital|religion|nationality|'
  r'ethnicity|disability|pwd|email|phone|mobile|contact|'
  r'address|barangay|postcode|zip code|tin|sss|gsis|'
  r'philhealth|pag.?ibig|umid|passport|voter|'
  r'national id|government id|household|father|mother|spouse|'
  r'license number|licence number|license code|driver.?s? license|'
  r'bank|account number|password|signature|form field \d+)\b',
  caseSensitive: false,
);

final RegExp _possiblePrivateValue = RegExp(
  r'\b\d{8,}\b|[\w.+-]+@[\w.-]+\.[a-z]{2,}',
  caseSensitive: false,
);

/// The *matching* backend trusts only verified source evidence. This function
/// limits what is sent to the upstream extractor; it does not verify AI facts.
String buildOnboardingAiEvidence({
  required Map<String, dynamic> resumeData,
  required Map<String, dynamic> pesoFormData,
  String? onboardingText,
}) {
  final entries = <String>[];
  final seen = <String>{};

  void add(String label, String value, {String section = ''}) {
    final heading = [section.trim(), label.trim()]
        .where((part) => part.isNotEmpty)
        .join(' - ')
        .replaceAll(RegExp(r'\s+'), ' ');
    final text = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.isEmpty ||
        text.length > 600 ||
        heading.isEmpty ||
        !_jobRelevant.hasMatch(heading) ||
        _privateOrProtected.hasMatch(heading) ||
        _possiblePrivateValue.hasMatch(text)) {
      return;
    }
    final line = '$heading: $text';
    if (seen.add(line.toLowerCase())) entries.add(line);
  }

  void addFields(Object? source, {required bool nsrp}) {
    if (source is! List) return;
    for (final item in source) {
      if (item is! Map) continue;
      final value = item['value']?.toString() ?? '';
      final label = item['label']?.toString() ?? '';
      final section = nsrp ? '' : (item['section']?.toString() ?? '');
      add(label, value, section: section);
    }
  }

  addFields(resumeData['fields'], nsrp: false);
  addFields(pesoFormData['entries'], nsrp: true);

  // Backward compatibility for older saved textual exports that lack fields.
  // Unknown free-form lines are not used as Gemini qualification evidence.
  void addKnownLabeledLines(String raw) {
    for (final sourceLine in raw.split(RegExp(r'[\r\n]+'))) {
      final line = sourceLine.trim();
      final colon = line.indexOf(':');
      if (colon <= 0 || colon > 120) continue;
      add(line.substring(0, colon), line.substring(colon + 1));
    }
  }

  if (resumeData['fields'] is! List) {
    addKnownLabeledLines(resumeData['plainText']?.toString() ?? '');
  }
  if (pesoFormData['entries'] is! List) {
    addKnownLabeledLines(pesoFormData['aiText']?.toString() ?? '');
  }
  // The onboarding bridge text is retained privately on the profile. Only
  // clearly labeled, job-related lines are ever sent to the AI service.
  addKnownLabeledLines(onboardingText ?? '');

  final combined = entries.join('\n');
  return combined.length <= 8500 ? combined : combined.substring(0, 8500);
}
