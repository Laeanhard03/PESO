import 'package:flutter/material.dart';

import '../../peso_services/app_toast.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../peso_services/peso_api_client.dart';
import '../../peso_models/job_posting.dart';

/// Registers trusted, publicly accessible PDF links for admin review.
/// Does not present simulated ingestion or matching metrics.
class AdminPdfLinkIngestionSection extends StatefulWidget {
  const AdminPdfLinkIngestionSection({super.key});

  @override
  State<AdminPdfLinkIngestionSection> createState() =>
      _AdminPdfLinkIngestionSectionState();
}

class _AdminPdfLinkIngestionSectionState
    extends State<AdminPdfLinkIngestionSection> {
  final _titleController = TextEditingController();
  final _urlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  List<Map<String, dynamic>> _sources = [];
  bool _loading = true;
  bool _saving = false;
  String? _message;
  String? _error;
  String? _sourceCategory;
  static const _green = Color(0xFF236349);

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await PesoApiClient.adminListPdfLinks();
      final records = response['sources'] is List
          ? (response['sources'] as List)
                .whereType<Map>()
                .map((row) => Map<String, dynamic>.from(row))
                .toList()
          : <Map<String, dynamic>>[];
      if (mounted) setState(() => _sources = records);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is PesoApiException
              ? error.message
              : 'Could not load linked PDFs from the PESO API.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() {
      _saving = true;
      _message = null;
      _error = null;
    });
    try {
      final result = await PesoApiClient.adminAddPdfLink(
        title: _titleController.text,
        url: _urlController.text,
        category: _sourceCategory!,
      );
      if (!mounted) return;
      setState(() {
        _message = result['updated'] == true
            ? 'PDF source category updated. Review it before publishing vacancies.'
            : result['existing'] == true
            ? 'This categorized PDF is already in the review queue.'
            : 'PDF link categorized and attached for review. No vacancy was published automatically.';
        _titleController.clear();
        _urlController.clear();
        _sourceCategory = null;
      });
      await _fetch();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is PesoApiException
              ? error.message
              : 'The link could not be checked or attached.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 620;
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 970),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Online PDF Job Sources',
                style: TextStyle(
                  color: const Color(0xFF17352B),
                  fontSize: compact ? 24 : 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'Add a public recruitment PDF link to the PESO review queue. '
                'The server verifies the URL and saves it; an admin must review '
                'the document and publish job listings separately. '
                'Historical compilation PDFs (including the July 2020 Walk-in '
                'and LRA documents) are reference sources, not confirmed current '
                'vacancies. Verify dates before posting; new LRA postings '
                'expire from the applicant feed after 24 hours.',
                style: TextStyle(color: Color(0xFF52675D), height: 1.55),
              ),
              const SizedBox(height: 25),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(compact ? 17 : 29),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFDCE9E1)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0E17352B),
                      blurRadius: 17,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.picture_as_pdf_outlined, color: _green),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Attach an online PDF',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 19,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      TextFormField(
                        controller: _titleController,
                        maxLength: 180,
                        decoration: const InputDecoration(
                          labelText: 'Source title',
                          hintText: 'e.g. October Recruitment Bulletin',
                          prefixIcon: Icon(Icons.title),
                        ),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Give this document a title.'
                            : null,
                      ),
                      const SizedBox(height: 9),
                      DropdownButtonFormField<String>(
                        key: ValueKey(
                          'pdf-source-category-${_sourceCategory ?? 'unset'}',
                        ),
                        initialValue: _sourceCategory,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Recruitment source type',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: PesoJobCategories.choices
                            .map(
                              (category) => DropdownMenuItem(
                                value: category,
                                child: Text(
                                  PesoJobCategories.labelWithShortName(
                                    category,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _saving
                            ? null
                            : (value) =>
                                  setState(() => _sourceCategory = value),
                        validator: (value) => value == null
                            ? 'Select Walk-in or Local Recruitment Activity.'
                            : null,
                      ),
                      const SizedBox(height: 9),
                      TextFormField(
                        controller: _urlController,
                        keyboardType: TextInputType.url,
                        maxLines: compact ? 2 : 1,
                        decoration: const InputDecoration(
                          labelText: 'Direct public HTTPS .pdf link',
                          hintText: 'https://example.gov.ph/jobs/bulletin.pdf',
                          prefixIcon: Icon(Icons.link),
                        ),
                        validator: (value) {
                          final uri = Uri.tryParse((value ?? '').trim());
                          return uri == null ||
                                  uri.scheme != 'https' ||
                                  !uri.path.toLowerCase().endsWith('.pdf')
                              ? 'Enter a direct HTTPS .pdf document URL.'
                              : null;
                        },
                      ),
                      const SizedBox(height: 13),
                      const Text(
                        'Supported: public government PDF sources, plus hosts approved '
                        'in the PESO server configuration. Private cloud links, '
                        'webpage viewers, or restricted PDFs need an approved source.',
                        style: TextStyle(
                          color: Color(0xFF667B70),
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 13),
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                      if (_message != null) ...[
                        const SizedBox(height: 13),
                        Text(_message!, style: const TextStyle(color: _green)),
                      ],
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _submit,
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.add_link),
                          label: Text(
                            _saving
                                ? 'Checking PDF...'
                                : 'Verify and attach PDF',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: _green,
                            minimumSize: const Size(170, 48),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Attached source documents',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF17352B),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh attached PDFs',
                    onPressed: _loading ? null : _fetch,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(22),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_sources.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    'No linked PDFs yet. Add a verified source above.',
                  ),
                )
              else
                ..._sources.map(
                  (source) => Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE0EAE4)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.description_outlined, color: _green),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                source['title']?.toString() ?? 'PDF',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Chip(
                                label: Text(
                                  source['category'] == null
                                      ? 'Category not set — needs review'
                                      : PesoJobCategories.labelWithShortName(
                                          source['category']?.toString(),
                                        ),
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                source['url']?.toString() ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF52675D),
                                ),
                              ),
                              const SizedBox(height: 5),
                              const Text(
                                'Verified link · Awaiting review · No job imported yet',
                                style: TextStyle(
                                  color: Color(0xFF92611D),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Open PDF for admin review',
                          icon: const Icon(
                            Icons.open_in_new_rounded,
                            color: _green,
                          ),
                          onPressed: () async {
                            final uri = Uri.tryParse(
                              source['url']?.toString() ?? '',
                            );
                            if (uri == null || uri.scheme != 'https') return;
                            final opened = await launchUrl(
                              uri,
                              mode: LaunchMode.platformDefault,
                              webOnlyWindowName: '_blank',
                            );
                            if (!opened && context.mounted) {
                              AppToast.warning(
                                context,
                                'The PDF could not open in a new tab. Check your browser popup settings and try again.',
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
