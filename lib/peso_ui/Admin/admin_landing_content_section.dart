import 'package:flutter/material.dart';
import '../../peso_services/peso_api_client.dart';

class AdminLandingContentSection extends StatefulWidget {
  const AdminLandingContentSection({super.key, this.loadContent, this.saveContent});

  /// Injectable boundaries keep widget tests deterministic; production defaults
  /// continue to use the authenticated API client.
  final Future<Map<String, dynamic>> Function()? loadContent;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)? saveContent;
  @override
  State<AdminLandingContentSection> createState() => _AdminLandingContentSectionState();
}

class _AdminLandingContentSectionState extends State<AdminLandingContentSection> {
  List<_Item> gallery = [];
  List<_Item> partners = [];
  bool loading = true;
  bool saving = false;
  String? error;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() {
    for (final item in [...gallery, ...partners]) { item.dispose(); }
    super.dispose();
  }

  List<_Item> _decode(dynamic value, bool isGallery) => value is List
      ? value.whereType<Map>().map((row) {
          final m = Map<String, dynamic>.from(row);
          return _Item(
            (isGallery ? m['title'] : m['name'])?.toString() ?? '',
            (isGallery ? m['imageUrl'] : m['logoUrl'])?.toString() ?? '',
            (isGallery ? m['caption'] : m['websiteUrl'])?.toString() ?? '',
            m['id']?.toString() ?? '',
          );
        }).toList()
      : <_Item>[];

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final r = await (widget.loadContent ?? PesoApiClient.adminGetLandingSiteContent)();
      final g = _decode(r['gallery'], true);
      final p = _decode(r['partners'], false);
      if (!mounted) { for (final i in [...g, ...p]) { i.dispose(); } return; }
      for (final i in [...gallery, ...partners]) { i.dispose(); }
      setState(() { gallery = g; partners = p; });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally { if (mounted) setState(() => loading = false); }
  }

  _Item _newItem(String kind) => _Item('', '', '', 'new-$kind-${DateTime.now().microsecondsSinceEpoch}');

  Map<String, dynamic> _json(_Item item, bool isGallery) => isGallery
      ? {'id': item.id, 'title': item.name.text.trim(), 'imageUrl': item.url.text.trim(), 'caption': item.detail.text.trim()}
      : {'id': item.id, 'name': item.name.text.trim(), 'logoUrl': item.url.text.trim(), 'websiteUrl': item.detail.text.trim()};

  bool _valid() {
    for (final i in gallery) {
      final u = Uri.tryParse(i.url.text.trim());
      if (i.name.text.trim().isEmpty || u == null || u.scheme != 'https' || u.host.isEmpty) {
        setState(() => error = 'Each gallery photo needs a title and a valid public HTTPS image URL.');
        return false;
      }
    }
    for (final i in partners) {
      final u = Uri.tryParse(i.url.text.trim());
      final site = i.detail.text.trim();
      final w = site.isEmpty ? null : Uri.tryParse(site);
      if (i.name.text.trim().isEmpty || u == null || u.scheme != 'https' || u.host.isEmpty ||
          (site.isNotEmpty && (w == null || w.scheme != 'https' || w.host.isEmpty))) {
        setState(() => error = 'Each partner needs a name, HTTPS logo URL, and (if supplied) an HTTPS website.');
        return false;
      }
    }
    return true;
  }

  Future<void> _save({bool reset = false}) async {
    if (saving || (!reset && !_valid())) return;
    setState(() { saving = true; error = null; });
    try {
      final r = await (widget.saveContent ?? PesoApiClient.adminSaveLandingSiteContent)({
        'gallery': reset ? [] : gallery.map((i) => _json(i, true)).toList(),
        'partners': reset ? [] : partners.map((i) => _json(i, false)).toList(),
      });
      final g = _decode(r['gallery'], true);
      final p = _decode(r['partners'], false);
      if (!mounted) { for (final i in [...g, ...p]) { i.dispose(); } return; }
      for (final i in [...gallery, ...partners]) { i.dispose(); }
      setState(() { gallery = g; partners = p; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(reset ? 'Bundled content restored.' : 'Landing content saved.')));
    } catch (e) { if (mounted) setState(() => error = e.toString()); }
    finally { if (mounted) setState(() => saving = false); }
  }

  Widget _section(String title, bool isGallery) {
    final rows = isGallery ? gallery : partners;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            OutlinedButton.icon(
              key: Key(isGallery ? 'landing-gallery-add' : 'landing-partner-add'),
              onPressed: saving ? null : () => setState(() => rows.add(_newItem(isGallery ? 'photo' : 'partner'))),
              icon: const Icon(Icons.add), label: Text(isGallery ? 'Add photo' : 'Add partner'),
            ),
          ]),
          Text(isGallery
              ? 'Use a publicly accessible HTTPS photo URL and optional caption.'
              : 'Use the correct employer name and official HTTPS logo URL; website is optional.'),
          if (rows.isEmpty) Padding(
            padding: const EdgeInsets.all(12),
            child: Text(isGallery
                ? 'No custom photos: the bundled PESO gallery remains active.'
                : 'No custom list: the bundled employer logos remain active.'),
          ),
          for (var n = 0; n < rows.length; n++) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Text((isGallery ? 'Photo ' : 'Partner ') + (n + 1).toString(), style: const TextStyle(fontWeight: FontWeight.w700))),
              IconButton(
                key: Key((isGallery ? 'landing-gallery-remove-' : 'landing-partner-remove-') + n.toString()),
                tooltip: 'Remove item', onPressed: saving ? null : () => setState(() { rows.removeAt(n).dispose(); }),
                icon: const Icon(Icons.delete_outline),
              ),
            ]),
            TextField(controller: rows[n].name, maxLength: 120, decoration: InputDecoration(
              labelText: isGallery ? 'Photo title *' : 'Employer / partner name *', counterText: ''),
            ),
            TextField(controller: rows[n].url, keyboardType: TextInputType.url, decoration: InputDecoration(
              labelText: isGallery ? 'HTTPS image URL *' : 'HTTPS logo URL *', hintText: 'https://...'),
            ),
            TextField(controller: rows[n].detail, maxLength: isGallery ? 240 : 2048,
              maxLines: isGallery ? 2 : 1, keyboardType: isGallery ? TextInputType.text : TextInputType.url,
              decoration: InputDecoration(labelText: isGallery ? 'Caption (optional)' : 'Website HTTPS URL (optional)', counterText: ''),
            ),
          ],
        ]),
      ),
    );
  }

  Future<void> _reset() async {
    final yes = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Restore bundled content?'),
      content: const Text('This clears custom gallery and partner overrides and restores the bundled photos/logos on the public page.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Restore defaults')),
      ],
    ));
    if (yes == true && mounted) await _save(reset: true);
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(12),
    child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1000),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Landing Page Content', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
        const Text('Edit public gallery photos and employer logos without changing source code. Changes are stored in MongoDB. This editor accepts HTTPS URLs; it does not upload files.'),
        const SizedBox(height: 16),
        if (loading) const Center(child: CircularProgressIndicator())
        else ...[
          if (error != null) Padding(padding: const EdgeInsets.all(8), child: Text(error!, style: const TextStyle(color: Colors.red))),
          _section('Gallery photos', true),
          _section('Employer partners', false),
          Wrap(spacing: 10, runSpacing: 10, children: [
            FilledButton.icon(key: const Key('landing-content-save'), onPressed: saving ? null : () => _save(),
              icon: const Icon(Icons.save_outlined), label: Text(saving ? 'Saving...' : 'Save landing content')),
            OutlinedButton.icon(onPressed: saving ? null : _reset, icon: const Icon(Icons.restore), label: const Text('Use bundled defaults')),
            TextButton.icon(onPressed: saving ? null : _load, icon: const Icon(Icons.refresh), label: const Text('Reload saved content')),
          ]),
        ],
      ]),
    )),
  );
}

class _Item {
  _Item(String title, String urlValue, String note, this.id)
      : name = TextEditingController(text: title),
        url = TextEditingController(text: urlValue),
        detail = TextEditingController(text: note);
  final String id;
  final TextEditingController name, url, detail;
  void dispose() { name.dispose(); url.dispose(); detail.dispose(); }
}
