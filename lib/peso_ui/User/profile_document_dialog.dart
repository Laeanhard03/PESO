import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../peso_services/peso_api_client.dart';
import 'profile_pdf_view.dart';

/// Owner-authenticated PDF/image preview with no popups or signed file URL.
class ProfileDocumentDialog extends StatefulWidget {
  const ProfileDocumentDialog({
    super.key,
    required this.artifact,
    this.onReplacePdf,
    this.onEditNsrp,
    this.fetchBytes,
  });
  final Map<String, dynamic> artifact;
  final Future<bool> Function()? onReplacePdf;
  final VoidCallback? onEditNsrp;

  /// Test seam for deterministic owner-checked bytes without network calls.
  final Future<Uint8List> Function(String artifactId)? fetchBytes;

  @override
  State<ProfileDocumentDialog> createState() => _ProfileDocumentDialogState();
}

class _ProfileDocumentDialogState extends State<ProfileDocumentDialog> {
  Uint8List? _bytes;
  String? _loadError;
  bool _busy = true;
  bool _replacing = false;
  Color get _green => const Color(0xFF236349);
  String get _fileName =>
      widget.artifact['fileName']?.toString() ?? 'document.pdf';
  String get _category => widget.artifact['category']?.toString() ?? '';
  bool get _isPdf =>
      widget.artifact['mimeType']?.toString() == 'application/pdf';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _busy = true;
        _loadError = null;
      });
    }
    try {
      final id = widget.artifact['id']?.toString() ?? '';
      if (id.isEmpty) throw StateError('This document has no saved file ID.');
      final bytes =
          await (widget.fetchBytes ?? PesoApiClient.readArtifactBytes)(id);
      if (!mounted) return;
      setState(() => _bytes = bytes);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _bytes = null;
        _loadError = error is PesoApiException
            ? error.message
            : 'Unable to read this stored document. Please retry.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download() async {
    final bytes = _bytes;
    if (bytes == null) return;
    final saved = await ProfilePdfDownload.save(bytes, _fileName);
    if (!saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Downloading this file requires a web browser.'),
        ),
      );
    }
  }

  Future<void> _editWithCanva() async {
    final bytes = _bytes;
    if (bytes == null) return;
    Future<bool>? editor;
    final approve = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit PDF in Canva'),
        content: const Text(
          'PESO will download a copy of your PDF and open the official Canva PDF editor. '
          'Sign in to Canva using Google if you choose, then upload the downloaded PDF. '
          'When finished, export it as a PDF and return to PESO to select Upload revised PDF. '
          'Your original remains private in PESO until you choose to upload a replacement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              // This must happen directly in the confirmation-button handler;
              // otherwise browser popup blockers can stop Canva opening.
              editor = launchUrl(
                Uri.parse('https://www.canva.com/pdf-editor/'),
                mode: LaunchMode.platformDefault,
                webOnlyWindowName: '_blank',
              );
              Navigator.pop(context, true);
            },
            child: const Text('Download and open Canva'),
          ),
        ],
      ),
    );
    if (approve != true || !mounted) return;
    final saved = await ProfilePdfDownload.save(bytes, _fileName);
    final opened = await (editor ?? Future<bool>.value(false));
    if (mounted && (!saved || !opened)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !opened
                ? 'Could not open Canva. Visit canva.com/pdf-editor.'
                : 'PDF download did not start. Use Download PDF below.',
          ),
        ),
      );
    }
  }

  Future<void> _replace() async {
    if (_replacing || widget.onReplacePdf == null) return;
    setState(() => _replacing = true);
    try {
      final saved = await widget.onReplacePdf!();
      if (saved && mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _replacing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final canShowPdf = _isPdf && _bytes != null;
    return Dialog(
      insetPadding: EdgeInsets.all(screen.width < 600 ? 10 : 25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 1000,
          maxHeight: screen.height * .92,
          minHeight: screen.height < 600 ? 320 : 450,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(19, 14, 8, 10),
              child: Row(
                children: [
                  Icon(
                    _category == 'nsrp_form'
                        ? Icons.assignment_outlined
                        : Icons.picture_as_pdf_outlined,
                    color: _green,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Private document preview',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          _fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF687E70),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close preview',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Container(
                color: const Color(0xFFF3F6F4),
                child: _busy
                    ? const Center(child: CircularProgressIndicator())
                    : _loadError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(25),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, size: 38),
                              const SizedBox(height: 10),
                              Text(_loadError!, textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: _load,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry loading document'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : canShowPdf
                    ? ProfilePdfView(bytes: _bytes!)
                    : _bytes != null
                    ? Image.memory(_bytes!, fit: BoxFit.contain)
                    : const Center(
                        child: Text('No document bytes were returned.'),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 9,
                children: [
                  if (_category == 'nsrp_form' && widget.onEditNsrp != null)
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onEditNsrp?.call();
                      },
                      icon: const Icon(Icons.edit_note),
                      label: const Text('Edit NSRP form'),
                    ),
                  if (widget.onReplacePdf != null && _category.startsWith('resume') && _isPdf)
                    OutlinedButton.icon(
                      onPressed: _busy || _bytes == null
                          ? null
                          : _editWithCanva,
                      icon: const Icon(Icons.design_services_outlined),
                      label: const Text('Edit in Canva'),
                    ),
                  if (_isPdf && widget.onReplacePdf == null)
                    OutlinedButton.icon(
                      onPressed: _busy || _bytes == null ? null : () async {
                        final bytes = _bytes;
                        if (bytes == null) return;
                        final opened = await ProfilePdfDownload.openForPrint(bytes);
                        if (!opened && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Use the PDF viewer print control or download the PDF to print.')));
                        }
                      },
                      icon: const Icon(Icons.print_outlined),
                      label: const Text('Print PDF'),
                    ),
                  OutlinedButton.icon(
                    onPressed: _busy || _bytes == null ? null : _download,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Download PDF'),
                  ),
                  if (widget.onReplacePdf != null) FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: _green),
                    onPressed: _replacing ? null : _replace,
                    icon: _replacing
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.upload_file_outlined),
                    label: Text(
                      _replacing ? 'Saving...' : 'Upload revised PDF',
                    ),
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
