import 'package:flutter/material.dart';

/// Explanation of a completed Go evaluation. This modal is not an application,
/// hiring decision, or a second Gemini-based qualification assessment.
class JobEvaluationResultDialog extends StatefulWidget {
  const JobEvaluationResultDialog({
    super.key,
    required this.report,
    this.loadFeedback,
  });

  final Map<String, dynamic> report;
  final Future<Map<String, dynamic>> Function()? loadFeedback;

  @override
  State<JobEvaluationResultDialog> createState() =>
      _JobEvaluationResultDialogState();
}

class _JobEvaluationResultDialogState extends State<JobEvaluationResultDialog> {
  late Map<String, dynamic> _feedback;
  List<Map<String, dynamic>> _recommendations = <Map<String, dynamic>>[];
  bool _loading = false;

  static const _careerNames = <String, String>{
    'sales_retail': 'Sales and shop work',
    'hospitality_food': 'Food and hotel work',
    'office_administration': 'Office work',
    'logistics_warehouse': 'Warehouse and delivery work',
    'manufacturing_operations': 'Factory and production work',
    'manufacturing_craft': 'Hands-on making and repair',
    'construction_trades': 'Construction work',
    'driving_transport': 'Driving and transport',
    'data_services': 'Computer and data work',
    'technical_services': 'Repair and technical work',
    'accounting_finance': 'Accounting and finance work',
    'electrical_trades': 'Electrical work',
    'personal_services': 'Customer and personal services',
  };

  static List<String> _lines(Object? raw) => (raw is List ? raw : const [])
      .whereType<String>()
      .where((text) => text.trim().isNotEmpty)
      .map((text) =>
          _careerNames[text] ?? text.replaceAll('_', ' ').trim())
      .take(5)
      .toList();

  static Map<String, dynamic> _initialFeedback(Map<String, dynamic> report) {
    final raw = report['modelMatch'];
    final model = raw is Map ? raw : const <String, dynamic>{};
    final gaps = _lines(model['missingMandatory']);
    final fields = _lines(model['matchedOccupationFields']);
    final score = num.tryParse(model['score'].toString()) ?? 0;
    final roleCriteriaSupported =
        model['assessmentBasis'] == 'role_attributed_requirements' &&
        (num.tryParse(model['roleCriteriaCount'].toString()) ?? 0) > 0;
    final reliable =
        roleCriteriaSupported &&
        (model['confidence'] == 'medium' || model['confidence'] == 'moderate');
    String status, headline, explanation;
    if (report['aiMatchingStatus'] != 'ready' || model.isEmpty) {
      status = 'unavailable';
      headline = 'We could not check this job';
      explanation = 'Please try again. You can still apply or ask PESO for help.';
    } else if (!reliable) {
      status = 'needs_review';
      headline = 'Let’s check this job';
      explanation = 'This job may be worth exploring. We need more details from the job post or your profile to check it properly. You can still apply or ask PESO for help.';
    } else if (fields.isNotEmpty && gaps.isEmpty && score >= 50) {
      status = 'match';
      headline = 'Your skills may fit this job';
      explanation = 'Some skills you listed connect to this job. Check the job details. PESO or the employer will confirm what you need.';
    } else {
      status = 'no_match';
      headline = gaps.isNotEmpty
          ? 'Check these job requirements'
          : 'You can explore other jobs too';
      explanation = gaps.isNotEmpty
          ? 'Your profile does not yet show some things this job asks for. Check the details below. If you have these skills or documents, update your profile. You can still apply.'
          : 'Your saved skills do not clearly connect to this job yet. You can explore other openings, update your profile, or still apply.';
    }
    return <String, dynamic>{
      'status': status,
      'headline': headline,
      'explanation': explanation,
      'matchedFields': fields,
      'requirementsToReview': gaps,
      'explanationSource': 'standard',
    };
  }

  @override
  void initState() {
    super.initState();
    _feedback = _initialFeedback(widget.report);
    final saved = widget.report['jobFeedback'];
    if (saved is Map) {
      final fb = saved['feedback'];
      final recs = saved['recommendations'];
      if (fb is Map && fb['status'] == _feedback['status']) {
        _feedback = Map<String, dynamic>.from(fb);
      }
      if (recs is List) {
        _recommendations = recs
            .whereType<Map>()
            .map((r) => Map<String, dynamic>.from(r))
            .toList();
      }
    }
    if (saved == null) {
      // Store the immediate Go-based result even if Gemini is skipped,
      // fails or the applicant leaves the popup before text arrives.
      widget.report['jobFeedback'] = <String, dynamic>{
        'feedback': _feedback,
        'recommendations': _recommendations,
      };
    }
    if (widget.loadFeedback != null && saved == null) {
      _loading = true;
      _requestExplanation();
    }
  }

  Future<void> _requestExplanation() async {
    try {
      final result = await widget.loadFeedback!();
      if (!mounted) return;
      final feedback = result['feedback'];
      final recommended = result['recommendations'];
      if (feedback is Map && feedback['status'] == _feedback['status']) {
        setState(() {
          _feedback = Map<String, dynamic>.from(feedback);
          _recommendations = recommended is List
              ? recommended
                    .whereType<Map>()
                    .map((r) => Map<String, dynamic>.from(r))
                    .toList()
              : <Map<String, dynamic>>[];
        });
        // Saved alongside Outcomes for later review. It never updates Go input.
        widget.report['jobFeedback'] = <String, dynamic>{
          'feedback': _feedback,
          'recommendations': _recommendations,
        };
      }
    } catch (_) {
      // Text is shown immediately even when Gemini quota or the network fails.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _feedback['status']?.toString() ?? 'review';
    final savedHeadline = _feedback['headline']?.toString() ?? '';
    // Older saved reports may use discouraging or technical titles.
    final displayHeadline = switch (savedHeadline) {
      'Career Fit Needs Review' => 'Let’s check this job',
      'Not a Match Yet' => 'You can explore other jobs too',
      'Good Match! Congratulations!' => 'Your skills may fit this job',
      'Evaluation unavailable' => 'We could not check this job',
      _ => savedHeadline.isEmpty ? 'Job check complete' : savedHeadline,
    };
    final positive = status == 'match';
    final warning = status == 'no_match';
    final primaryColor = positive
        ? const Color(0xFF226747)
        : warning
        ? const Color(0xFF8A5B13)
        : const Color(0xFF315E87);
    final background = positive
        ? const Color(0xFFEAF6EE)
        : warning
        ? const Color(0xFFFFF5E5)
        : const Color(0xFFECF3F9);
    final title = widget.report['job']?.toString() ?? 'Selected job';
    final matches = _lines(_feedback['matchedFields']);
    final gaps = _lines(_feedback['requirementsToReview']);

    return AlertDialog(
      key: const Key('job-evaluation-popup'),
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              positive
                  ? Icons.celebration_outlined
                  : warning
                  ? Icons.lightbulb_outline_rounded
                  : Icons.fact_check_outlined,
              size: 29,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            displayHeadline,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 21),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF52675D), fontSize: 13),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _feedback['explanation']?.toString() ?? '',
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            if (_feedback['explanationSource'] == 'gemini') ...[
              const SizedBox(height: 7),
              const Text(
                'AI helped write this note using your saved job details.',
                style: TextStyle(fontSize: 11, color: Color(0xFF64766C)),
              ),
            ],
            if (_loading) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: 6),
              const Text(
                'Looking for other jobs you might like…',
                style: TextStyle(fontSize: 11, color: Color(0xFF64766C)),
              ),
            ],
            if (matches.isNotEmpty) ...[
              const SizedBox(height: 13),
              const Text(
                'Work areas related to your skills',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(matches.join(', '), style: const TextStyle(fontSize: 13)),
            ],
            if (gaps.isNotEmpty) ...[
              const SizedBox(height: 13),
              const Text(
                'Things to check with PESO',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              ...gaps
                  .take(3)
                  .map(
                    (gap) => Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        '• $gap',
                        style: const TextStyle(fontSize: 12.5, height: 1.4),
                      ),
                    ),
                  ),
            ],
            if (!positive && gaps.isNotEmpty) ...[
              const SizedBox(height: 13),
              const Text(
                'What you can do next',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'If you already have these skills or documents, add them to your profile. If not, ask PESO how to get started. You can still apply.',
                style: TextStyle(fontSize: 12.5, height: 1.4),
              ),
            ],
            if (!positive) ...[
              const SizedBox(height: 15),
              const Text(
                'Other jobs you can explore',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              const SizedBox(height: 6),
              if (_recommendations.isEmpty && !_loading)
                const Text(
                  'No other job suggestions yet. You can still browse all jobs or ask PESO for help.',
                  style: TextStyle(fontSize: 12.5, height: 1.4),
                ),
              ..._recommendations.map((job) {
                final id = job['jobId']?.toString() ?? '';
                final reason = job['reason']?.toString() ?? '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: OutlinedButton(
                    key: Key('recommended-role-$id'),
                    onPressed: id.isEmpty
                        ? null
                        : () => Navigator.of(context).pop('job:$id'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      alignment: Alignment.centerLeft,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.work_outline, size: 19),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                job['title']?.toString() ?? 'Related opening',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                job['company']?.toString() ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11),
                              ),
                              if (reason.isNotEmpty)
                                Text(
                                  reason,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    height: 1.3,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, size: 18),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 5),
              const Text(
                'These are ideas, not a hiring decision.',
                style: TextStyle(fontSize: 11, color: Color(0xFF617269)),
              ),
            ],
            const SizedBox(height: 11),
            const Text(
              'You can still apply. PESO will review your information.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: Color(0xFF52675D),
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, 'outcomes'),
          child: const Text('See more details'),
        ),
        FilledButton(
          key: const Key('continue-to-peso'),
          onPressed: () => Navigator.pop(context, 'apply'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF246E4A),
          ),
          child: const Text('Continue application to PESO'),
        ),
      ],
    );
  }
}
