import 'package:flutter/material.dart';

import '../../peso_services/peso_api_client.dart';
import '../Reusable_Designs/peso_images.dart';

class AdminLandingContentSection extends StatefulWidget {
  const AdminLandingContentSection({
    super.key,
    this.loadContent,
    this.saveContent,
  });

  /// Injectable API boundaries keep widget tests independent of sign-in.
  final Future<Map<String, dynamic>> Function()? loadContent;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)?
  saveContent;

  @override
  State<AdminLandingContentSection> createState() =>
      _AdminLandingContentSectionState();
}

class _AdminLandingContentSectionState
    extends State<AdminLandingContentSection> {
  static const int _pageSize = 8;

  List<_Item> gallery = [];
  List<_Item> partners = [];
  late final List<_Item> _bundledGallery = [
    for (var i = 0; i < PesoImageAssets.gallery.length; i++)
      _Item(
        'PESO Montalban Photo ${i + 1}',
        'asset:${PesoImageAssets.gallery[i]}',
        '',
        'bundled-$i',
      ),
  ];
  late final List<_Item> _bundledPartners = [
    for (var i = 0; i < PesoImageAssets.partnerLogos.length; i++)
      _Item(
        PesoImageAssets.partnerLogos[i].name,
        'asset:${PesoImageAssets.partnerLogos[i].asset}',
        '',
        'bundled-partner-$i',
      ),
  ];

  bool loading = true;
  bool saving = false;
  bool galleryConfigured = false;
  bool partnersConfigured = false;
  bool showGallery = true;
  int galleryPage = 0;
  int partnerPage = 0;
  int? selectedPhoto;
  int? selectedPartner;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final item in [
      ...gallery,
      ...partners,
      ..._bundledGallery,
      ..._bundledPartners,
    ]) {
      item.dispose();
    }
    super.dispose();
  }

  List<_Item> _decode(dynamic value, bool isGallery) => value is List
      ? value.whereType<Map>().map((raw) {
          final row = Map<String, dynamic>.from(raw);
          return _Item(
            (isGallery ? row['title'] : row['name'])?.toString() ?? '',
            (isGallery ? row['imageUrl'] : row['logoUrl'])?.toString() ?? '',
            (isGallery ? row['caption'] : row['websiteUrl'])?.toString() ?? '',
            row['id']?.toString() ?? '',
          );
        }).toList()
      : <_Item>[];

  void _applyContent(Map<String, dynamic> result) {
    final newGallery = _decode(result['gallery'], true);
    final newPartners = _decode(result['partners'], false);
    if (!mounted) {
      for (final item in [...newGallery, ...newPartners]) {
        item.dispose();
      }
      return;
    }
    final previous = [...gallery, ...partners];
    setState(() {
      gallery = newGallery;
      partners = newPartners;
      galleryConfigured =
          result['galleryConfigured'] == true || newGallery.isNotEmpty;
      partnersConfigured =
          result['partnersConfigured'] == true || newPartners.isNotEmpty;
      galleryPage = 0;
      partnerPage = 0;
      selectedPhoto = null;
      selectedPartner = null;
    });
    // Allow old TextFields to detach from their controllers first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final item in previous) {
        item.dispose();
      }
    });
  }

  Future<void> _load() async {
    if (saving) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response =
          await (widget.loadContent ??
              PesoApiClient.adminGetLandingSiteContent)();
      _applyContent(response);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _activate(bool isGallery) {
    if (isGallery) {
      if (!galleryConfigured) {
        gallery = [for (final item in _bundledGallery) item.copy()];
        galleryConfigured = true;
      }
    } else if (!partnersConfigured) {
      partners = [for (final item in _bundledPartners) item.copy()];
      partnersConfigured = true;
    }
  }

  List<_Item> _visibleItems(bool isGallery) => isGallery
      ? (galleryConfigured ? gallery : _bundledGallery)
      : (partnersConfigured ? partners : _bundledPartners);

  _Item _newItem(bool isGallery) => _Item(
    '',
    '',
    '',
    'new-${isGallery ? 'photo-' : 'partner-'}${DateTime.now().microsecondsSinceEpoch}',
  );

  void _add(bool isGallery) {
    if (saving) return;
    setState(() {
      _activate(isGallery);
      final rows = isGallery ? gallery : partners;
      rows.add(_newItem(isGallery));
      final index = rows.length - 1;
      if (isGallery) {
        galleryPage = index ~/ _pageSize;
        selectedPhoto = index;
      } else {
        partnerPage = index ~/ _pageSize;
        selectedPartner = index;
      }
    });
  }

  void _select(bool isGallery, int index) {
    if (saving) return;
    setState(() {
      _activate(isGallery);
      if (isGallery) {
        selectedPhoto = index;
      } else {
        selectedPartner = index;
      }
    });
  }

  void _changePage(bool isGallery, int nextPage) {
    setState(() {
      if (isGallery) {
        galleryPage = nextPage;
        selectedPhoto = null;
      } else {
        partnerPage = nextPage;
        selectedPartner = null;
      }
    });
  }

  Future<void> _remove(bool isGallery, int index) async {
    final itemName = isGallery ? 'photo' : 'partner';
    final remove = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Remove selected $itemName?'),
        content: Text(
          'This $itemName will be removed from the public page after you save.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text('Remove $itemName'),
          ),
        ],
      ),
    );
    if (remove != true || !mounted) return;
    late final _Item removed;
    setState(() {
      _activate(isGallery);
      final rows = isGallery ? gallery : partners;
      removed = rows.removeAt(index);
      final next = rows.isEmpty ? null : index.clamp(0, rows.length - 1);
      if (isGallery) {
        selectedPhoto = next;
        galleryPage = next == null ? 0 : next ~/ _pageSize;
      } else {
        selectedPartner = next;
        partnerPage = next == null ? 0 : next ~/ _pageSize;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
  }

  bool _validImageUrl(String value, bool isGallery) {
    final raw = value.trim();
    if (raw.startsWith('asset:')) {
      final path = raw.substring(6);
      return isGallery
          ? PesoImageAssets.gallery.contains(path)
          : PesoImageAssets.partnerLogos.any((p) => p.asset == path);
    }
    final parsed = Uri.tryParse(raw);
    return parsed != null &&
        parsed.scheme == 'https' &&
        parsed.host.isNotEmpty &&
        parsed.userInfo.isEmpty;
  }

  bool _valid() {
    for (final item in gallery) {
      if (item.name.text.trim().isEmpty ||
          !_validImageUrl(item.url.text, true)) {
        setState(
          () => error =
              'Each gallery photo needs a title and a valid HTTPS image URL.',
        );
        return false;
      }
    }
    for (final item in partners) {
      final website = item.detail.text.trim();
      final parsedWebsite = Uri.tryParse(website);
      if (item.name.text.trim().isEmpty ||
          !_validImageUrl(item.url.text, false) ||
          (website.isNotEmpty &&
              (parsedWebsite == null ||
                  parsedWebsite.scheme != 'https' ||
                  parsedWebsite.host.isEmpty ||
                  parsedWebsite.userInfo.isNotEmpty))) {
        setState(
          () => error = 'Each partner needs a name, HTTPS logo URL, and a valid HTTPS website if supplied.',
        );
        return false;
      }
    }
    return true;
  }

  Map<String, dynamic> _json(_Item item, bool isGallery) => isGallery
      ? {
          'id': item.id,
          'title': item.name.text.trim(),
          'imageUrl': item.url.text.trim(),
          'caption': item.detail.text.trim(),
        }
      : {
          'id': item.id,
          'name': item.name.text.trim(),
          'logoUrl': item.url.text.trim(),
          'websiteUrl': item.detail.text.trim(),
        };

  Future<void> _save({bool reset = false}) async {
    if (saving || (!reset && !_valid())) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final result =
          await (widget.saveContent ??
              PesoApiClient.adminSaveLandingSiteContent)({
            'gallery': reset || !galleryConfigured
                ? []
                : gallery.map((item) => _json(item, true)).toList(),
            'galleryConfigured': !reset && galleryConfigured,
            'partners': reset || !partnersConfigured
                ? []
                : partners.map((item) => _json(item, false)).toList(),
            'partnersConfigured': !reset && partnersConfigured,
          });
      _applyContent(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              reset
                  ? 'Bundled photos and partner logos restored.'
                  : 'Public photos and employer logos saved.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _reset() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Restore bundled content?'),
        content: const Text(
          'This clears custom gallery and partner overrides and restores the bundled photos and logos on the public page.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Restore defaults'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) await _save(reset: true);
  }

  Widget _image(String url, {required bool isGallery, bool large = false}) {
    final fit = isGallery ? BoxFit.cover : BoxFit.contain;
    final decodeWidth = large ? 640 : 260;
    final trimmed = url.trim();
    if (trimmed.startsWith('asset:')) {
      return Image.asset(
        trimmed.substring(6),
        fit: fit,
        cacheWidth: decodeWidth,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, _, _) =>
            const Center(child: Icon(Icons.broken_image_outlined)),
      );
    }
    if (_validImageUrl(trimmed, isGallery)) {
      return Image.network(
        trimmed,
        fit: fit,
        cacheWidth: decodeWidth,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, _, _) =>
            const Center(child: Icon(Icons.broken_image_outlined)),
      );
    }
    return const Center(
      child: Icon(Icons.add_photo_alternate_outlined, size: 32),
    );
  }

  Widget _tile(bool isGallery, _Item item, int index, bool selected) {
    final keyPrefix = isGallery ? 'gallery' : 'partner';
    final borderColor = Theme.of(context).colorScheme.primary;
    return Semantics(
      button: true,
      label: 'Select ${isGallery ? 'photo' : 'partner'} ${index + 1}',
      child: InkWell(
        key: Key('landing-$keyPrefix-select-$index'),
        onTap: saving ? null : () => _select(isGallery, index),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? borderColor : Theme.of(context).dividerColor,
              width: selected ? 2.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
                child: SizedBox(
                  height: 94,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: Theme.of(context).colorScheme.surface,
                        child: _image(item.previewUrl, isGallery: isGallery),
                      ),
                      if (selected)
                        const Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.check_circle, size: 22),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(6),
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: item.name,
                  builder: (_, value, _) => Text(
                    value.text.trim().isEmpty
                        ? (isGallery ? 'New photo' : 'New partner')
                        : value.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _editor(bool isGallery) {
    final prefix = isGallery ? 'gallery' : 'partner';
    final all = _visibleItems(isGallery);
    final selected = isGallery ? selectedPhoto : selectedPartner;
    final active = selected != null && selected >= 0 && selected < all.length;
    final totalPages = (all.length / _pageSize).ceil().clamp(1, 1000);
    final current = (isGallery ? galleryPage : partnerPage).clamp(
      0,
      totalPages - 1,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    isGallery ? 'Gallery photos' : 'Employer partners',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                OutlinedButton.icon(
                  key: Key('landing-$prefix-add'),
                  onPressed: saving || all.length >= (isGallery ? 30 : 40)
                      ? null
                      : () => _add(isGallery),
                  icon: const Icon(Icons.add),
                  label: Text(isGallery ? 'Add photo' : 'Add partner'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              isGallery
                  ? 'Select a photo to edit its title, replace its image, or remove it.'
                  : 'Select an employer logo to change the image, company name, or website.',
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, bounds) {
                final columns = bounds.maxWidth >= 710
                    ? 4
                    : bounds.maxWidth >= 450
                    ? 3
                    : 2;
                const gap = 10.0;
                final tileWidth =
                    (bounds.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (
                      var index = current * _pageSize;
                      index < all.length && index < (current + 1) * _pageSize;
                      index++
                    )
                      SizedBox(
                        width: tileWidth,
                        child: _tile(
                          isGallery,
                          all[index],
                          index,
                          selected == index,
                        ),
                      ),
                  ],
                );
              },
            ),
            if (all.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  isGallery
                      ? 'No gallery photos selected. Add a photo or restore bundled defaults.'
                      : 'No employer logos selected. Add a partner or restore bundled defaults.',
                ),
              ),
            if (totalPages > 1)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      key: Key('landing-$prefix-previous'),
                      tooltip: 'Previous page',
                      onPressed: current == 0 || saving
                          ? null
                          : () => _changePage(isGallery, current - 1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text('${current + 1} / $totalPages'),
                    IconButton(
                      key: Key('landing-$prefix-next'),
                      tooltip: 'Next page',
                      onPressed: current >= totalPages - 1 || saving
                          ? null
                          : () => _changePage(isGallery, current + 1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
            if (active) ...[
              const SizedBox(height: 16),
              const Divider(),
              _selectedEditor(isGallery, selected, all[selected]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _selectedEditor(bool isGallery, int index, _Item item) {
    final prefix = isGallery ? 'gallery' : 'partner';
    return Column(
      key: ValueKey('landing-$prefix-editor-${item.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Edit ${isGallery ? 'photo' : 'partner'} ${index + 1}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 156,
          width: double.infinity,
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surface,
            child: _image(item.previewUrl, isGallery: isGallery, large: true),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: Key('landing-$prefix-name'),
          controller: item.name,
          maxLength: 120,
          decoration: InputDecoration(
            labelText: isGallery ? 'Photo title *' : 'Employer name *',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: Key('landing-$prefix-image-url'),
          controller: item.url,
          maxLines: 1,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: isGallery
                ? 'Replace image (public HTTPS URL)'
                : 'Replace logo (public HTTPS URL)',
            helperText: 'Paste an HTTPS URL to replace the existing image.',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: Key('landing-$prefix-preview'),
            onPressed: saving
                ? null
                : () => setState(() => item.previewUrl = item.url.text.trim()),
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Preview image'),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: Key(
            isGallery ? 'landing-gallery-caption' : 'landing-partner-website',
          ),
          controller: item.detail,
          maxLength: isGallery ? 240 : 2048,
          maxLines: isGallery ? 2 : 1,
          keyboardType: isGallery ? TextInputType.text : TextInputType.url,
          decoration: InputDecoration(
            labelText: isGallery
                ? 'Caption (optional)'
                : 'Website HTTPS URL (optional)',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: Key('landing-$prefix-remove-$index'),
          onPressed: saving ? null : () => _remove(isGallery, index),
          icon: const Icon(Icons.delete_outline),
          label: Text(
            isGallery ? 'Delete selected photo' : 'Delete selected partner',
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(12),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Landing Page Content',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'Manage gallery photos and employer logos. Changes are saved to the public website.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  key: const Key('landing-gallery-tab'),
                  label: const Text('Gallery photos'),
                  avatar: const Icon(Icons.photo_library_outlined, size: 17),
                  selected: showGallery,
                  onSelected: (_) => setState(() => showGallery = true),
                ),
                ChoiceChip(
                  key: const Key('landing-partner-tab'),
                  label: const Text('Employer partners'),
                  avatar: const Icon(Icons.business_outlined, size: 17),
                  selected: !showGallery,
                  onSelected: (_) => setState(() => showGallery = false),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (loading)
              const Center(child: CircularProgressIndicator())
            else ...[
              if (error != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              _editor(showGallery),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    key: const Key('landing-content-save'),
                    onPressed: saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(saving ? 'Saving...' : 'Save landing content'),
                  ),
                  OutlinedButton.icon(
                    onPressed: saving ? null : _reset,
                    icon: const Icon(Icons.restore),
                    label: const Text('Use bundled defaults'),
                  ),
                  TextButton.icon(
                    onPressed: saving ? null : _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reload saved content'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _Item {
  _Item(String title, String image, String note, this.id)
    : name = TextEditingController(text: title),
      url = TextEditingController(text: image),
      detail = TextEditingController(text: note),
      previewUrl = image;

  final String id;
  final TextEditingController name;
  final TextEditingController url;
  final TextEditingController detail;
  String previewUrl;

  _Item copy() => _Item(name.text, url.text, detail.text, id);

  void dispose() {
    name.dispose();
    url.dispose();
    detail.dispose();
  }
}
