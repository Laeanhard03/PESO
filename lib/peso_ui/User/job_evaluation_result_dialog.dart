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

  static List<String> _lines(Object? raw) => (raw is List ? raw : const [])
      .whereType<String>()
      .where((text) => text.trim().isNotEmpty)
      .map((text) => text.replaceAll('_', ' '))
      .take(5)
      .toList();

  static Map<String, dynamic> _initialFeedback(Map<String, dynamic> report) {
    final raw = report['modelMatch'];
    final model = raw is Map ? raw : const <String, dynamic>{};
    final gaps = _lines(model['missingMandatory']);
    final fields = _lines(model['matchedOccupationFields']);
    final score = num.tryParse(model['score'].toString()) ?? 0;
    String status, headline, explanation;
    if (report['aiMatchingStatus'] != 'ready' || model.isEmpty) {
      status = 'unavailable';
      headline = 'Evaluation unavailable';
      explanation = 'The AI service could not finish this check. You can retry or still send your application to PESO.';
    } else if (fields.isNotEmpty && gaps.isEmpty && score >= 50) {
      status = 'match';
      headline = 'Good Match! Congratulations!';
      explanation = 'Your saved NSRP and résumé details relate to this job. PESO and the employer will still confirm the exact qualifications.';
    } else {
      status = 'no_match';
      headline = 'Not a Match Yet';
      explanation = gaps.isNotEmpty
          ? 'Your saved details do not yet show some requirements for this job. Here are other jobs to consider. You can still apply through PESO.'
          : 'Your current skills do not closely match this job category yet. Here are other jobs to consider. You can still apply through PESO.';
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
            _feedback['headline']?.toString() ?? 'Job evaluation complete',
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
                'Brief explanation by Gemini using existing evaluation evidence.',
                style: TextStyle(fontSize: 11, color: Color(0xFF64766C)),
              ),
            ],
            if (_loading) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: 6),
              const Text(
                'Personalizing your explanation and finding related jobs…',
                style: TextStyle(fontSize: 11, color: Color(0xFF64766C)),
              ),
            ],
            if (matches.isNotEmpty) ...[
              const SizedBox(height: 13),
              const Text(
                'Skills and work areas related to this job',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(matches.join(', '), style: const TextStyle(fontSize: 13)),
            ],
            if (gaps.isNotEmpty) ...[
              const SizedBox(height: 13),
              const Text(
                'Requirements to review with PESO',
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
            if (!positive) ...[
              const SizedBox(height: 15),
              const Text(
                'Jobs we recommend exploring',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              const SizedBox(height: 6),
              if (_recommendations.isEmpty && !_loading)
                const Text(
                  'No closely related active job could be confirmed yet. You can still browse all openings or proceed to PESO.',
                  style: TextStyle(fontSize: 12.5, height: 1.4),
                ),
              ..._recommendations.map((job) {
                final id = job['jobId']?.toString() ?? '';
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
                'These are suggestions, not guaranteed job qualifications.',
                style: TextStyle(fontSize: 11, color: Color(0xFF617269)),
              ),
            ],
            const SizedBox(height: 11),
            const Text(
              'You can still send your application to PESO for human review, even if your skills do not yet align closely.',
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
          child: const Text('View full results'),
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
