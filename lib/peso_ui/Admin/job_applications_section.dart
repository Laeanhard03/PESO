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
  bool _loadingMore = false;
  String? _nextPageToken;
  String? _savingStatusId;
  static const _statusNames = <String, String>{
    'submitted': 'Submitted',
    'under_review': 'Under review',
    'matched': 'Qualified for PESO referral',
    'accepted': 'Accepted',
    'rejected': 'Declined',
    'action_required': 'Action needed',
  };
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
      final response = await PesoApiClient.adminListApplications(limit: 100);
      final records = response['applications'];
      if (!mounted) return;
      setState(() {
        _applications = records is List
            ? records
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList()
            : <Map<String, dynamic>>[];
        _nextPageToken = response['nextPageToken']?.toString();
        _expandedIndex = null;
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

  Future<void> _loadMoreApplications() async {
    final token = _nextPageToken;
    if (token == null || _loadingMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final response = await PesoApiClient.adminListApplications(
        limit: 100,
        pageToken: token,
      );
      final rows = response['applications'];
      if (rows is! List)
        throw const FormatException('Invalid applications response');
      if (!mounted) return;
      final ids = _applications.map((row) => row['id']?.toString()).toSet();
      setState(() {
        _applications.addAll(
          rows
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .where((row) => ids.add(row['id']?.toString())),
        );
        _nextPageToken = response['nextPageToken']?.toString();
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load more applications. Retry.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _setOfficialStatus(
    Map<String, dynamic> row,
    String status,
  ) async {
    final id = row['id']?.toString() ?? '';
    if (id.isEmpty || _savingStatusId != null) return;
    setState(() => _savingStatusId = id);
    try {
      final response = await PesoApiClient.adminSetApplicationStatus(
        id,
        status,
      );
      final saved = response['application'];
      if (saved is! Map)
        throw const FormatException('Invalid application status response');
      if (!mounted) return;
      final index = _applications.indexWhere(
        (item) => item['id']?.toString() == id,
      );
      setState(() {
        if (index >= 0) _applications[index] = Map<String, dynamic>.from(saved);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Official status updated: ${_statusNames[status] ?? status}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is PesoApiException
                ? error.message
                : 'Unable to save the official application status.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingStatusId = null);
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
      return const Center(child: Text('No job applications submitted yet.'));
    }

    return RefreshIndicator(
      onRefresh: _loadApplications,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _applications.length + (_nextPageToken == null ? 0 : 1),
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == _applications.length) {
            return Center(
              child: FilledButton.tonalIcon(
                onPressed: _loadingMore ? null : _loadMoreApplications,
                icon: _loadingMore
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more_rounded),
                label: Text(
                  _loadingMore
                      ? 'Loading applications...'
                      : 'Load more applications',
                ),
              ),
            );
          }
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
                              (app['applicantName'] ??
                                      app['applicantEmail'] ??
                                      'Applicant')
                                  .toString(),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _statusNames[app['status']?.toString()] ??
                              'Submitted',
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Update official PESO application status',
                        enabled: _savingStatusId == null,
                        icon: _savingStatusId == app['id']?.toString()
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.edit_note_rounded),
                        onSelected: (status) => _setOfficialStatus(app, status),
                        itemBuilder: (context) => _statusNames.entries
                            .map(
                              (entry) => PopupMenuItem(
                                value: entry.key,
                                child: Text(entry.value),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${app['jobTitle'] ?? 'Untitled job'} @ ${app['employer'] ?? 'Employer'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
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
                    icon: Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                    ),
                    label: Text(expanded ? 'Hide answers' : 'View answers'),
                  ),
                  if (expanded) ...<Widget>[
                    const Divider(),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: answers.entries
                          .map(
                            (entry) => Chip(
                              label: Text(
                                '${_labelFor(entry.key)}: ${entry.value}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              backgroundColor: Colors.blue.shade50,
                            ),
                          )
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
