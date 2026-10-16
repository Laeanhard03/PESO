import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../peso_services/peso_image_cache_manager.dart';

class UserJobFeedTab extends StatelessWidget {
  final String userName;
  final List<Map<String, dynamic>> availableJobs;
  final Map<String, dynamic>? selectedJob;
  final Function(Map<String, dynamic>) onSelectJob;
  final Function(String jobTitle, String company, int matchScore) onEvaluateJob;
  final String Function(String) translate;
  final Color primary;
  final Color textDark;
  final Color textLight;

  const UserJobFeedTab({
    super.key,
    required this.userName,
    required this.availableJobs,
    required this.selectedJob,
    required this.onSelectJob,
    required this.onEvaluateJob,
    required this.translate,
    required this.primary,
    required this.textDark,
    required this.textLight,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(50),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeSlideEntrance(
                delay: 0,
                child: Text(
                  translate('Welcome back, ${userName.split(" ")[0]}!'),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: textDark,
                    letterSpacing: -1,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              FadeSlideEntrance(
                delay: 100,
                child: Text(
                  translate(
                    'Discover your top AI-matched opportunities based on your extracted skills.',
                  ),
                  style: TextStyle(fontSize: 18, color: textLight),
                ),
              ),
              const SizedBox(height: 40),
              FadeSlideEntrance(
                delay: 200,
                child: SizedBox(
                  height: 320,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: availableJobs.length,
                    itemBuilder: (context, index) {
                      final job = availableJobs[index];
                      final isSelected = selectedJob == job;
                      final bool isTopMatch = job['match'] >= 90;

                      return GestureDetector(
                        onTap: () => onSelectJob(job),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 300,
                          margin: const EdgeInsets.only(
                            right: 25,
                            bottom: 20,
                            top: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isSelected
                                  ? primary
                                  : (isTopMatch
                                        ? Colors.indigo.shade100
                                        : Colors.transparent),
                              width: isSelected ? 3 : (isTopMatch ? 2 : 0),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isSelected
                                    ? primary.withValues(alpha: 0.3)
                                    : Colors.black.withValues(alpha: 0.05),
                                blurRadius: isSelected ? 20 : 15,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(21),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      CachedNetworkImage(
                                        imageUrl: job['image'],
                                        cacheManager: PesoImageCacheManager.instance,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            Container(
                                              color: Colors.grey.shade200,
                                              child: const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                            ),
                                        errorWidget: (context, url, error) =>
                                            const Icon(Icons.work),
                                      ),
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.transparent,
                                              Colors.black.withValues(
                                                alpha: 0.8,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 15,
                                        right: 15,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          child: BackdropFilter(
                                            filter: ImageFilter.blur(
                                              sigmaX: 10,
                                              sigmaY: 10,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(
                                                  alpha: 0.2,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.3),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.auto_awesome,
                                                    color: isTopMatch
                                                        ? Colors.amberAccent
                                                        : Colors.white,
                                                    size: 14,
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    '${job['match']}% Match',
                                                    style: TextStyle(
                                                      color: isTopMatch
                                                          ? Colors.amberAccent
                                                          : Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 4,
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          job['title'],
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: textDark,
                                            height: 1.2,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.business,
                                              size: 14,
                                              color: textLight,
                                            ),
                                            const SizedBox(width: 5),
                                            Expanded(
                                              child: Text(
                                                job['company'],
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: textLight,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 30),
              if (selectedJob != null)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.05),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Container(
                    key: ValueKey(selectedJob!['title']),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 240,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(30),
                              topRight: Radius.circular(30),
                            ),
                            image: DecorationImage(
                              image: PesoCachedNetworkImageProvider(
                                selectedJob!['image'],
                              ),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(30),
                                topRight: Radius.circular(30),
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.1),
                                  Colors.black.withValues(alpha: 0.9),
                                ],
                              ),
                            ),
                            padding: const EdgeInsets.all(30),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.business,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: Text(
                                        selectedJob!['company'],
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 18,
                                          letterSpacing: 1,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  selectedJob!['title'],
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      _buildInfoBadge(
                                        Icons.location_on,
                                        selectedJob!['location'],
                                      ),
                                      const SizedBox(width: 15),
                                      _buildInfoBadge(
                                        Icons.work,
                                        selectedJob!['type'],
                                      ),
                                      const SizedBox(width: 15),
                                      _buildInfoBadge(
                                        Icons.people,
                                        '${selectedJob!['vacancies']} Slots',
                                      ),
                                    ],
                                  ),
                                  Text(
                                    selectedJob!['salary'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: primary,
                                      fontSize: 26,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 35),
                              Text(
                                'Role Description',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: textDark,
                                ),
                              ),
                              const SizedBox(height: 15),
                              Text(
                                selectedJob!['description'],
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade700,
                                  height: 1.8,
                                ),
                              ),
                              const SizedBox(height: 35),
                              Text(
                                'AI Extracted Requirements',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: textDark,
                                ),
                              ),
                              const SizedBox(height: 15),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children:
                                    (selectedJob!['reqs'] as List<dynamic>)
                                        .map(
                                          (req) =>
                                              _buildReqChip(req.toString()),
                                        )
                                        .toList(),
                              ),
                              const SizedBox(height: 50),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [primary, Colors.green.shade800],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: primary.withValues(alpha: 0.4),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton.icon(
                                    onPressed: () => onEvaluateJob(
                                      selectedJob!['title'],
                                      selectedJob!['company'],
                                      selectedJob!['match'],
                                    ),
                                    icon: const Icon(
                                      Icons.auto_awesome,
                                      size: 24,
                                    ),
                                    label: const Text(
                                      'Evaluate Job Qualification',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      shadowColor: Colors.transparent,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 40,
                                        vertical: 24,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: textLight),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: textDark,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReqChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50.withValues(alpha: 0.5),
        border: Border.all(color: Colors.blue.shade100),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 18, color: Colors.blue.shade600),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: Colors.blue.shade900,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class QualificationEvaluationDialog extends StatefulWidget {
  final String jobTitle;
  final String company;
  final int matchScore;
  final Color pesoGreen;
  final Function(int score, bool isPassed) onComplete;

  const QualificationEvaluationDialog({
    super.key,
    required this.jobTitle,
    required this.company,
    required this.matchScore,
    required this.pesoGreen,
    required this.onComplete,
  });

  @override
  State<QualificationEvaluationDialog> createState() =>
      _QualificationEvaluationDialogState();
}

class _QualificationEvaluationDialogState
    extends State<QualificationEvaluationDialog> {
  bool _isAnalyzing = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isPassed = widget.matchScore >= 60;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(40),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _isAnalyzing
              ? _buildAnalyzingState()
              : _buildResultState(isPassed),
        ),
      ),
    );
  }

  Widget _buildAnalyzingState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      key: const ValueKey('analyzing'),
      children: [
        SizedBox(
          width: 70,
          height: 70,
          child: CircularProgressIndicator(
            color: widget.pesoGreen,
            strokeWidth: 5,
          ),
        ),
        const SizedBox(height: 30),
        const Text(
          'AI Matching Engine Active',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 15),
        Text(
          'Cross-referencing your parsed resume skills with requirements for ${widget.jobTitle} at ${widget.company}...',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 15,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildResultState(bool isPassed) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      key: const ValueKey('result'),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: (isPassed ? Colors.green : Colors.orange).withValues(
              alpha: 0.1,
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isPassed ? Icons.verified_rounded : Icons.school_rounded,
            color: isPassed ? Colors.green : Colors.orange,
            size: 56,
          ),
        ),
        const SizedBox(height: 25),
        Text(
          isPassed ? 'Qualification Pre-Vetted' : 'Upskilling Recommended',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Match Score:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${widget.matchScore}% (${isPassed ? "Pre-Vetted" : "Action Plan Generated"})',
                    style: TextStyle(
                      color: isPassed ? widget.pesoGreen : Colors.orange,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),
        Text(
          isPassed
              ? 'Your profile meets employer specifications. It has been routed to the Montalban PESO Admin queue.'
              : 'Our AI has formulated a custom TESDA upskilling action plan and identified local alternative jobs.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onComplete(widget.matchScore, isPassed);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.pesoGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'View Outcome Plan',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}

class FadeSlideEntrance extends StatefulWidget {
  final Widget child;
  final int delay;

  const FadeSlideEntrance({
    super.key,
    required this.child,
    required this.delay,
  });

  @override
  State<FadeSlideEntrance> createState() => _FadeSlideEntranceState();
}

class _FadeSlideEntranceState extends State<FadeSlideEntrance>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
