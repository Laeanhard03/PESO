import 'package:flutter/material.dart';

import '../../peso_services/app_toast.dart';

import '../../peso_models/job_posting.dart';
import '../../peso_services/peso_api_client.dart';

/// Admin job postings persisted through the protected MongoDB API.
class JobManagementSection extends StatefulWidget {
  const JobManagementSection({super.key});

  @override
  State<JobManagementSection> createState() => _JobManagementSectionState();
}

class _JobManagementSectionState extends State<JobManagementSection> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _company = TextEditingController();
  final _location = TextEditingController(text: 'Rodriguez, Rizal');
  final _salary = TextEditingController();
  final _employmentType = TextEditingController(text: 'Full-time');
  final _description = TextEditingController();
  final _requirements = TextEditingController();
  final _vacancies = TextEditingController(text: '1');

  String _category = PesoJobCategories.walkInApplication;
  List<Map<String, dynamic>> _jobs = <Map<String, dynamic>>[];
  bool _loading = false;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  @override
  void dispose() {
    _title.dispose();
    _company.dispose();
    _location.dispose();
    _salary.dispose();
    _employmentType.dispose();
    _description.dispose();
    _requirements.dispose();
    _vacancies.dispose();
    super.dispose();
  }

  Future<void> _loadJobs() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final response = await PesoApiClient.adminListJobs(limit: 300);
      final records = response['jobs'];
      if (!mounted) return;
      setState(() {
        _jobs = records is List
            ? records
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList()
            : <Map<String, dynamic>>[];
      });
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _loadError = error is PesoApiException
            ? error.message
            : 'Could not load saved job postings.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createJob() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final response = await PesoApiClient.adminCreateJob(<String, dynamic>{
        'title': _title.text.trim(),
        'company': _company.text.trim(),
        'location': _location.text.trim(),
        'salary': _salary.text.trim(),
        'employmentType': _employmentType.text.trim(),
        'description': _description.text.trim(),
        'requirements': _requirements.text
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(),
        'vacancies': int.parse(_vacancies.text.trim()),
        'category': _category,
      });
      final created = response['job'];
      if (!mounted) return;
      setState(() {
        if (created is Map) _jobs.insert(0, Map<String, dynamic>.from(created));
        _title.clear();
        _company.clear();
        _salary.clear();
        _description.clear();
        _requirements.clear();
        _vacancies.text = '1';
      });
      _notice('Job posting created successfully.');
    } catch (error) {
      if (!mounted) return;
      _notice(
        error is PesoApiException
            ? error.message
            : 'Could not create the job posting.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setJobActive(Map<String, dynamic> job, bool active) async {
    final id = job['id']?.toString() ?? '';
    if (id.isEmpty) {
      _notice('This job has no saved record ID yet.', isError: true);
      return;
    }
    try {
      final response = await PesoApiClient.adminSetJobStatus(
        id,
        active: active,
      );
      final raw = response['job'];
      if (!mounted) return;
      if (raw is Map) {
        final updated = Map<String, dynamic>.from(raw);
        final index = _jobs.indexWhere((item) => item['id']?.toString() == id);
        setState(() {
          if (index >= 0) _jobs[index] = updated;
        });
      } else {
        await _loadJobs();
      }
      _notice(active ? 'Job posting reactivated.' : 'Job posting deactivated.');
    } catch (error) {
      if (!mounted) return;
      _notice(
        error is PesoApiException
            ? error.message
            : 'Could not update this job posting.',
        isError: true,
      );
    }
  }

  void _notice(String message, {bool isError = false}) {
    isError
        ? AppToast.error(context, message)
        : AppToast.success(context, message);
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator:
          validator ??
          (value) => value == null || value.trim().isEmpty ? 'Required' : null,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
      ),
    );
  }

  Widget _badge(String label, Color background, Color foreground) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: foreground,
      ),
    ),
  );

  Widget _jobCard(Map<String, dynamic> job, bool compact) {
    final category = job['category']?.toString();
    final active = (job['status']?.toString() ?? 'active') == 'active';
    final expiry = PesoJobCategories.expiryText(job);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _badge(
                  PesoJobCategories.labelWithShortName(category),
                  const Color(0xFFDBEAFE),
                  const Color(0xFF1D4ED8),
                ),
                _badge(
                  active ? 'Active' : 'Inactive',
                  active ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                  active ? const Color(0xFF166534) : const Color(0xFF475569),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              job['title']?.toString() ?? 'Untitled job',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${job['company'] ?? 'Employer'} • ${job['location'] ?? 'Location not set'}',
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            Text(
              '${job['salary'] ?? 'Salary not set'} • ${job['employmentType'] ?? 'Type not set'} • ${job['vacancies'] ?? 1} slot(s)',
              style: const TextStyle(
                color: Color(0xFF334155),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.schedule, size: 17, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    expiry,
                    style: TextStyle(
                      color: expiry == 'Expired'
                          ? const Color(0xFFB91C1C)
                          : const Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if ((job['description']?.toString() ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                job['description'].toString(),
                maxLines: compact ? 3 : 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF475569), height: 1.4),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _setJobActive(job, !active),
                icon: Icon(
                  active
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                ),
                label: Text(active ? 'Deactivate' : 'Reactivate'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 720;
    final fieldWidth = compact ? width - 72 : (width < 1120 ? 310.0 : 350.0);
    return SingleChildScrollView(
      padding: EdgeInsets.all(compact ? 16 : 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Job Postings',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Create and manage PESO opportunities.',
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _loadJobs,
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Card(
                elevation: 0,
                color: const Color(0xFFF8FAFC),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: EdgeInsets.all(compact ? 14 : 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Create a job posting',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Choose a category. Every posting uses the regular PESO job qualification process.',
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _category,
                          decoration: InputDecoration(
                            labelText: 'Job category',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: PesoJobCategories.walkInApplication,
                              child: Text(
                                'Walk-in Application',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            DropdownMenuItem(
                              value: PesoJobCategories.localRecruitmentActivity,
                              child: Text(
                                'Local Recruitment Activity (LRA)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                          onChanged: _saving
                              ? null
                              : (value) {
                                  if (value != null)
                                    setState(() => _category = value);
                                },
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _category == PesoJobCategories.walkInApplication
                                ? 'Walk-in Application: remains listed until an Admin deactivates it. No automatic expiration.'
                                : 'Local Recruitment Activity: remains listed for 24 hours from the server-recorded creation time, then is hidden automatically.',
                            style: const TextStyle(
                              color: Color(0xFF1E40AF),
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: fieldWidth,
                              child: _field(_title, 'Job title'),
                            ),
                            SizedBox(
                              width: fieldWidth,
                              child: _field(_company, 'Employer / company'),
                            ),
                            SizedBox(
                              width: fieldWidth,
                              child: _field(_location, 'Work location'),
                            ),
                            SizedBox(
                              width: fieldWidth,
                              child: _field(_salary, 'Salary / compensation'),
                            ),
                            SizedBox(
                              width: fieldWidth,
                              child: _field(_employmentType, 'Employment type'),
                            ),
                            SizedBox(
                              width: fieldWidth,
                              child: _field(
                                _vacancies,
                                'Number of vacancies',
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  final count = int.tryParse(
                                    value?.trim() ?? '',
                                  );
                                  if (count == null ||
                                      count < 1 ||
                                      count > 100000)
                                    return 'Enter a positive whole number';
                                  return null;
                                },
                              ),
                            ),
                            SizedBox(
                              width: fieldWidth,
                              child: _field(
                                _requirements,
                                'Requirements (comma-separated)',
                                maxLines: 2,
                                validator: (_) => null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _field(_description, 'Job description', maxLines: 4),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _createJob,
                            icon: _saving
                                ? const SizedBox(
                                    width: 17,
                                    height: 17,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.publish),
                            label: Text(_saving ? 'Saving…' : 'Publish job'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Saved job postings',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Text(
                    '${_jobs.length} total',
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_loadError != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _loadError!,
                    style: const TextStyle(color: Color(0xFF991B1B)),
                  ),
                )
              else if (_loading && _jobs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_jobs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 22),
                  child: Text(
                    'No saved postings yet. Create one above to make it available to job seekers.',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 900 ? 2 : 1;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _jobs.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        mainAxisExtent: 320,
                      ),
                      itemBuilder: (context, index) =>
                          _jobCard(_jobs[index], compact),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
