import 'package:flutter/material.dart';

/// Displays only actual model responses for user-selected individual roles.
/// Incomplete employer scope suppresses numerical comparison, never application.
class NoticeRoleComparisonDialog extends StatelessWidget {
  const NoticeRoleComparisonDialog({
    super.key,
    required this.roles,
    required this.result,
    required this.onEvaluate,
  });

  final List<Map<String, dynamic>> roles;
  final Map<String, dynamic> result;
  final ValueChanged<Map<String, dynamic>> onEvaluate;

  @override
  Widget build(BuildContext context) {
    final entries = result['results'] is List
        ? (result['results'] as List).whereType<Map>().toList()
        : <Map>[];
    final byId = {for (final row in entries)
      row['jobId']?.toString() ?? '': Map<String, dynamic>.from(row)};
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 750,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Compare individual positions',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  ),
                  IconButton(
                    tooltip: 'Close comparison',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('Go model: ${result['modelVersion'] ?? 'not available'}. '
                  'These are qualification-alignment checks, not employment probabilities or hiring decisions.',
                  style: const TextStyle(color: Color(0xFF52675D), height: 1.5)),
              const SizedBox(height: 18),
              for (final role in roles) ...[
                Builder(builder: (context) {
                  final id = role['id']?.toString() ?? '';
                  final match = byId[id];
                  final scope = role['requirementScope']?.toString() ?? '';
                  final unverifiedRequirements = scope != 'explicit_role' &&
                      scope != 'single_role';
                  final low = match?['confidence'] == 'low';
                  final showScore = match != null && !unverifiedRequirements &&
                      !low && match['score'] is num;
                  final gaps = (match?['missingMandatory'] as List?) ?? [];
                  final notes = (match?['needsReview'] as List?) ?? [];
                  return Container(
                    key: Key('compare-result-$id'),
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F8F5),
                      border: Border.all(color: const Color(0xFFC8E0D0)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(role['title']?.toString() ?? 'Position',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text(showScore
                            ? 'Model alignment: ${match['score']}/100 · ${match['confidence']} evidence confidence'
                            : match == null
                                ? 'No model result returned for this role.'
                                : 'Model checked this role — more verified qualification evidence is needed before displaying a score.',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        if (unverifiedRequirements) ...[
                          const SizedBox(height: 5),
                          const Text('Employer requirements were not reliably attributed to this specific role. '
                              'Do not interpret an inferred skill as a mandatory condition.',
                              style: TextStyle(color: Color(0xFF93591C), fontSize: 12)),
                        ],
                        if (gaps.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('Potential requirements to confirm: ${gaps.take(3).join('; ')}',
                              style: const TextStyle(fontSize: 12)),
                        ],
                        if (notes.isNotEmpty) ...[
                          const SizedBox(height: 7),
                          Text('Human review: ${notes.take(3).join('; ')}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF52675D))),
                        ],
                        const SizedBox(height: 8),
                        FilledButton.tonal(
                          key: Key('compare-evaluate-$id'),
                          onPressed: () => onEvaluate(role),
                          child: const Text('Evaluate and continue toward PESO application'),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
