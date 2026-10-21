import 'package:flutter/material.dart';

import 'user_job_feed_tab.dart'; // Imports FadeSlideEntrance
import '../Reusable_Designs/peso_premium_ui.dart';
import 'readiness_report_card.dart';

class UserOutcomesTab extends StatelessWidget {
  final List<Map<String, dynamic>> assessmentOutcomes;
  final List<Map<String, dynamic>> applications;
  final bool applicationsLoading;
  final String? applicationsError;
  final String? focusedApplicationId;
  final VoidCallback? onRefreshApplications;
  final String Function(String) translate;
  final Color primary;
  final Color textDark;
  final Color textLight;
  final ValueChanged<Map<String, dynamic>>? onSubmitReadiness;
  final ValueChanged<Map<String, dynamic>>? onEditQualifications;
  final VoidCallback? onEditPersonalInfo;
  final ValueChanged<Map<String, dynamic>>? onRecheckReadiness;
  final String? submittingReportId;

  const UserOutcomesTab({
    super.key,
    required this.assessmentOutcomes,
    this.applications = const [],
    this.applicationsLoading = false,
    this.applicationsError,
    this.focusedApplicationId,
    this.onRefreshApplications,
    required this.translate,
    required this.primary,
    required this.textDark,
    required this.textLight,
    this.onSubmitReadiness,
    this.onEditQualifications,
    this.onEditPersonalInfo,
    this.onRecheckReadiness,
    this.submittingReportId,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < 600;
    final medium = screenWidth < 1024;
    if (assessmentOutcomes.isEmpty &&
        applications.isEmpty &&
        !applicationsLoading &&
        applicationsError == null) {
      return Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(compact ? 16 : 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: compact ? (screenWidth - 32).clamp(260.0, 640.0) : 640,
            ),
            child: FadeSlideEntrance(
              delay: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF3ED),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFD9E8DF)),
                    ),
                    child: Icon(
                      Icons.analytics_rounded,
                      size: 80,
                      color: const Color(0xFF236349),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'No Assessments Evaluated Yet',
                    textAlign: TextAlign.center,
                    softWrap: true,
                    style: TextStyle(
                      fontSize: compact ? 24 : 32,
                      fontWeight: FontWeight.w900,
                      color: textDark,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    'Evaluate your qualification for a position in the Job Feed to generate personalized career plans.',
                    textAlign: TextAlign.center,
                    softWrap: true,
                    style: TextStyle(
                      color: textLight,
                      fontSize: compact ? 15 : 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(compact ? 16 : (medium ? 24 : 50)),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeSlideEntrance(
                delay: 0,
                child: PesoPageHeader(
                  title: translate('Outcomes & Action Plans'),
                  description: translate(
                    'Review pre-vetted statuses or recommended TESDA courses.',
                  ),
                  eyebrow: 'Your career progress',
                  icon: Icons.insights_rounded,
                  detail: PesoHeaderPill(
                    icon: Icons.fact_check_outlined,
                    label: '${assessmentOutcomes.length} recorded outcomes',
                  ),
                ),
              ),
              const SizedBox(height: 22),
              _buildApplicationHistory(compact),
              const SizedBox(height: 24),
              ...List.generate(assessmentOutcomes.length, (index) {
                final outcome = assessmentOutcomes[index];
                return FadeSlideEntrance(
                  delay: 90 + (index.clamp(0, 4) * 55),
                  child: outcome['status'] == 'readiness'
                      ? ReadinessReportCard(
                          data: outcome,
                          submitting:
                              submittingReportId != null &&
                              submittingReportId ==
                                  outcome['createdAt']?.toString(),
                          onSubmitApplication: onSubmitReadiness == null
                              ? null
                              : () => onSubmitReadiness!(outcome),
                          onEditQualifications: onEditQualifications == null
                              ? null
                              : () => onEditQualifications!(outcome),
                          onEditPersonalInfo: onEditPersonalInfo,
                          onRecheck: onRecheckReadiness == null
                              ? null
                              : () => onRecheckReadiness!(outcome),
                        )
                      : outcome['status'] == 'passed'
                      ? _buildPassCard(outcome, compact: compact)
                      : outcome['status'] == 'recommended'
                      ? _buildRecommendationCard(outcome, compact: compact)
                      : _buildActionPlanCard(outcome, compact: compact),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPassCard(Map<String, dynamic> data, {required bool compact}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: EdgeInsets.all(compact ? 16 : 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.green.shade200, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.1),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 48,
            ),
          ),
          const SizedBox(width: 30),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['job'],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: compact ? 22 : 28,
                            fontWeight: FontWeight.w900,
                            color: textDark,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          data['company'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 10 : 20,
                        vertical: compact ? 8 : 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withValues(alpha: 0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Text(
                        'Score: ${data['score']}% - PRE-VETTED',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  data['message'],
                  style: TextStyle(
                    color: Colors.grey.shade800,
                    fontSize: 18,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// JSON restores arrays as `List<dynamic>`; never cast them to `List<String>`.
  /// Ignore malformed entries while retaining valid text and numeric labels.
  static List<String> _outcomeLabels(dynamic value) {
    if (value is! List) return const <String>[];
    return value
        .where((entry) => entry is String || entry is num)
        .map((entry) => entry.toString().trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }

  Widget _buildActionPlanCard(
    Map<String, dynamic> data, {
    required bool compact,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: EdgeInsets.all(compact ? 16 : 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border(
          top: BorderSide(color: Colors.orange.shade400, width: 6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.psychology,
                        color: Colors.orange,
                        size: 36,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AI Career Action Plan',
                            style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${data['job']} @ ${data['company']}',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: compact ? 20 : 24,
                              fontWeight: FontWeight.w900,
                              color: textDark,
                              letterSpacing: -0.5,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 10 : 20,
                    vertical: compact ? 8 : 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Score: ${data['score']}% - UPSKILLING REQUIRED',
                    softWrap: true,
                    style: TextStyle(
                      color: textLight,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          const Divider(color: Colors.black12),
          const SizedBox(height: 40),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Identified Skill Gaps',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _outcomeLabels(data['failed_skills'])
                          .map((skill) => _buildGapChip(skill))
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 40),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Alternative Local Jobs',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _outcomeLabels(data['alt_jobs'])
                          .map((job) => _buildAltJobChip(job))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 50),
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade50, Colors.white],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 640;
                final left = Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.1),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.school,
                        color: Colors.blue.shade700,
                        size: 36,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recommended TESDA Course',
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            data['training']?.toString() ??
                                'No training recommendation recorded.',
                            softWrap: true,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              color: textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                final button = ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'View Local Center',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                );
                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      left,
                      const SizedBox(height: 16),
                      button,
                    ],
                  );
                }
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Expanded(child: left),
                    button,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _officialApplicationStatus(String value) => switch (value) {
    'under_review' => 'Under review',
    'matched' => 'Qualified for PESO referral',
    'accepted' => 'Accepted',
    'rejected' => 'Declined',
    'action_required' => 'Action needed',
    _ => 'Submitted',
  };

  String _applicationTimestamp(dynamic raw) {
    final parsed = DateTime.tryParse(raw?.toString() ?? '');
    if (parsed == null) return 'Date unavailable';
    final ph = parsed.toUtc().add(const Duration(hours: 8));
    final formatted = ph.toIso8601String().replaceFirst('T', ' ');
    return '${formatted.substring(0, 16)} PHT';
  }

  Widget _buildApplicationHistory(bool compact) {
    final sorted = [...applications];
    if (focusedApplicationId != null) {
      sorted.sort(
        (a, b) => (a['id'] == focusedApplicationId ? -1 : 0).compareTo(
          b['id'] == focusedApplicationId ? -1 : 0,
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 16 : 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDDE8E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Your PESO applications',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Refresh saved application statuses',
                onPressed: onRefreshApplications,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const Text(
            'These are official PESO application records, separate from AI recommendations.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          if (applicationsLoading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (applicationsError != null) ...[
            const SizedBox(height: 8),
            Text(
              applicationsError!,
              style: const TextStyle(color: Color(0xFFB45309)),
            ),
          ],
          if (sorted.isEmpty && !applicationsLoading) ...[
            const SizedBox(height: 14),
            const Text(
              'No submitted applications are saved to your account yet.',
            ),
          ],
          ...sorted.map((row) {
            final id = row['id']?.toString() ?? '';
            final status = _officialApplicationStatus(
              row['status']?.toString() ?? 'submitted',
            );
            final focused = id == focusedApplicationId;
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: focused
                        ? const Color(0xFF236349)
                        : const Color(0xFFDDE8E2),
                    width: focused ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ExpansionTile(
                  key: ValueKey('application-$id-$focused'),
                  initiallyExpanded: focused,
                  title: Text(
                    row['jobTitle']?.toString() ?? 'Saved job',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${row['employer'] ?? 'PESO'} • $status',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  leading: const Icon(Icons.assignment_turned_in_outlined),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Status: $status',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Submitted: ${_applicationTimestamp(row['submittedAt'])}',
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Only PESO and the employer can confirm official hiring decisions.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(
    Map<String, dynamic> data, {
    required bool compact,
  }) {
    final answers = data['answers'] is Map
        ? Map<String, dynamic>.from(data['answers'] as Map)
        : <String, dynamic>{};
    final submittedAt = data['submittedAt']?.toString();
    final rawStatus =
        data['applicationStatus']?.toString().toLowerCase() ?? 'submitted';
    final officialStatus = switch (rawStatus) {
      'reviewing' || 'under_review' || 'in_review' => 'Under review',
      'qualified' || 'accepted' || 'approved' => 'Qualified',
      'declined' || 'rejected' || 'not_qualified' => 'Declined',
      'needs_action' ||
      'action_required' ||
      'needs_documents' => 'Action needed',
      _ => 'Submitted',
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: EdgeInsets.all(compact ? 16 : 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.green.shade200, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.1),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: Colors.green,
                  size: 36,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI-guided recommendation (not a hiring decision)',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${data['job']} @ ${data['company']}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 20 : 24,
                        fontWeight: FontWeight.w900,
                        color: textDark,
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (data['applicationSubmitted'] == true) ...[
            Text(
              'PESO application: $officialStatus',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF1D4ED8),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            data['message']?.toString() ?? 'This AI-guided report is for career planning. PESO or the employer makes official screening and hiring decisions.',
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 16,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (answers.isNotEmpty) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: answers.entries
                  .map(
                    (entry) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade100),
                      ),
                      child: Text(
                        '${_labelFor(entry.key)}: ${entry.value}',
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Next steps',
                  style: TextStyle(
                    color: Colors.blue.shade800,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '1. Wait for a call or message from PESO Montalban.\n'
                  '2. Bring your resume, valid ID and any required certificates.\n'
                  '3. Report to the PESO Montalban office when scheduled.',
                  style: TextStyle(
                    color: Colors.blue.shade900,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                if (submittedAt != null && submittedAt.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Submitted: $submittedAt',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _labelFor(String key) {
    switch (key) {
      case 'experience':
        return 'Experience';
      case 'availability':
        return 'Start';
      case 'willingToWork':
        return 'Willing to work';
      case 'interviewWilling':
        return 'Interview';
      case 'driverLicense':
        return 'Driver license';
      case 'certificate':
        return 'Certificate';
      case 'education':
        return 'Education';
      case 'computerSkills':
        return 'Computer skills';
      default:
        return key;
    }
  }

  Widget _buildGapChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.red.shade700,
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildAltJobChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.blue.shade700,
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    );
  }
}
