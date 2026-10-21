import 'package:flutter/material.dart';

import '../../peso_services/peso_api_client.dart';

/// Admin view of screening applications submitted by job seekers from the
/// job feed ("Continue Application"). Each row holds the applicant, the job,
/// the submitted answers and the timestamp.
class JobApplicationsSection extends StatefulWidget {
  const JobApplicationsSection({super.key});

  @override
  State<JobApplicationsSection> createState() => _JobApplicationsSectionState();
}

class _JobApplicationsSectionState extends State<JobApplicationsSection> {
  List<Map<String, dynamic>> _applications = <Map<String, dynamic>>[];
  bool _loading = false;
  String? _loadError;
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final response = await PesoApiClient.adminListApplications(limit: 200);
      final records = response['applications'];
      if (!mounted) return;
      setState(() {
        _applications = records is List
            ? records
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList()
            : <Map<String, dynamic>>[];
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error is PesoApiException
            ? error.message
            : 'Could not load job applications.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _labelFor(String key) {
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(_loadError!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loadApplications,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_applications.isEmpty) {
      return const Center(
        child: Text('No job applications submitted yet.'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadApplications,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _applications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final app = _applications[index];
          final answers = app['answers'] is Map
              ? Map<String, dynamic>.from(app['answers'] as Map)
              : <String, dynamic>{};
          final expanded = _expandedIndex == index;
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              (app['applicantName'] ?? app['applicantEmail'] ?? 'Applicant').toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              (app['applicantEmail'] ?? '').toString(),
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          (app['status'] ?? 'submitted').toString(),
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${app['jobTitle'] ?? 'Untitled job'} @ ${app['employer'] ?? 'Employer'}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${app['location'] ?? ''}  •  ${app['submittedAt'] ?? ''}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _expandedIndex = expanded ? null : index;
                    }),
                    icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                    label: Text(expanded ? 'Hide answers' : 'View answers'),
                  ),
                  if (expanded) ...<Widget>[
                    const Divider(),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: answers.entries
                          .map((entry) => Chip(
                                label: Text(
                                  '${_labelFor(entry.key)}: ${entry.value}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                backgroundColor: Colors.blue.shade50,
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
