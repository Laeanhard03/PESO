import 'package:flutter/material.dart';
import '../../peso_services/peso_api_client.dart';
import '../Reusable_Designs/peso_images.dart';

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
  int? selectedPhoto;
  bool galleryConfigured = false;
  late final List<_Item> bundledPreview = _bundledGallery();

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() {
    for (final item in [...gallery, ...partners, ...bundledPreview]) { item.dispose(); }
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
      final configured = r['galleryConfigured'] == true || g.isNotEmpty;
      final p = _decode(r['partners'], false);
      if (!mounted) { for (final i in [...g, ...p]) { i.dispose(); } return; }
      for (final i in [...gallery, ...partners]) { i.dispose(); }
      setState(() { gallery = g; partners = p; galleryConfigured = configured; selectedPhoto = null; });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally { if (mounted) setState(() => loading = false); }
  }

  List<_Item> _bundledGallery() => [
    for (var i = 0; i < PesoImageAssets.gallery.length; i++)
      _Item('PESO Montalban Photo ${i + 1}', 'asset:${PesoImageAssets.gallery[i]}', '', 'bundled-$i'),
  ];

  void _startEditingGallery() {
    if (galleryConfigured) return;
    setState(() {
      gallery = _bundledGallery();
      galleryConfigured = true;
    });
  }

  Future<void> _removePhoto(int index) async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialog) => AlertDialog(
      title: const Text('Remove selected photo?'),
      content: const Text('This photo will be removed from the public gallery after you save.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Remove photo')),
      ],
    ));
    if (confirmed != true || !mounted) return;
    _startEditingGallery();
    setState(() {
      gallery.removeAt(index).dispose();
      selectedPhoto = gallery.isEmpty ? null : index.clamp(0, gallery.length - 1);
    });
  }

  Widget _thumbnail(_Item item) {
    final url = item.url.text.trim();
    if (url.startsWith('asset:')) {
      return Image.asset(url.substring(6), fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined));
    }
    if (url.startsWith('https://')) {
      return Image.network(url, fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined));
    }
    return const Icon(Icons.add_photo_alternate_outlined, size: 35);
  }

  Widget _galleryEditor() {
    final displayed = galleryConfigured ? gallery : bundledPreview;
    final selection = selectedPhoto;
    final active = selection != null && selection >= 0 && selection < displayed.length;
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Expanded(child: Text('Gallery photos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          OutlinedButton.icon(key: const Key('landing-gallery-add'),
            onPressed: saving || displayed.length >= 30 ? null : () {
              _startEditingGallery();
              setState(() { gallery.add(_newItem('photo')); selectedPhoto = gallery.length - 1; });
            }, icon: const Icon(Icons.add), label: const Text('Add photo')),
        ]),
        const SizedBox(height: 6),
        const Text('Select a photo to edit, replace its URL, or remove it. Changes appear publicly after Save landing content.'),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, bounds) {
          final count = bounds.maxWidth > 700 ? 5 : bounds.maxWidth > 420 ? 3 : 2;
          final w = (bounds.maxWidth - (count - 1) * 10) / count;
          return Wrap(spacing: 10, runSpacing: 10, children: [
            for (var n = 0; n < displayed.length; n++)
              SizedBox(width: w, child: InkWell(
                key: Key('landing-gallery-select-$n'),
                onTap: saving ? null : () { _startEditingGallery(); setState(() => selectedPhoto = n); },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: selectedPhoto == n ? Theme.of(context).colorScheme.primary : Colors.black12,
                      width: selectedPhoto == n ? 3 : 1),
                  ),
                  child: Column(children: [
                    ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      child: SizedBox(height: 95, width: double.infinity, child: _thumbnail(displayed[n]))),
                    Padding(padding: const EdgeInsets.all(5), child: Text(
                      displayed[n].name.text.isEmpty ? 'New photo' : displayed[n].name.text,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12))),
                  ]),
                ),
              )),
          ]);
        }),
        if (displayed.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('No photos selected for the public gallery. Add a photo or restore defaults.')),
        if (active) ...[
          const SizedBox(height: 18),
          const Divider(),
          Text('Edit photo ${selection + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          SizedBox(height: 180, width: double.infinity, child: _thumbnail(displayed[selection])),
          const SizedBox(height: 10),
          TextField(key: const Key('landing-gallery-title'), controller: displayed[selection].name, maxLength: 120,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Photo title *', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(key: const Key('landing-gallery-image-url'), controller: displayed[selection].url,
            keyboardType: TextInputType.url,
            onChanged: (_) { _startEditingGallery(); setState(() {}); },
            decoration: const InputDecoration(labelText: 'Replace image (public HTTPS URL)', hintText: 'https://...', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(key: const Key('landing-gallery-caption'), controller: displayed[selection].detail,
            maxLength: 240, maxLines: 2, onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Caption (optional)', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          OutlinedButton.icon(key: Key('landing-gallery-remove-$selection'),
            onPressed: saving ? null : () => _removePhoto(selection),
            icon: const Icon(Icons.delete_outline), label: const Text('Delete selected photo')),
        ],
      ],
    )));
  }

  _Item _newItem(String kind) => _Item('', '', '', 'new-$kind-${DateTime.now().microsecondsSinceEpoch}');

  Map<String, dynamic> _json(_Item item, bool isGallery) => isGallery
      ? {'id': item.id, 'title': item.name.text.trim(), 'imageUrl': item.url.text.trim(), 'caption': item.detail.text.trim()}
      : {'id': item.id, 'name': item.name.text.trim(), 'logoUrl': item.url.text.trim(), 'websiteUrl': item.detail.text.trim()};

  bool _valid() {
    for (final i in gallery) {
      final u = Uri.tryParse(i.url.text.trim());
      if (i.name.text.trim().isEmpty || !(i.url.text.startsWith('asset:lib/assets/peso_gallery') || (u != null && u.scheme == 'https' && u.host.isNotEmpty))) {
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
        'gallery': reset ? [] : (galleryConfigured ? gallery : <_Item>[]).map((i) => _json(i, true)).toList(),
        'galleryConfigured': !reset && galleryConfigured,
        'partners': reset ? [] : partners.map((i) => _json(i, false)).toList(),
      });
      final g = _decode(r['gallery'], true);
      final p = _decode(r['partners'], false);
      if (!mounted) { for (final i in [...g, ...p]) { i.dispose(); } return; }
      for (final i in [...gallery, ...partners]) { i.dispose(); }
      setState(() { gallery = g; partners = p; galleryConfigured = r['galleryConfigured'] == true || g.isNotEmpty; selectedPhoto = null; });
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
        const Text('Edit public gallery photos and employer logos without changing source code. Changes are stored in MongoDB. Choose an existing gallery photo, update its caption, replace it using a public HTTPS image URL, or delete it.'),
        const SizedBox(height: 16),
        if (loading) const Center(child: CircularProgressIndicator())
        else ...[
          if (error != null) Padding(padding: const EdgeInsets.all(8), child: Text(error!, style: const TextStyle(color: Colors.red))),
          _galleryEditor(),
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
