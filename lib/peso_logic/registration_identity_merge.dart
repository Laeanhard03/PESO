/// Resume analysis is only a suggestion. Never replace registered identity
/// that the applicant entered or Firebase supplied.
Map<String, String> mergeResumeIdentityForNsrp(
  Map<String, String> registration,
  Map<String, dynamic> aiPreview,
) {
  final merged = Map<String, String>.from(registration);
  bool missing(String field) => (merged[field] ?? '').trim().isEmpty;

  if (missing('firstName') || missing('lastName')) {
    final name = (aiPreview['fullName'] ?? '')
        .toString()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (name.isNotEmpty) {
      final parts = _splitResumeFullName(name);
      for (final field in ['firstName', 'middleName', 'lastName']) {
        final proposed = (parts[field] ?? '').trim();
        if (missing(field) && proposed.isNotEmpty) merged[field] = proposed;
      }
    }
  }

  // Use resume contact suggestions only where registration supplied nothing.
  // Applicant must still review these fields on the editable NSRP form.
  for (final entry in <String, String>{
    'email': (aiPreview['email'] ?? '').toString().trim(),
    'phone': (aiPreview['phoneNumber'] ?? '').toString().trim(),
  }.entries) {
    if (missing(entry.key) && entry.value.isNotEmpty) {
      merged[entry.key] = entry.value;
    }
  }
  return merged;
}

Map<String, String> _splitResumeFullName(String fullName) {
  final commaIndex = fullName.indexOf(',');
  if (commaIndex > 0) {
    final surname = fullName.substring(0, commaIndex).trim();
    final given = fullName
        .substring(commaIndex + 1)
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    return {
      'firstName': given.isNotEmpty ? given.first : '',
      'middleName': given.length > 1 ? given.sublist(1).join(' ') : '',
      'lastName': surname,
    };
  }
  final parts = fullName
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  return {
    'firstName': parts.isNotEmpty ? parts.first : '',
    'middleName': parts.length > 2
        ? parts.sublist(1, parts.length - 1).join(' ')
        : '',
    'lastName': parts.length > 1 ? parts.last : '',
  };
}

/// Accept only a source-backed statement explicitly labeling sex/gender.
/// No inference from a person's name, photograph, title, or pronouns.
String? explicitResumeSex(String text) {
  final match = RegExp(
    r'(?:^|\n)\s*(?:sex|gender)\s*[:=-]\s*(male|female|other)\b',
    caseSensitive: false,
  ).firstMatch(text);
  if (match == null) return null;
  final value = match.group(1)!.toLowerCase();
  if (value == 'male') return 'Male';
  if (value == 'female') return 'Female';
  return 'Other';
}

/// A Gemini suggestion is not verified merely because it has a sex field:
/// require backend-attested evidence and an explicit statement in the quote.
String? verifiedResumeSex(Map<String, dynamic> extracted) {
  final evidence = extracted['verifiedSexEvidence'];
  if (evidence is! Map || evidence['verified'] != true) return null;
  final source = evidence['sourceQuote'];
  if (source is! String) return null;
  final parsed = explicitResumeSex(source);
  return parsed == evidence['sex'] ? parsed : null;
}
