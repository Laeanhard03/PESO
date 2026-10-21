import 'package:flutter/material.dart';

/// Edits the saved, structured NSRP Form 1 entries (not the immutable original
/// PDF). Users may separately upload an updated PDF after editing the fields.
class NsrpEntriesEditor extends StatefulWidget {
  const NsrpEntriesEditor({
    super.key,
    required this.formData,
    required this.onSave,
  });
  final Map<String, dynamic> formData;
  final Future<void> Function(Map<String, dynamic> updatedForm) onSave;

  @override
  State<NsrpEntriesEditor> createState() => _NsrpEntriesEditorState();
}

class _NsrpEntriesEditorState extends State<NsrpEntriesEditor> {
  late final List<Map<String, dynamic>> _entries;
  late final List<TextEditingController> _controllers;
  late final List<bool> _checked;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final source = widget.formData['entries'];
    _entries = source is List
        ? source
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : <Map<String, dynamic>>[];
    _controllers = _entries
        .map((e) => TextEditingController(text: e['value']?.toString() ?? ''))
        .toList();
    _checked = _entries
        .map(
          (e) =>
              e['checked'] == true ||
              e['value']?.toString().toLowerCase() == 'selected',
        )
        .toList();
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updatedEntries = <Map<String, dynamic>>[];
      for (var i = 0; i < _entries.length; i++) {
        final entry = Map<String, dynamic>.from(_entries[i]);
        final type = entry['type']?.toString().toLowerCase() ?? '';
        if (type == 'checkbox' || type == 'radio') {
          entry['checked'] = _checked[i];
          entry['value'] = _checked[i] ? 'Selected' : '';
        } else {
          entry['value'] = _controllers[i].text.trim();
        }
        updatedEntries.add(entry);
      }
      // Store all submitted values privately, but make the optional AI summary
      // job-related only. Personal identifiers are deliberately excluded.
      final relevant = RegExp(
        r'\b(skill|training|education|school|college|university|course|'
        r'vocational|tesda|experience|employment|occupation|work history|'
        r'certification|qualification|professional|software|degree|job title)\b',
        caseSensitive: false,
      );
      final privateLabel = RegExp(
        r'\b(first name|last name|middle name|full name|birth|age|sex|gender|'
        r'civil status|religion|disability|pwd|email|phone|address|barangay|'
        r'tin|sss|gsis|philhealth|pag.?ibig|passport|household|voter|'
        r'national id|government id|tax id|umid|license number|'
        r'bank|account number|signature|form field)\b',
        caseSensitive: false,
      );
      final privateValue = RegExp(
        r'\b\d{8,}\b|[\w.+-]+@[\w.-]+\.[a-z]{2,}',
        caseSensitive: false,
      );
      final aiLines = updatedEntries
          .where((entry) {
            final label = entry['label']?.toString() ?? '';
            final value = entry['value']?.toString().trim() ?? '';
            return label.isNotEmpty &&
                value.isNotEmpty &&
                value.length <= 600 &&
                relevant.hasMatch(label) &&
                !privateLabel.hasMatch(label) &&
                !privateValue.hasMatch(value);
          })
          .map((entry) => [entry['label'], ': ', entry['value']].join());

      final updated = <String, dynamic>{
        ...widget.formData,
        'entries': updatedEntries,
        'aiText': 'NSRP FORM 1 - COMPLETED VALUES\n${aiLines.join('\n')}',
        'lastEditedAt': DateTime.now().toUtc().toIso8601String(),
      };
      await widget.onSave(updated);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Saving failed. Check your PESO connection and retry; your edits are still here.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: EdgeInsets.all(size.width < 600 ? 10 : 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 760, maxHeight: size.height * .9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 12, 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.edit_document,
                    color: Color(0xFF236349),
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Edit NSRP Form 1 details',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close without saving',
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 22),
              child: Text(
                'Update the form values saved to your PESO account. '
                'The original PDF is preserved. To change the PDF itself, '
                'upload a revised official NSRP Form 1 after saving these details.',
                style: TextStyle(color: Color(0xFF68796F), height: 1.4),
              ),
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            Flexible(
              child: _entries.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No structured NSRP values were saved. Re-submit NSRP Form 1 first.',
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _entries.length,
                      itemBuilder: (context, index) {
                        final entry = _entries[index];
                        final type =
                            entry['type']?.toString().toLowerCase() ?? '';
                        final label = entry['label']?.toString().trim();
                        final name = (label != null && label.isNotEmpty)
                            ? label
                            : 'Form field ${index + 1}';
                        final heading = '${index + 1}. $name';
                        if (type == 'checkbox' || type == 'radio') {
                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(heading, maxLines: 3),
                            value: _checked[index],
                            activeColor: const Color(0xFF236349),
                            onChanged: _saving
                                ? null
                                : (v) => setState(
                                    () => _checked[index] = v ?? false,
                                  ),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: TextFormField(
                            key: ValueKey('nsrp-field-$index'),
                            controller: _controllers[index],
                            enabled: !_saving,
                            maxLines: 1,
                            decoration: InputDecoration(
                              labelText: heading,
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _saving || _entries.isEmpty ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Saving...' : 'Save NSRP changes'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF236349),
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
