import 'package:flutter/material.dart';

import '../../peso_services/peso_api_client.dart';

/// A short, job-dependent screening questionnaire. The questions are derived
/// deterministically from the job title, its listed requirements and its
/// description, so the answers stay relevant to the specific role without an
/// extra AI round-trip.
class ScreeningQuestion {
  const ScreeningQuestion({
    required this.id,
    required this.prompt,
    required this.options,
  });

  final String id;
  final String prompt;
  final List<String> options;
}

List<ScreeningQuestion> buildJobScreeningQuestions(Map<String, dynamic> job) {
  final title = (job['title'] ?? '').toString().toLowerCase();
  final reqs = job['reqs'] is List
      ? (job['reqs'] as List).map((item) => item.toString()).join(' ').toLowerCase()
      : '';
  final description = (job['description'] ?? '').toString().toLowerCase();
  final hay = '$title $reqs $description';
  final location = (job['location'] ?? 'the job site').toString();

  final questions = <ScreeningQuestion>[];

  questions.add(const ScreeningQuestion(
    id: 'experience',
    prompt: 'How many years of related work experience do you have?',
    options: <String>[
      'No experience yet',
      'Less than 1 year',
      '1-2 years',
      '3-5 years',
      'More than 5 years',
    ],
  ));
  questions.add(ScreeningQuestion(
    id: 'availability',
    prompt: 'When can you start if hired?',
    options: const <String>[
      'Within a few days',
      'Next week',
      'Within a month',
      'Not sure yet',
    ],
  ));
  questions.add(ScreeningQuestion(
    id: 'willingToWork',
    prompt: 'Are you willing to report to $location for this job?',
    options: const <String>[
      'Yes',
      'No, but I can relocate',
      'No',
    ],
  ));
  questions.add(const ScreeningQuestion(
    id: 'interviewWilling',
    prompt: 'Are you willing to attend the PESO/employer interview and submit the required documents?',
    options: <String>['Yes', 'No'],
  ));

  if (RegExp(r'driver|driving|delivery|truck|motor|license|chauffeur').hasMatch(hay)) {
    questions.add(const ScreeningQuestion(
      id: 'driverLicense',
      prompt: 'Do you have a valid driver\'s license?',
      options: <String>['Professional', 'Non-professional', 'Student permit', 'None'],
    ));
  }
  if (RegExp(r'nc ii|ncii|tesda|certificate|certified|nc iii').hasMatch(hay)) {
    questions.add(const ScreeningQuestion(
      id: 'certificate',
      prompt: 'Do you hold the required TESDA / NC certificate?',
      options: <String>['Yes', 'No', 'In progress'],
    ));
  }
  if (RegExp(r'college|graduate|bachelor|high school|senior high|vocational|degree').hasMatch(hay)) {
    questions.add(const ScreeningQuestion(
      id: 'education',
      prompt: 'What is your highest educational attainment?',
      options: <String>[
        'Elementary',
        'High school',
        'Senior high',
        'Vocational / TESDA',
        'College graduate',
        'Post-graduate',
      ],
    ));
  }
  if (RegExp(r'computer|encoder|clerk|office|admin|data entry|encoding').hasMatch(hay)) {
    questions.add(const ScreeningQuestion(
      id: 'computerSkills',
      prompt: 'Can you use a computer and common office tools (Word, Excel)?',
      options: <String>['Yes, proficient', 'Basic only', 'No'],
    ));
  }

  return questions;
}

class JobApplicationDialog extends StatefulWidget {
  const JobApplicationDialog({
    super.key,
    required this.job,
    required this.primary,
    required this.textDark,
    required this.textLight,
  });

  final Map<String, dynamic> job;
  final Color primary;
  final Color textDark;
  final Color textLight;

  @override
  State<JobApplicationDialog> createState() => _JobApplicationDialogState();
}

class _JobApplicationDialogState extends State<JobApplicationDialog> {
  late final List<ScreeningQuestion> _questions;
  final Map<String, String> _answers = <String, String>{};
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _questions = buildJobScreeningQuestions(widget.job);
  }

  bool get _complete =>
      _questions.every((question) => (_answers[question.id] ?? '').isNotEmpty);

  Future<void> _submit() async {
    if (!_complete || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final application = await PesoApiClient.submitJobApplication(
        job: widget.job,
        answers: _answers,
      );
      if (!mounted) return;
      Navigator.of(context).pop(application);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = (widget.job['title'] ?? 'Untitled job').toString();
    final company = (widget.job['company'] ?? 'Employer').toString();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: widget.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.fact_check_rounded, color: widget.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Quick screening for PESO Montalban',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: widget.textDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$title @ $company',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: widget.textLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Answer a few questions. Your answers will be sent to the PESO office for referral to $company.',
                    style: TextStyle(fontSize: 13, color: widget.textLight, height: 1.4),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                itemCount: _questions.length,
                itemBuilder: (context, index) {
                  final question = _questions[index];
                  final selected = _answers[question.id];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${index + 1}. ${question.prompt}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: widget.textDark,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: question.options.map((option) {
                            final isSelected = selected == option;
                            return ChoiceChip(
                              label: Text(option),
                              selected: isSelected,
                              onSelected: (_) {
                                setState(() => _answers[question.id] = option);
                              },
                              selectedColor: widget.primary.withValues(alpha: 0.18),
                              labelStyle: TextStyle(
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? widget.primary : widget.textDark,
                                fontSize: 13,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isSelected
                                      ? widget.primary
                                      : Colors.grey.shade300,
                                ),
                              ),
                              showCheckmark: false,
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  Row(
                    children: <Widget>[
                      TextButton(
                        onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: (!_complete || _submitting) ? null : _submit,
                        icon: _submitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 18),
                        label: Text(_submitting ? 'Sending...' : 'Submit to PESO'),
                        style: FilledButton.styleFrom(
                          backgroundColor: widget.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
