import 'package:flutter/material.dart';

/// Editable applicant-owned NSRP career details. This intentionally does not
/// edit the original PDF, PESO staff/assessor fields or government ID numbers.
const applicantEducationLevels = <String>[
  'No formal schooling',
  'Elementary',
  'Junior High School',
  'Senior High School',
  'Technical / Vocational',
  'College Undergraduate',
  'College Graduate',
  'Postgraduate',
  'Currently studying',
];
const applicantExperienceLevels = <String>[
  'No previous work experience',
  'Has work experience',
  'Prefer to discuss with PESO',
];
const applicantSkillsStages = <String>[
  'Has skills or training to list',
  'New entrant / still learning',
];

/// Replaces only explicitly tagged applicant-owned fields, preserving original
/// NSRP entries (including optional identifiers and PESO assessor records).
/// No AI-extracted claims or invented qualifications are introduced.
Map<String, dynamic> updateApplicantNsrpCareerDetails(
  Map<String, dynamic> source,
  Map<String, String> details,
) {
  final rows = <Map<String, dynamic>>[];
  final raw = source['entries'];
  if (raw is List) {
    for (final item in raw) {
      if (item is! Map) continue;
      final copy = Map<String, dynamic>.from(item);
      if (copy['fieldKey']?.toString().startsWith('applicant.') == true) {
        continue;
      }
      rows.add(copy);
    }
  }
  void add(String key, String label, String value) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      rows.add({
        'index': rows.length + 1,
        'type': 'applicant_essential',
        'fieldKey': key,
        'label': label,
        'value': trimmed,
      });
    }
  }

  add(
    'applicant.highestEducation',
    'Highest education attained',
    details['education'] ?? '',
  );
  add(
    'applicant.experienceStatus',
    'Work experience status',
    details['experience'] ?? '',
  );
  add(
    'applicant.skillsStage',
    'Career readiness stage',
    details['skillsStage'] ?? '',
  );
  if (details['skillsStage'] == applicantSkillsStages.first) {
    add('applicant.skills', 'Other skills acquired', details['skills'] ?? '');
  }
  add(
    'applicant.preferredOccupation',
    'Preferred occupation',
    details['preferredOccupation'] ?? '',
  );
  add(
    'applicant.educationHistory',
    'Educational background (self-reported)',
    details['educationHistory'] ?? '',
  );
  add(
    'applicant.employmentHistory',
    'Employment history (self-reported)',
    details['employmentHistory'] ?? '',
  );
  add(
    'applicant.certifications',
    'Certifications (self-reported)',
    details['certifications'] ?? '',
  );
  add(
    'applicant.yearsExperience',
    'Years of work experience (self-reported)',
    details['yearsExperience'] ?? '',
  );

  return {
    ...source,
    'documentType': 'NSRP Form 1',
    'entries': rows,
    'applicantEssentials': {
      'education': details['education']?.trim() ?? '',
      'experience': details['experience']?.trim() ?? '',
      'skillsStage': details['skillsStage']?.trim() ?? '',
      'skills': details['skillsStage'] == applicantSkillsStages.first
          ? details['skills']?.trim() ?? ''
          : '',
      'preferredOccupation': details['preferredOccupation']?.trim() ?? '',
      'educationHistory': details['educationHistory']?.trim() ?? '',
      'employmentHistory': details['employmentHistory']?.trim() ?? '',
      'certifications': details['certifications']?.trim() ?? '',
      'yearsExperience': details['yearsExperience']?.trim() ?? '',
    },
    // A previous free-text AI summary may describe qualifications the user
    // just corrected. The source entries, not stale prose, are authoritative.
    'aiText': '',
    'updatedByApplicantAt': DateTime.now().toUtc().toIso8601String(),
  };
}

/// A source/profile edit makes saved model results outdated. Keep the original
/// answers and any submitted application, but never retain an obsolete score.
void markReadinessReportsForRecheck(
  List<Map<String, dynamic>> outcomes, {
  required String reason,
}) {
  for (final outcome in outcomes) {
    if (outcome['status'] != 'readiness') continue;
    final previousReview = (outcome['modelReviewNotes'] as List?) ?? const [];
    if (outcome['nextSteps'] is List) {
      outcome['nextSteps'] = (outcome['nextSteps'] as List)
          .where((item) => !previousReview.contains(item))
          .toList();
    }
    for (final field in ['strengths', 'improvements']) {
      if (outcome[field] is List) {
        outcome[field] = (outcome[field] as List).where((item) {
          final text = item.toString();
          return !text.startsWith('Relevant skill: ') &&
              !text.startsWith('Requirement to review: ');
        }).toList();
      }
    }
    outcome.remove('modelMatch');
    outcome.remove('modelVersion');
    outcome.remove('modelReviewNotes');
    outcome.remove('aiMatchingProblem');
    outcome['aiMatchingStatus'] = 'needs_recheck';
    outcome['message'] =
        '$reason Recheck this job to see a current trained-model review. You can still apply through PESO.';
  }
}

class UserQualificationsEditor extends StatefulWidget {
  const UserQualificationsEditor({
    super.key,
    required this.pesoFormData,
    required this.resumeData,
    required this.accountProfile,
    required this.onSave,
  });
  final Map<String, dynamic> pesoFormData;
  final Map<String, dynamic> resumeData;
  final Map<String, dynamic> accountProfile;
  final Future<void> Function(Map<String, dynamic> updatedNsrp) onSave;

  @override
  State<UserQualificationsEditor> createState() =>
      _UserQualificationsEditorState();
}

class _UserQualificationsEditorState extends State<UserQualificationsEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _skills;
  late final TextEditingController _occupation;
  late final TextEditingController _educationHistory;
  late final TextEditingController _employmentHistory;
  late final TextEditingController _certifications;
  late final TextEditingController _years;
  String? _education;
  String? _experience;
  String? _skillsStage;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final data = widget.pesoFormData['applicantEssentials'] is Map
        ? Map<String, dynamic>.from(
            widget.pesoFormData['applicantEssentials'] as Map,
          )
        : widget.resumeData['applicantEssentials'] is Map
        ? Map<String, dynamic>.from(
            widget.resumeData['applicantEssentials'] as Map,
          )
        : <String, dynamic>{};
    final education =
        data['education']?.toString().trim() ??
        widget.accountProfile['educationLevel']?.toString().trim() ??
        '';
    _education = applicantEducationLevels.contains(education)
        ? education
        : null;
    final experience = data['experience']?.toString().trim() ?? '';
    _experience = applicantExperienceLevels.contains(experience)
        ? experience
        : null;
    final stage = data['skillsStage']?.toString().trim() ?? '';
    _skillsStage = applicantSkillsStages.contains(stage) ? stage : null;
    _skills = TextEditingController(text: data['skills']?.toString() ?? '');
    _occupation = TextEditingController(
      text: data['preferredOccupation']?.toString() ?? '',
    );
    _educationHistory = TextEditingController(
      text: data['educationHistory']?.toString() ?? '',
    );
    _employmentHistory = TextEditingController(
      text: data['employmentHistory']?.toString() ?? '',
    );
    _certifications = TextEditingController(
      text: data['certifications']?.toString() ?? '',
    );
    _years = TextEditingController(
      text: data['yearsExperience']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _skills.dispose();
    _occupation.dispose();
    _educationHistory.dispose();
    _employmentHistory.dispose();
    _certifications.dispose();
    _years.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = updateApplicantNsrpCareerDetails(widget.pesoFormData, {
        'education': _education ?? '',
        'experience': _experience ?? '',
        'skillsStage': _skillsStage ?? '',
        'skills': _skills.text,
        'preferredOccupation': _occupation.text,
        'educationHistory': _educationHistory.text,
        'employmentHistory': _employmentHistory.text,
        'certifications': _certifications.text,
        'yearsExperience': _years.text,
      });
      await widget.onSave(updated);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not save your updated NSRP details. Please check your connection and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Update your NSRP career details'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Only applicant-owned education, experience and skills can be edited here. '
                  'First-time jobseekers may select no experience or still learning. '
                  'You do not need TIN, SSS, certificates or PESO assessor information.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: const Key('edit_nsrp_education'),
                  initialValue: _education,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Highest education',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final item in applicantEducationLevels)
                      DropdownMenuItem(value: item, child: Text(item)),
                  ],
                  onChanged: (value) => setState(() => _education = value),
                  validator: (value) => value == null
                      ? 'Select your highest education, including if still studying.'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const Key('edit_nsrp_experience'),
                  initialValue: _experience,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Work experience status',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final item in applicantExperienceLevels)
                      DropdownMenuItem(value: item, child: Text(item)),
                  ],
                  onChanged: (value) => setState(() => _experience = value),
                  validator: (value) => value == null
                      ? 'Choose your experience status; no experience is okay.'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const Key('edit_nsrp_skills_stage'),
                  initialValue: _skillsStage,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Skills and training',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final item in applicantSkillsStages)
                      DropdownMenuItem(value: item, child: Text(item)),
                  ],
                  onChanged: (value) => setState(() => _skillsStage = value),
                  validator: (value) => value == null
                      ? 'Choose whether to list skills or indicate you are starting.'
                      : null,
                ),
                if (_skillsStage == applicantSkillsStages.first) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('edit_nsrp_skills'),
                    controller: _skills,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Your actual skills or training',
                      hintText: 'e.g. Workplace safety, basic welding',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'List skills you really have, or select still learning.'
                        : null,
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _occupation,
                  decoration: const InputDecoration(
                    labelText: 'Preferred occupation (optional)',
                    hintText: 'e.g. Construction safety staff',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('edit_education_history'),
                  controller: _educationHistory,
                  maxLines: 2,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Education or courses (self-reported)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  key: const Key('edit_employment_history'),
                  controller: _employmentHistory,
                  maxLines: 2,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Employment background (self-reported)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  key: const Key('edit_certifications'),
                  controller: _certifications,
                  maxLines: 2,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Certificates actually earned (self-reported)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  key: const Key('edit_years_experience'),
                  controller: _years,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Years of relevant experience (optional)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) return null;
                    final years = double.tryParse(trimmed);
                    return years == null || years < 0 || years > 60
                        ? 'Enter 0 to 60 years, or leave blank.'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your editable NSRP entries will be updated privately. '
                  'Previously generated PDFs remain unchanged; you may ask PESO to verify employer requirements.',
                  style: TextStyle(fontSize: 12),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          key: const Key('save_nsrp_career_details'),
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Saving...' : 'Save NSRP details'),
        ),
      ],
    );
  }
}
