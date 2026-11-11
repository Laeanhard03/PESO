import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../peso_services/peso_api_client.dart';

class AdminDevelopmentNotesSection extends StatefulWidget {
  const AdminDevelopmentNotesSection({super.key});
  @override
  State<AdminDevelopmentNotesSection> createState() =>
      _AdminDevelopmentNotesSectionState();
}

class _AdminDevelopmentNotesSectionState
    extends State<AdminDevelopmentNotesSection> {
  static const green = Color(0xFF236349);
  static const ink = Color(0xFF193D31);
  static const muted = Color(0xFF64748B);
  final search = TextEditingController();
  List<Map<String, dynamic>> notes = [];
  bool loading = true, busy = false;
  String? error, selectedId;
  String kind = 'all', status = 'active';
  Timer? _refreshTimer;

  String str(Object? value) => value?.toString() ?? '';
  int revision(Map<String, dynamic> note) =>
      (note['revision'] as num?)?.toInt() ?? 1;
  DateTime date(Object? value) =>
      DateTime.tryParse(str(value)) ?? DateTime(1970);
  List<Map<String, dynamic>> maps(Object? value) => value is List
      ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : [];

  @override
  void initState() {
    super.initState();
    load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted && !busy && !loading && search.text.trim().isEmpty) {
        load(spinner: false);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    search.dispose();
    super.dispose();
  }

  Future<void> load({bool spinner = true}) async {
    if (spinner && mounted) setState(() => loading = true);
    try {
      final result = await PesoApiClient.adminListDevelopmentNotes(
        query: search.text.trim(),
        kind: kind,
        status: status,
      );
      if (!mounted) return;
      setState(() {
        notes = maps(result['notes']);
        loading = false;
        error = null;
        if (selectedId != null &&
            !notes.any((n) => str(n['id']) == selectedId)) {
          selectedId = null;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = e.toString();
        });
      }
    }
  }

  void upsert(Map<String, dynamic> note) {
    final index = notes.indexWhere((n) => str(n['id']) == str(note['id']));
    if (index < 0) {
      notes.insert(0, note);
    } else {
      notes[index] = note;
    }
    notes.sort((a, b) => date(b['updatedAt']).compareTo(date(a['updatedAt'])));
  }

  void message(String value, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value),
        backgroundColor: isError ? const Color(0xFFB91C1C) : ink,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> mutate(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      if (mounted) setState(() => busy = false);
    } catch (e) {
      if (mounted) {
        setState(() => busy = false);
        message(e.toString(), isError: true);
        await load(spinner: false);
      }
    }
  }

  Future<void> createNote() async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _DevelopmentNoteEditor(),
    );
    if (data == null || !mounted) return;
    await mutate(() async {
      final result = await PesoApiClient.adminCreateDevelopmentNote(data);
      final note = Map<String, dynamic>.from(result['note'] as Map);
      upsert(note);
      selectedId = str(note['id']);
      message('Development item created.');
    });
  }

  Future<void> editNote(Map<String, dynamic> note) async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _DevelopmentNoteEditor(note: note),
    );
    if (data == null || !mounted) return;
    await mutate(() async {
      final result = await PesoApiClient.adminUpdateDevelopmentNote(
        str(note['id']),
        data,
        expectedRevision: revision(note),
      );
      upsert(Map<String, dynamic>.from(result['note'] as Map));
    });
  }

  Future<void> addChecklist(Map<String, dynamic> note) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add checklist item'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 300,
          decoration: const InputDecoration(
            hintText: 'e.g. Reproduce issue on mobile',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return;
    await mutate(() async {
      final result = await PesoApiClient.adminAddDevelopmentChecklistItem(
        str(note['id']),
        value,
        expectedRevision: revision(note),
      );
      upsert(Map<String, dynamic>.from(result['note'] as Map));
    });
  }

  Future<void> toggleChecklist(
    Map<String, dynamic> note,
    Map<String, dynamic> item,
    bool value,
  ) async {
    await mutate(() async {
      final result = await PesoApiClient.adminSetDevelopmentChecklistItem(
        str(note['id']),
        str(item['id']),
        completed: value,
        expectedRevision: revision(note),
      );
      upsert(Map<String, dynamic>.from(result['note'] as Map));
    });
  }

  Future<void> removeChecklist(
    Map<String, dynamic> note,
    Map<String, dynamic> item,
  ) async {
    await mutate(() async {
      final result = await PesoApiClient.adminRemoveDevelopmentChecklistItem(
        str(note['id']),
        str(item['id']),
        expectedRevision: revision(note),
      );
      upsert(Map<String, dynamic>.from(result['note'] as Map));
    });
  }

  Future<void> addComment(Map<String, dynamic> note) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Team comment'),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 5,
          maxLength: 3000,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Post'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return;
    await mutate(() async {
      final result = await PesoApiClient.adminCommentDevelopmentNote(
        str(note['id']),
        value,
      );
      upsert(Map<String, dynamic>.from(result['note'] as Map));
    });
  }

  String mime(String name) => switch (name.toLowerCase().split('.').last) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    _ => 'image/png',
  };

  Future<void> attachImages(Map<String, dynamic> note) async {
    final remaining = 10 - maps(note['attachments']).length;
    if (remaining <= 0) {
      message('Maximum of 10 screenshots reached.', isError: true);
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return;
    final files = result.files.take(remaining).toList();
    if (files.any((f) => f.bytes == null || f.size > 5 * 1024 * 1024)) {
      message('Each screenshot must be 5 MB or smaller.', isError: true);
      return;
    }
    await mutate(() async {
      var latest = note;
      for (final file in files) {
        final response = await PesoApiClient.adminAttachDevelopmentNoteImage(
          str(note['id']),
          fileName: file.name,
          mimeType: mime(file.name),
          base64: base64Encode(file.bytes!),
          expectedRevision: revision(latest),
        );
        latest = Map<String, dynamic>.from(response['note'] as Map);
        upsert(latest);
      }
      message('Screenshot upload complete.');
    });
  }

  Future<void> viewImage(
    Map<String, dynamic> note,
    Map<String, dynamic> attachment,
  ) async {
    try {
      final bytes = await PesoApiClient.adminReadDevelopmentNoteImage(
        str(note['id']),
        str(attachment['id']),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              InteractiveViewer(
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: IconButton.filled(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      message(e.toString(), isError: true);
    }
  }

  Future<void> removeImage(
    Map<String, dynamic> note,
    Map<String, dynamic> attachment,
  ) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove screenshot?'),
        content: Text('Remove ' + str(attachment['fileName']) + '?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await mutate(() async {
      final result = await PesoApiClient.adminRemoveDevelopmentNoteImage(
        str(note['id']),
        str(attachment['id']),
        expectedRevision: revision(note),
      );
      upsert(Map<String, dynamic>.from(result['note'] as Map));
    });
  }

  Future<void> archive(Map<String, dynamic> note, bool value) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(value ? 'Archive item?' : 'Restore item?'),
        content: Text(
          value
              ? 'This hides the item from the active list. You can restore it later.'
              : 'This returns the item to the active list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(value ? 'Archive' : 'Restore'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await mutate(() async {
      await PesoApiClient.adminUpdateDevelopmentNote(str(note['id']), {
        'archived': value,
      }, expectedRevision: revision(note));
      selectedId = null;
      await load(spinner: false);
    });
  }

  Color statusColor(String value) => switch (value) {
    'fixed' || 'implemented' => const Color(0xFF047857),
    'in_progress' => const Color(0xFF2563EB),
    'blocked' => const Color(0xFFB45309),
    _ => const Color(0xFF64748B),
  };
  Color priorityColor(String value) => switch (value) {
    'critical' => const Color(0xFFBE123C),
    'high' => const Color(0xFFEA580C),
    'medium' => const Color(0xFFB45309),
    _ => const Color(0xFF64748B),
  };
  String statusLabel(String value) => switch (value) {
    'in_progress' => 'In progress',
    'fixed' => 'Fixed',
    'implemented' => 'Implemented',
    'blocked' => 'Blocked',
    _ => 'Open',
  };

  Widget pill(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800),
    ),
  );

  Widget metric(String label, int count, Color color) => Container(
    constraints: const BoxConstraints(minWidth: 105),
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE2E8F0)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: muted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final matches = notes.where((n) => str(n['id']) == selectedId);
    final selected = matches.isEmpty ? null : matches.first;
    final done = notes
        .where((n) => n['status'] == 'fixed' || n['status'] == 'implemented')
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5F2EB),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.checklist_rounded,
                    color: green,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Development Notepad',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: ink,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Shared bugs, improvements, and implementation tracking.',
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: busy ? null : load,
                    icon: const Icon(Icons.refresh),
                  ),
                  FilledButton.icon(
                    onPressed: busy ? null : createNote,
                    icon: const Icon(Icons.add),
                    label: const Text('New item'),
                    style: FilledButton.styleFrom(backgroundColor: green),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            metric('Total', notes.length, green),
            metric(
              'Open',
              notes.where((n) => n['status'] == 'open').length,
              muted,
            ),
            metric(
              'In progress',
              notes.where((n) => n['status'] == 'in_progress').length,
              const Color(0xFF2563EB),
            ),
            metric('Completed', done, const Color(0xFF047857)),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 850;
              if (narrow && selected != null) {
                return detailPanel(selected, full: true);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: narrow || selected == null
                        ? constraints.maxWidth
                        : 360,
                    child: listPanel(),
                  ),
                  if (!narrow && selected != null) ...[
                    const SizedBox(width: 12),
                    Expanded(child: detailPanel(selected)),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget listPanel() => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE2E8F0)),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        TextField(
          controller: search,
          onSubmitted: (_) => load(),
          decoration: InputDecoration(
            hintText: 'Search title, details, assignee, tags...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              onPressed: load,
              icon: const Icon(Icons.arrow_forward),
            ),
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(11)),
          ),
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: kind,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All types')),
                  DropdownMenuItem(value: 'bug', child: Text('Bugs')),
                  DropdownMenuItem(
                    value: 'improvement',
                    child: Text('Improvements'),
                  ),
                  DropdownMenuItem(value: 'task', child: Text('Tasks')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() => kind = v);
                    load();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: status,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'all', child: Text('All statuses')),
                  DropdownMenuItem(value: 'open', child: Text('Open')),
                  DropdownMenuItem(
                    value: 'in_progress',
                    child: Text('In progress'),
                  ),
                  DropdownMenuItem(value: 'blocked', child: Text('Blocked')),
                  DropdownMenuItem(value: 'fixed', child: Text('Fixed')),
                  DropdownMenuItem(
                    value: 'implemented',
                    child: Text('Implemented'),
                  ),
                  DropdownMenuItem(value: 'archived', child: Text('Archived')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      status = v;
                      selectedId = null;
                    });
                    load();
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_outlined, size: 32),
                      Text(error!, textAlign: TextAlign.center),
                      TextButton(onPressed: load, child: const Text('Retry')),
                    ],
                  ),
                )
              : notes.isEmpty
              ? const Center(
                  child: Text(
                    'No development notes yet. Add the first bug or improvement.',
                  ),
                )
              : ListView.separated(
                  itemCount: notes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 7),
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    final checklist = maps(note['checklist']);
                    final completed = checklist
                        .where((i) => i['completed'] == true)
                        .length;
                    final attachments = maps(note['attachments']);
                    final state = str(note['status']);
                    return Material(
                      color: str(note['id']) == selectedId
                          ? const Color(0xFFEAF4EE)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () =>
                            setState(() => selectedId = str(note['id'])),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      str(note['title']),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  pill(statusLabel(state), statusColor(state)),
                                ],
                              ),
                              const SizedBox(height: 7),
                              Row(
                                children: [
                                  Text(
                                    str(note['kind']).toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: muted,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  pill(
                                    str(note['priority']).toUpperCase(),
                                    priorityColor(str(note['priority'])),
                                  ),
                                ],
                              ),
                              if (checklist.isNotEmpty) ...[
                                const SizedBox(height: 9),
                                LinearProgressIndicator(
                                  value: completed / checklist.length,
                                  minHeight: 5,
                                  color: green,
                                  backgroundColor: const Color(0xFFE2E8F0),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$completed of ' +
                                      checklist.length.toString() +
                                      ' checklist items completed',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: muted,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 7),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.person_outline,
                                    size: 13,
                                    color: muted,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      str(note['assignee']).isEmpty
                                          ? 'Unassigned'
                                          : str(note['assignee']),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: muted,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (attachments.isNotEmpty)
                                    const Icon(
                                      Icons.attach_file,
                                      size: 14,
                                      color: muted,
                                    ),
                                  Text(
                                    attachments.length.toString(),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: muted,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    ),
  );

  Widget detailPanel(Map<String, dynamic> note, {bool full = false}) {
    final checklist = maps(note['checklist']);
    final attachments = maps(note['attachments']);
    final comments = maps(note['comments']);
    final activity = maps(note['activity']).reversed.toList();
    final completed = checklist.where((i) => i['completed'] == true).length;
    final state = str(note['status']);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (full)
                  IconButton(
                    onPressed: () => setState(() => selectedId = null),
                    icon: const Icon(Icons.arrow_back),
                  ),
                const Expanded(
                  child: Text(
                    'Development item',
                    style: TextStyle(
                      fontSize: 13,
                      color: muted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Edit item',
                  onPressed: busy ? null : () => editNote(note),
                  icon: const Icon(Icons.edit_outlined),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) => archive(note, v == 'archive'),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: note['archived'] == true ? 'restore' : 'archive',
                      child: Text(
                        note['archived'] == true ? 'Restore' : 'Archive',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Text(
              str(note['title']),
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: ink,
              ),
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                pill(statusLabel(state), statusColor(state)),
                pill(str(note['kind']).toUpperCase(), green),
                pill(
                  str(note['priority']).toUpperCase(),
                  priorityColor(str(note['priority'])),
                ),
              ],
            ),
            if (str(note['description']).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 13),
                child: Text(
                  str(note['description']),
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Assigned to: ' +
                  (str(note['assignee']).isEmpty
                      ? 'Unassigned'
                      : str(note['assignee'])),
              style: const TextStyle(fontSize: 12, color: muted),
            ),
            if (note['tags'] is List)
              Wrap(
                spacing: 5,
                children: [
                  for (final tag in note['tags'] as List)
                    pill('#' + tag.toString(), muted),
                ],
              ),
            const Divider(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Checklist',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: ink,
                    ),
                  ),
                ),
                Text(
                  '$completed/' + checklist.length.toString(),
                  style: const TextStyle(
                    color: muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  tooltip: 'Add checklist item',
                  onPressed: busy ? null : () => addChecklist(note),
                  icon: const Icon(Icons.add_circle_outline, color: green),
                ),
              ],
            ),
            if (checklist.isEmpty)
              const Text(
                'Add the steps needed to resolve or implement this item.',
                style: TextStyle(color: muted, fontSize: 12),
              )
            else
              ...checklist.map(
                (item) => CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: item['completed'] == true,
                  onChanged: busy
                      ? null
                      : (v) => toggleChecklist(note, item, v ?? false),
                  title: Text(
                    str(item['text']),
                    style: TextStyle(
                      fontSize: 12,
                      decoration: item['completed'] == true
                          ? TextDecoration.lineThrough
                          : null,
                      color: item['completed'] == true ? muted : ink,
                    ),
                  ),
                  subtitle: item['completedBy'] is Map
                      ? Text(
                          'Completed by ' +
                              str((item['completedBy'] as Map)['name']),
                          style: const TextStyle(fontSize: 10),
                        )
                      : null,
                  secondary: IconButton(
                    tooltip: 'Remove item',
                    onPressed: busy ? null : () => removeChecklist(note, item),
                    icon: const Icon(Icons.close, size: 17),
                  ),
                ),
              ),
            if (checklist.isNotEmpty && completed == checklist.length)
              pill(
                state == 'fixed'
                    ? 'All checks complete • Bug fixed'
                    : state == 'implemented'
                    ? 'All checks complete • Implemented'
                    : 'All checks complete',
                const Color(0xFF047857),
              ),
            const Divider(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Screenshots & attachments',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: ink,
                    ),
                  ),
                ),
                Text(
                  attachments.length.toString() + '/10',
                  style: const TextStyle(fontSize: 11, color: muted),
                ),
                IconButton(
                  tooltip: 'Attach screenshot',
                  onPressed: busy ? null : () => attachImages(note),
                  icon: const Icon(
                    Icons.add_photo_alternate_outlined,
                    color: green,
                  ),
                ),
              ],
            ),
            if (attachments.isEmpty)
              const Text(
                'No screenshots attached yet.',
                style: TextStyle(fontSize: 12, color: muted),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: attachments
                    .map(
                      (a) => InkWell(
                        onTap: () => viewImage(note, a),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 116,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.image_outlined,
                                color: green,
                                size: 28,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                str(a['fileName']),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 10),
                              ),
                              const Text(
                                'View image',
                                style: TextStyle(
                                  color: green,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Remove screenshot',
                                onPressed: busy
                                    ? null
                                    : () => removeImage(note, a),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            const Divider(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Team discussion',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: ink,
                    ),
                  ),
                ),
                Text(
                  comments.length.toString() + ' comments',
                  style: const TextStyle(fontSize: 11, color: muted),
                ),
                IconButton(
                  tooltip: 'Add comment',
                  onPressed: busy ? null : () => addComment(note),
                  icon: const Icon(Icons.add_comment_outlined, color: green),
                ),
              ],
            ),
            if (comments.isEmpty)
              const Text(
                'No comments yet. Add findings or progress updates.',
                style: TextStyle(fontSize: 12, color: muted),
              )
            else
              ...comments.reversed.map(
                (comment) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const CircleAvatar(
                    radius: 15,
                    child: Icon(Icons.person_outline, size: 16),
                  ),
                  title: Text(
                    str((comment['actor'] as Map?)?['name']),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(
                    str(comment['message']),
                    style: const TextStyle(fontSize: 12, height: 1.4),
                  ),
                ),
              ),
            const Divider(height: 24),
            const Text(
              'Activity history',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: ink,
              ),
            ),
            if (activity.isEmpty)
              const Text(
                'No activity recorded.',
                style: TextStyle(color: muted, fontSize: 12),
              )
            else
              ...activity
                  .take(12)
                  .map(
                    (event) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(
                        Icons.history,
                        size: 16,
                        color: muted,
                      ),
                      title: Text(
                        str(event['message']),
                        style: const TextStyle(fontSize: 11),
                      ),
                      subtitle: Text(
                        str((event['actor'] as Map?)?['name']) +
                            ' • ' +
                            date(event['at']).toLocal().toString(),
                        style: const TextStyle(fontSize: 10, color: muted),
                      ),
                    ),
                  ),
            if (busy) const LinearProgressIndicator(minHeight: 2),
          ],
        ),
      ),
    );
  }
}

class _DevelopmentNoteEditor extends StatefulWidget {
  const _DevelopmentNoteEditor({this.note});
  final Map<String, dynamic>? note;
  @override
  State<_DevelopmentNoteEditor> createState() => _DevelopmentNoteEditorState();
}

class _DevelopmentNoteEditorState extends State<_DevelopmentNoteEditor> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController title,
      description,
      assignee,
      tags,
      checklist;
  late String kind, priority, status;

  @override
  void initState() {
    super.initState();
    final note = widget.note ?? {};
    title = TextEditingController(text: note['title']?.toString() ?? '');
    description = TextEditingController(
      text: note['description']?.toString() ?? '',
    );
    assignee = TextEditingController(text: note['assignee']?.toString() ?? '');
    tags = TextEditingController(
      text: note['tags'] is List ? (note['tags'] as List).join(', ') : '',
    );
    checklist = TextEditingController();
    kind = note['kind']?.toString() ?? 'bug';
    priority = note['priority']?.toString() ?? 'medium';
    status = note['status']?.toString() ?? 'open';
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    assignee.dispose();
    tags.dispose();
    checklist.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.note != null;
    return AlertDialog(
      title: Text(editing ? 'Edit development item' : 'New development item'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: title,
                  autofocus: true,
                  maxLength: 140,
                  decoration: const InputDecoration(
                    labelText: 'Title *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'A title is required.'
                      : null,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: kind,
                  decoration: const InputDecoration(labelText: 'Item type'),
                  items: const [
                    DropdownMenuItem(value: 'bug', child: Text('Bug report')),
                    DropdownMenuItem(
                      value: 'improvement',
                      child: Text('Improvement'),
                    ),
                    DropdownMenuItem(
                      value: 'task',
                      child: Text('Development task'),
                    ),
                  ],
                  onChanged: (v) => setState(() => kind = v ?? 'bug'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                    DropdownMenuItem(
                      value: 'critical',
                      child: Text('Critical'),
                    ),
                  ],
                  onChanged: (v) => setState(() => priority = v ?? 'medium'),
                ),
                if (editing)
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: 'open', child: Text('Open')),
                      DropdownMenuItem(
                        value: 'in_progress',
                        child: Text('In progress'),
                      ),
                      DropdownMenuItem(
                        value: 'blocked',
                        child: Text('Blocked'),
                      ),
                      DropdownMenuItem(value: 'fixed', child: Text('Fixed')),
                      DropdownMenuItem(
                        value: 'implemented',
                        child: Text('Implemented'),
                      ),
                    ],
                    onChanged: (v) => setState(() => status = v ?? 'open'),
                  ),
                TextFormField(
                  controller: description,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 10000,
                  decoration: const InputDecoration(
                    labelText: 'Description / reproduction steps',
                    border: OutlineInputBorder(),
                  ),
                ),
                TextFormField(
                  controller: assignee,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Assigned programmer',
                  ),
                ),
                TextFormField(
                  controller: tags,
                  decoration: const InputDecoration(
                    labelText: 'Tags (comma separated)',
                  ),
                ),
                if (!editing)
                  TextFormField(
                    controller: checklist,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Initial checklist (one item per line)',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!formKey.currentState!.validate()) return;
            final result = <String, dynamic>{
              'title': title.text.trim(),
              'description': description.text.trim(),
              'kind': kind,
              'priority': priority,
              'assignee': assignee.text.trim(),
              'tags': tags.text
                  .split(',')
                  .map((v) => v.trim())
                  .where((v) => v.isNotEmpty)
                  .toList(),
            };
            if (editing) {
              result['status'] = status;
            } else {
              result['checklist'] = checklist.text
                  .split('\n')
                  .map((v) => v.trim())
                  .where((v) => v.isNotEmpty)
                  .toList();
            }
            Navigator.pop(context, result);
          },
          child: Text(editing ? 'Save changes' : 'Create item'),
        ),
      ],
    );
  }
}
