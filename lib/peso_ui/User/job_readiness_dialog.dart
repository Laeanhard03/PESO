import 'package:flutter/material.dart';

import 'job_readiness_model.dart';

/// Optional PESO job-application questionnaire. Open only AFTER independent
/// Go AI matching; these answers never enter the trained model.
class JobReadinessDialog extends StatefulWidget {
  const JobReadinessDialog({
    super.key,
    required this.job,
    this.primary = const Color(0xFF236349),
  });

  final Map<String, dynamic> job;
  final Color primary;

  @override
  State<JobReadinessDialog> createState() => _JobReadinessDialogState();
}

class _JobReadinessDialogState extends State<JobReadinessDialog> {
  late final List<JobReadinessQuestion> _questions = questionsForJob(
    widget.job,
  );
  final Map<String, String> _answers = <String, String>{};
  int _stage = 0; // overview, questions, local preview
  int _index = 0;

  void _advance() {
    if (_stage == 0) {
      setState(() => _stage = 1);
      return;
    }
    if (_stage != 1 || !_answers.containsKey(_questions[_index].id)) return;
    setState(() {
      if (_index + 1 >= _questions.length) {
        _stage = 2;
      } else {
        _index++;
      }
    });
  }

  void _back() {
    if (_stage == 2) {
      setState(() => _stage = 1);
    } else if (_index > 0) {
      setState(() => _index--);
    } else {
      setState(() => _stage = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 600;
    final jobTitle = widget.job['title']?.toString() ?? 'This position';
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.92, end: 1.0),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      builder: (context, value, child) => Transform.scale(
        scale: value,
        child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
      ),
      child: Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 28,
          vertical: 16,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        clipBehavior: Clip.antiAlias,
        backgroundColor: Colors.white,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 625,
            maxHeight: size.height * 0.88,
            minHeight: size.height > 500 ? 360 : 240,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(compact ? 20 : 26),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF173C2E), Color(0xFF286C4F)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_outlined,
                          color: Color(0xFFE7F7EC),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Career Readiness Studio',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close career preview',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(
                      jobTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x28FFFFFF),
                        border: Border.all(color: const Color(0x37FFFFFF)),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Text(
                        'Application questions • Separate from AI matching',
                        style: TextStyle(
                          color: Color(0xFFE8F5ED),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_stage == 1)
                LinearProgressIndicator(
                  value: (_index + 1) / _questions.length,
                  minHeight: 5,
                  backgroundColor: const Color(0xFFE5ECE8),
                  color: widget.primary,
                ),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(compact ? 20 : 28),
                  child: AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 170),
                    child: _stage == 0
                        ? _overview(key: const ValueKey('overview'))
                        : _stage == 1
                        ? _question(key: ValueKey(_index))
                        : _preview(key: const ValueKey('preview')),
                  ),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE4EEE7)),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 14 : 24,
                  13,
                  compact ? 14 : 24,
                  16,
                ),
                child: Row(
                  children: [
                    if (_stage > 0)
                      TextButton.icon(
                        onPressed: _back,
                        icon: const Icon(Icons.arrow_back_rounded, size: 17),
                        label: const Text('Back'),
                      )
                    else
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Maybe later'),
                      ),
                    const Spacer(),
                    Flexible(
                      child: FilledButton.icon(
                        onPressed: _stage == 2
                            ? () => Navigator.of(context).pop(
                                buildJobReadinessReport(widget.job, _answers),
                              )
                            : _stage == 0 ||
                                  _answers.containsKey(_questions[_index].id)
                            ? _advance
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: widget.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(130, 49),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        icon: Icon(
                          _stage == 2
                              ? Icons.summarize_outlined
                              : Icons.arrow_forward_rounded,
                          size: 18,
                        ),
                        label: Text(
                          _stage == 0
                              ? 'Start questions'
                              : _stage == 2
                              ? 'Save my responses'
                              : _index + 1 == _questions.length
                              ? 'See my preview'
                              : 'Continue',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _overview({Key? key}) {
    final reqs = widget.job['reqs'] is List
        ? (widget.job['reqs'] as List)
              .map((e) => e.toString())
              .where((s) => s.trim().isNotEmpty)
              .take(3)
              .toList()
        : <String>[];
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Discover your next step',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Color(0xFF17352B),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'You already saw your AI job evaluation. If you choose to continue applying, these 10 questions provide additional information to PESO and do not change that evaluation.',
          style: TextStyle(
            height: 1.55,
            color: Color(0xFF52675D),
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 18),
        _infoPanel(
          Icons.psychology_outlined,
          'About this preview',
          'These answers are optional additional application details for PESO. Your prior AI evaluation is unchanged. After these questions, you will review and explicitly confirm whether to submit an application.',
        ),
        if (reqs.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'JOB REQUIREMENTS TO EXPLORE',
            style: TextStyle(
              color: Color(0xFF236349),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          ...reqs.map(
            (req) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: Color(0xFF236349),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      req,
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'Complete all ${_questions.length} questions to continue your optional PESO application.',
          style: const TextStyle(
            color: Color(0xFF52675D),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _question({Key? key}) {
    final question = _questions[_index];
    final selected = _answers[question.id];
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUESTION ${_index + 1} OF ${_questions.length}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: widget.primary,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          question.prompt,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            height: 1.25,
            color: Color(0xFF17352B),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          question.guidance,
          style: const TextStyle(color: Color(0xFF667B70), height: 1.5),
        ),
        const SizedBox(height: 22),
        for (final option in question.options)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _answers[question.id] = option),
                borderRadius: BorderRadius.circular(13),
                child: AnimatedContainer(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 130),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: selected == option
                        ? const Color(0xFFE9F4EE)
                        : const Color(0xFFF9FBFA),
                    border: Border.all(
                      color: selected == option
                          ? widget.primary
                          : const Color(0xFFDDE8E2),
                    ),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selected == option
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        size: 20,
                        color: selected == option
                            ? widget.primary
                            : const Color(0xFF809187),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          option,
                          style: TextStyle(
                            color: const Color(0xFF17352B),
                            fontWeight: selected == option
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _preview({Key? key}) {
    final report = buildJobReadinessReport(widget.job, _answers);
    final strengths = (report['strengths'] as List).cast<String>();
    final improvements = (report['improvements'] as List).cast<String>();
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.assistant_photo_outlined,
          color: Color(0xFF236349),
          size: 42,
        ),
        const SizedBox(height: 12),
        const Text(
          'Your career pathway is taking shape',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w900,
            color: Color(0xFF17352B),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Every job seeker has room to grow. Here is a preview from your answers:',
          style: TextStyle(color: Color(0xFF52675D), height: 1.5),
        ),
        const SizedBox(height: 18),
        _infoPanel(
          Icons.stars_rounded,
          'Your current strengths',
          strengths.first,
        ),
        const SizedBox(height: 12),
        _infoPanel(
          Icons.tips_and_updates_outlined,
          'A next skill to develop',
          improvements.first,
        ),
        const SizedBox(height: 16),
        const Text(
          'Your original AI evaluation remains separate. These self-reported answers will be saved to your outcomes and shared with PESO only if you confirm application submission.',
          style: TextStyle(fontSize: 13, color: Color(0xFF52675D), height: 1.5),
        ),
        const SizedBox(height: 10),
        const Text(
          'No rejection, no auto-hiring decision, and no information sent to an employer.',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF236349),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _infoPanel(IconData icon, String heading, String body) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7F2),
        border: Border.all(color: const Color(0xFFD9E9DF)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: widget.primary, size: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  heading,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF17352B),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: const TextStyle(
                    color: Color(0xFF52675D),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
