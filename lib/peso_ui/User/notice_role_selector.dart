import 'package:flutter/material.dart';

/// Selects existing source-linked positions; never treats an aggregate notice
/// as a job that can be scored. Results are requested for each real role ID.
class NoticeRoleSelector extends StatefulWidget {
  const NoticeRoleSelector({
    super.key,
    required this.roles,
    required this.onView,
    required this.onEvaluate,
    required this.onCompare,
  });

  final List<Map<String, dynamic>> roles;
  final ValueChanged<Map<String, dynamic>> onView;
  final ValueChanged<Map<String, dynamic>> onEvaluate;
  final ValueChanged<List<Map<String, dynamic>>>? onCompare;

  @override
  State<NoticeRoleSelector> createState() => _NoticeRoleSelectorState();
}

class _NoticeRoleSelectorState extends State<NoticeRoleSelector> {
  final Set<String> _selected = <String>{};

  @override
  void didUpdateWidget(covariant NoticeRoleSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    final allowed = widget.roles.map((x) => x['id']?.toString()).toSet();
    _selected.removeWhere((id) => !allowed.contains(id));
  }

  @override
  Widget build(BuildContext context) {
    final linked = widget.roles;
    final selected = linked
        .where((role) => _selected.contains(role['id']?.toString()))
        .toList();
    return Container(
      key: const Key('notice-role-selector'),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F8F4),
        border: Border.all(color: const Color(0xFFC5DDCE)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose a specific position',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            linked.isEmpty
                ? 'No individual job cards could be verified as belonging to this notice. Please confirm the positions with PESO. You can still forward an application for review.'
                : '${linked.length} positions are linked to this source notice. View or evaluate one position, or select 2–6 for comparison.',
            style: const TextStyle(color: Color(0xFF4B6455), height: 1.4),
          ),
          if (linked.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Role names come from the published source extraction. Requirements and current availability still need confirmation by PESO or the employer.',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B6450)),
            ),
            const SizedBox(height: 13),
            for (final role in linked)
              Padding(
                key: Key('notice-role-row-${role['id']}'),
                padding: const EdgeInsets.only(bottom: 9),
                child: LayoutBuilder(
                  builder: (context, bounds) {
                    final compact = bounds.maxWidth < 570;
                    final id = role['id']?.toString() ?? '';
                    final title = role['title']?.toString() ?? 'Named position';
                    final roleTitle = title.split(' — ').first;
                    final scope = role['requirementScope']?.toString() ?? '';
                    final review = scope != 'single_role' && scope != 'explicit_role';
                    final buttons = Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        OutlinedButton(
                          onPressed: () => widget.onView(role),
                          child: const Text('View details'),
                        ),
                        FilledButton(
                          key: Key('notice-role-evaluate-$id'),
                          onPressed: () => widget.onEvaluate(role),
                          child: const Text('Evaluate role'),
                        ),
                      ],
                    );
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.fromLTRB(7, 7, 11, 7),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Checkbox(
                            key: Key('notice-role-checkbox-$id'),
                            value: _selected.contains(id),
                            onChanged: (checked) {
                              if (id.isEmpty) return;
                              setState(() {
                                if (checked == true && _selected.length < 6) {
                                  _selected.add(id);
                                } else if (checked == false) {
                                  _selected.remove(id);
                                }
                              });
                            },
                          ),
                          Expanded(
                            child: compact
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(roleTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
                                      if (review)
                                        const Text('Role requirements require review',
                                            style: TextStyle(color: Color(0xFF8C5919), fontSize: 12)),
                                      const SizedBox(height: 4),
                                      buttons,
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(roleTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
                                            if (review)
                                              const Text('Role requirements require review',
                                                  style: TextStyle(color: Color(0xFF8C5919), fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                      buttons,
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 4),
            FilledButton.icon(
              key: const Key('notice-compare-selected'),
              onPressed: selected.length < 2 || widget.onCompare == null
                  ? null
                  : () => widget.onCompare!(selected),
              icon: const Icon(Icons.compare_arrows_outlined),
              label: Text('Compare ${selected.length} selected positions'),
            ),
          ],
        ],
      ),
    );
  }
}
