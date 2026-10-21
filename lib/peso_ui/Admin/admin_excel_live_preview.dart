import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../peso_services/app_toast.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../peso_services/peso_api_client.dart';

class AdminExcelLivePreview extends StatefulWidget {
  const AdminExcelLivePreview({super.key});

  @override
  State<AdminExcelLivePreview> createState() => _AdminExcelLivePreviewState();
}

class _AdminExcelLivePreviewState extends State<AdminExcelLivePreview> {
  final _rows = <List<String>>[];
  bool _loading = true;
  String _selected = 'All';
  String? _error;
  Uri? _workbookUrl;
  DateTime? _updated;
  Timer? _refreshTimer;
  static const _green = Color(0xFF236349);
  static const _labels = [
    'Name',
    'Email',
    'Location',
    'Job / Preference',
    'Employer',
    'Status',
  ];
  static const _widths = [165.0, 210.0, 140.0, 205.0, 160.0, 150.0];
  static String _str(dynamic input) => input?.toString() ?? '';
  static String _category(String status, {required bool applied}) {
    if (!applied) return 'Not Yet Applied';
    if (status == 'matched' || status == 'accepted') return 'Successful';
    if (status == 'rejected' || status == 'not_matched') return 'Needs Support';
    return 'Under Review';
  }

  @override
  void initState() {
    super.initState();
    _refresh();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && !_loading) _refresh();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Uri? get _liveLink {
    final base = Uri.base;
    if (base.scheme != 'https' && base.scheme != 'http') return null;
    return base.replace(
      queryParameters: const {'liveApplicants': '1'},
      fragment: '',
    );
  }

  Future<void> _copyLiveLink() async {
    final link = _liveLink;
    if (link == null) {
      if (mounted)
        AppToast.warning(
          context,
          'Online links are available from the PESO web app.',
        );
      return;
    }
    await Clipboard.setData(ClipboardData(text: link.toString()));
    if (mounted) {
      AppToast.success(
        context,
        'Private live spreadsheet link copied. Admin sign-in is required.',
      );
    }
  }

  Future<void> _openLiveLink() async {
    final link = _liveLink;
    if (link == null) {
      if (mounted)
        AppToast.warning(
          context,
          'Open the PESO web app to view its live spreadsheet.',
        );
      return;
    }
    final opened = await launchUrl(
      link,
      mode: LaunchMode.platformDefault,
      webOnlyWindowName: '_blank',
    );
    if (!opened && mounted) {
      AppToast.warning(
        context,
        'Could not open the live register tab. Copy the live link instead.',
      );
    }
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = <Map<String, dynamic>>[];
      String? pageToken;
      final seenTokens = <String>{};
      for (var page = 0; page < 100; page++) {
        final pageData = await PesoApiClient.adminListUsers(
          limit: 500,
          pageToken: pageToken,
        );
        users.addAll(
          (pageData['users'] as List? ?? const []).whereType<Map>().map(
            (raw) => Map<String, dynamic>.from(raw),
          ),
        );
        pageToken = pageData['nextPageToken']?.toString();
        if (pageToken == null || pageToken.isEmpty) break;
        if (!seenTokens.add(pageToken) || page == 99) {
          throw StateError(
            'The account list is too large or its pagination token repeated. Try again.',
          );
        }
      }
      // The live table must fetch all pages, not just the first 500 results.
      final applications = <Map<String, dynamic>>[];
      String? applicationToken;
      final seenApplicationTokens = <String>{};
      for (var page = 0; page < 100; page++) {
        final response = await PesoApiClient.adminListApplications(
          limit: 500,
          pageToken: applicationToken,
        );
        if (!response.containsKey('nextPageToken')) {
          throw StateError(
            'Restart the updated PESO API to enable complete application paging.',
          );
        }
        applications.addAll(
          (response['applications'] as List? ?? const []).whereType<Map>().map(
            (raw) => Map<String, dynamic>.from(raw),
          ),
        );
        final next = response['nextPageToken']?.toString();
        if (next == null || next.isEmpty) break;
        if (!seenApplicationTokens.add(next) || page == 99) {
          throw StateError(
            'The application list is too large or its pagination token repeated. Try again.',
          );
        }
        applicationToken = next;
      }
      final byUid = <String, Map<String, dynamic>>{
        for (final item in users)
          if (_str(item['uid']).isNotEmpty && _str(item['role']) != 'admin')
            _str(item['uid']): item,
      };
      final applied = <String>{};
      final rows = <List<String>>[];
      for (final app in applications) {
        final uid = _str(app['applicantUid']);
        if (uid.isNotEmpty) applied.add(uid);
        final u = byUid[uid] ?? <String, dynamic>{};
        final status = _str(app['status']);
        rows.add([
          _str(app['applicantName']).isEmpty
              ? _str(u['displayName'])
              : _str(app['applicantName']),
          _str(app['applicantEmail']).isEmpty
              ? _str(u['email'])
              : _str(app['applicantEmail']),
          _str(u['location']),
          _str(app['jobTitle']),
          _str(app['employer']),
          status.isEmpty ? 'submitted' : status,
          _category(status, applied: true),
        ]);
      }
      for (final entry in byUid.entries) {
        if (applied.contains(entry.key)) continue;
        final u = entry.value;
        rows.add([
          _str(u['displayName']),
          _str(u['email']),
          _str(u['location']),
          _str(u['professionalTitle']),
          '',
          'Not yet applied',
          'Not Yet Applied',
        ]);
      }
      const rank = {
        'Successful': 0,
        'Under Review': 1,
        'Needs Support': 2,
        'Not Yet Applied': 3,
      };
      rows.sort((a, b) {
        final status = (rank[a[6]] ?? 8).compareTo(rank[b[6]] ?? 8);
        return status != 0 ? status : a[0].compareTo(b[0]);
      });
      final exportResponse = await PesoApiClient.adminCreateExportLink();
      final candidate = Uri.tryParse(_str(exportResponse['url']));
      if (!mounted) return;
      setState(() {
        _rows
          ..clear()
          ..addAll(rows);
        _workbookUrl =
            candidate != null &&
                (candidate.scheme == 'https' || candidate.scheme == 'http')
            ? candidate
            : null;
        _updated = DateTime.now();
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          if (error is PesoApiException &&
              (error.statusCode == 401 || error.statusCode == 403)) {
            // A logged-out or deauthorized administrator must not continue to
            // see stale private applicant rows or a previously issued export.
            _rows.clear();
            _workbookUrl = null;
            _updated = null;
            _error =
                'Your administrator session is no longer authorized. '
                'Sign in again to view the private register.';
          } else {
            _error = error is PesoApiException
                ? error.message
                : error is StateError
                ? error.toString().replaceFirst('Bad state: ', '')
                : 'Live preview could not load. Check your admin API connection.';
          }
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _row(List<String> cells, {bool heading = false, bool alt = false}) {
    return Container(
      color: heading
          ? const Color(0xFFE9F3EC)
          : alt
          ? const Color(0xFFF8FBF8)
          : Colors.white,
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++)
            SizedBox(
              width: _widths[i],
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
                child: Text(
                  cells[i].isEmpty ? '—' : cells[i],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: const Color(0xFF17352B),
                    fontWeight: heading || i == 0
                        ? FontWeight.w800
                        : FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final width = (screen.width - 24).clamp(300.0, 1150.0);
    final height = (screen.height * 0.84).clamp(360.0, 790.0);
    final displayed = _selected == 'All'
        ? _rows
        : _rows.where((row) => row[6] == _selected).toList();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 10, 4),
              child: Row(
                children: [
                  const Icon(Icons.table_view_outlined, color: _green),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Live Applicant Register',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Auto-refreshes from PESO every 30 seconds (admin only)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF52675D),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close live register',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final choice in [
                    'All',
                    'Successful',
                    'Under Review',
                    'Needs Support',
                    'Not Yet Applied',
                  ])
                    ChoiceChip(
                      label: Text(choice),
                      selected: _selected == choice,
                      onSelected: (_) => setState(() => _selected = choice),
                    ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            if (_loading && _rows.isEmpty)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: _widths.reduce((a, b) => a + b),
                    child: ListView.builder(
                      itemCount: displayed.length + 1,
                      itemBuilder: (context, i) => i == 0
                          ? _row(_labels, heading: true)
                          : _row(displayed[i - 1], alt: i.isEven),
                    ),
                  ),
                ),
              ),
            const Divider(height: 1),
            if (screen.width < 600)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Refresh register',
                      onPressed: _loading ? null : _refresh,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _liveLink == null ? null : _openLiveLink,
                        icon: const Icon(Icons.open_in_new_rounded, size: 17),
                        label: const Text(
                          'Open live spreadsheet',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: FilledButton.styleFrom(backgroundColor: _green),
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'More live register options',
                      icon: const Icon(Icons.more_vert_rounded),
                      onSelected: (choice) async {
                        if (choice == 'copy') {
                          await _copyLiveLink();
                        } else if (choice == 'xlsx' && _workbookUrl != null) {
                          await launchUrl(
                            _workbookUrl!,
                            mode: LaunchMode.platformDefault,
                            webOnlyWindowName: '_blank',
                          );
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'copy',
                          child: Text('Copy private live link'),
                        ),
                        PopupMenuItem(
                          value: 'xlsx',
                          enabled: _workbookUrl != null,
                          child: const Text('Download Excel workbook'),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(11),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${displayed.length} visible • ${_updated == null ? 'Loading...' : 'Live snapshot'}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF52675D),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _copyLiveLink,
                      icon: const Icon(Icons.link_rounded, size: 17),
                      label: const Text('Copy live link'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _openLiveLink,
                      icon: const Icon(Icons.open_in_new_rounded, size: 17),
                      label: const Text('Open online spreadsheet'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _refresh,
                      icon: const Icon(Icons.refresh, size: 17),
                      label: const Text('Refresh'),
                    ),
                    FilledButton.icon(
                      onPressed: _workbookUrl == null
                          ? null
                          : () async {
                              final opened = await launchUrl(
                                _workbookUrl!,
                                mode: LaunchMode.platformDefault,
                                webOnlyWindowName: '_blank',
                              );
                              if (!opened && context.mounted) {
                                AppToast.warning(
                                  context,
                                  'Your browser blocked the Excel download. Allow downloads for this site, then try again.',
                                );
                              }
                            },
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: const Text('Full Excel workbook'),
                      style: FilledButton.styleFrom(backgroundColor: _green),
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
