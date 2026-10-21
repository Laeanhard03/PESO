import 'package:flutter/material.dart';

import 'user_job_feed_tab.dart'; // Imports FadeSlideEntrance
import 'profile_document_dialog.dart';
import 'nsrp_entries_editor.dart';
import '../Reusable_Designs/peso_premium_ui.dart';

class UserAiProfileTab extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController titleController;
  final TextEditingController bioController;
  final List<String> userSkills;
  final Map<String, dynamic> aiProfileData;
  final bool aiExtractionUnavailable;
  final bool sourcesSaved;
  final bool retryingAi;
  final Future<void> Function()? onRetryAi;
  final Map<String, dynamic> resumeData;
  final Map<String, dynamic> pesoFormData;
  final List<Map<String, dynamic>> artifacts;
  final Future<bool> Function(String category)? onReplacePdf;
  final Future<void> Function(Map<String, dynamic>)? onSaveNsrp;
  final VoidCallback? onRebuildNsrp;
  final String Function(String) translate;
  final Future<void> Function()? onSavePersonalDetails;
  final VoidCallback? onEditQualifications;
  final Color primary;
  final Color textDark;
  final Color textLight;

  const UserAiProfileTab({
    super.key,
    required this.nameController,
    required this.titleController,
    required this.bioController,
    required this.userSkills,
    required this.aiProfileData,
    this.aiExtractionUnavailable = false,
    this.sourcesSaved = true,
    this.retryingAi = false,
    this.onRetryAi,
    required this.resumeData,
    required this.pesoFormData,
    required this.artifacts,
    this.onReplacePdf,
    this.onSaveNsrp,
    this.onRebuildNsrp,
    required this.translate,
    this.onSavePersonalDetails,
    this.onEditQualifications,
    required this.primary,
    required this.textDark,
    required this.textLight,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < 600;
    final medium = screenWidth < 1024;
    final personalAnchor = GlobalKey();
    final documentsAnchor = GlobalKey();
    final backgroundAnchor = GlobalKey();
    final formAnchor = GlobalKey();
    final resumeAnchor = GlobalKey();
    Widget jumpChip(String label, IconData icon, GlobalKey anchor) =>
        ActionChip(
          avatar: Icon(icon, color: primary, size: 17),
          label: Text(label),
          onPressed: () {
            final target = anchor.currentContext;
            if (target == null) return;
            Scrollable.ensureVisible(
              target,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              alignment: 0.05,
            );
          },
        );
    return SingleChildScrollView(
      padding: EdgeInsets.all(compact ? 16 : (medium ? 24 : 50)),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeSlideEntrance(
                delay: 0,
                child: PesoPageHeader(
                  title: translate(
                    aiExtractionUnavailable
                        ? 'Saved Profile & Forms'
                        : 'AI Extracted Profile',
                  ),
                  description: translate(
                    aiExtractionUnavailable
                        ? 'Review your submitted resume and saved NSRP Form 1. AI extraction can be retried.'
                        : 'Review your AI-extracted background, submitted resume, and saved NSRP Form 1 details below.',
                  ),
                  eyebrow: 'A clearer picture of your strengths',
                  icon: Icons.auto_awesome_rounded,
                  detail: Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    children: [
                      PesoHeaderPill(
                        icon: Icons.stars_outlined,
                        label: aiExtractionUnavailable
                            ? 'AI extraction pending'
                            : '${userSkills.length} extracted skills',
                      ),
                      PesoHeaderPill(
                        icon: Icons.folder_copy_outlined,
                        label: '${artifacts.length} saved documents',
                      ),
                    ],
                  ),
                ),
              ),
              if (aiExtractionUnavailable) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sourcesSaved
                              ? 'Your source forms are saved. AI extraction and matching are unavailable or pending.'
                              : 'Your source forms are available here but saving failed. Please save them again when connected.',
                        ),
                        const SizedBox(height: 8),
                        if (onRetryAi != null)
                          TextButton.icon(
                            onPressed: retryingAi ? null : onRetryAi,
                            icon: const Icon(Icons.refresh),
                            label: Text(
                              retryingAi
                                  ? 'Retrying AI extraction...'
                                  : 'Retry AI extraction',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 5,
                children: [
                  jumpChip('My details', Icons.person_outline, personalAnchor),
                  jumpChip(
                    'Saved documents',
                    Icons.folder_open_outlined,
                    documentsAnchor,
                  ),
                  if (_hasAiBackground)
                    jumpChip(
                      'AI background',
                      Icons.auto_awesome_outlined,
                      backgroundAnchor,
                    ),
                  if (_formEntries.isNotEmpty)
                    jumpChip(
                      'NSRP entries',
                      Icons.assignment_outlined,
                      formAnchor,
                    ),
                  if (_resumeFields.isNotEmpty)
                    jumpChip(
                      'Resume content',
                      Icons.description_outlined,
                      resumeAnchor,
                    ),
                ],
              ),
              const SizedBox(height: 20),
              FadeSlideEntrance(
                delay: 300,
                child: Container(
                  key: personalAnchor,
                  child: SectionWrapper(
                    title: 'Personal Context',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final narrow = constraints.maxWidth < 600;
                            final fields = [
                              _buildDesignerTextField(
                                'Full Name',
                                'Name from Resume',
                                controller: nameController,
                              ),
                              _buildDesignerTextField(
                                'Professional Title',
                                'Title from Resume',
                                icon: Icons.badge_outlined,
                                controller: titleController,
                              ),
                            ];
                            return narrow
                                ? Column(
                                    children: [
                                      fields[0],
                                      const SizedBox(height: 16),
                                      fields[1],
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Expanded(child: fields[0]),
                                      const SizedBox(width: 24),
                                      Expanded(child: fields[1]),
                                    ],
                                  );
                          },
                        ),
                        const SizedBox(height: 30),
                        Text(
                          aiExtractionUnavailable
                              ? 'Biography (not AI generated)'
                              : 'AI Generated Bilingual Bio',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: bioController,
                          maxLines: 5,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.all(25),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: primary, width: 2),
                            ),
                          ),
                        ),
                        if (onSavePersonalDetails != null)
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              key: const Key('save-ai-profile-edits'),
                              onPressed: onSavePersonalDetails,
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('Save my profile changes'),
                            ),
                          ),
                        const SizedBox(height: 24),
                        Text(
                          aiExtractionUnavailable
                              ? 'Skills pending AI extraction'
                              : 'AI Extracted Skills',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'AI-extracted qualifications must be verified from your submitted sources.',
                          style: TextStyle(color: textLight, fontSize: 12),
                        ),
                        if (onEditQualifications != null)
                          TextButton.icon(
                            onPressed: onEditQualifications,
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit my source qualifications'),
                          ),
                        const SizedBox(height: 15),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: userSkills.isNotEmpty
                              ? userSkills
                                    .map((skill) => _buildSkillChip(skill))
                                    .toList()
                              : [_buildSkillChip('No skills extracted')],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                key: documentsAnchor,
                child: _buildDocumentsSection(context),
              ),
              if (_hasAiBackground)
                Container(
                  key: backgroundAnchor,
                  child: _buildAiBackgroundSection(),
                ),
              if (_formEntries.isNotEmpty)
                Container(
                  key: formAnchor,
                  child: _buildNsrpDetailsSection(context),
                ),
              if (_resumeFields.isNotEmpty ||
                  (resumeData['plainText']?.toString().trim().isNotEmpty ??
                      false))
                Container(
                  key: resumeAnchor,
                  child: _buildResumeDetailsSection(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _hasAiBackground =>
      !aiExtractionUnavailable &&
      (_stringList('education').isNotEmpty ||
          _stringList('employmentHistory').isNotEmpty ||
          _stringList('certifications').isNotEmpty ||
          (aiProfileData['yearsExperience'] is num &&
              (aiProfileData['yearsExperience'] as num) > 0));

  List<String> _stringList(String key) {
    final raw = aiProfileData[key];
    if (raw is! List) return <String>[];
    return raw
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }

  Widget _buildAiBackgroundSection() {
    final years = aiProfileData['yearsExperience'];
    return SectionWrapper(
      title: 'AI Extracted Background',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (years is num && years > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Estimated experience: ${years.toInt()} year${years == 1 ? '' : 's'}',
                style: TextStyle(color: textDark, fontWeight: FontWeight.w800),
              ),
            ),
          _buildExtractedList(
            'Education',
            _stringList('education'),
            Icons.school_outlined,
          ),
          _buildExtractedList(
            'Employment history',
            _stringList('employmentHistory'),
            Icons.work_outline,
          ),
          _buildExtractedList(
            'Certifications',
            _stringList('certifications'),
            Icons.workspace_premium_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildExtractedList(String title, List<String> values, IconData icon) {
    if (values.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(color: textDark, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...values.map(
            (value) => Padding(
              padding: const EdgeInsets.only(left: 28, bottom: 8),
              child: Text(
                value,
                style: TextStyle(color: textLight, height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _hasResumeSource {
    final fileName = resumeData['fileName']?.toString().trim() ?? '';
    final plainText = resumeData['plainText']?.toString().trim() ?? '';
    final fields = resumeData['fields'];
    return fileName.isNotEmpty ||
        plainText.isNotEmpty ||
        (fields is List && fields.isNotEmpty);
  }

  bool get _hasNsrpSource =>
      (pesoFormData['documentType']?.toString().isNotEmpty ?? false) ||
      _formEntries.isNotEmpty;

  bool get _hasSubmittedResumeOrForm => _hasResumeSource || _hasNsrpSource;

  List<Map<String, dynamic>> get _formEntries {
    final raw = pesoFormData['entries'];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .where(
          (value) => (value['value']?.toString().trim().isNotEmpty ?? false),
        )
        .toList();
  }

  List<Map<String, dynamic>> get _resumeFields {
    final raw = resumeData['fields'];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .where(
          (value) => (value['value']?.toString().trim().isNotEmpty ?? false),
        )
        .toList();
  }

  Widget _buildDocumentsSection(BuildContext context) {
    return SectionWrapper(
      title: 'Saved Resumes & Forms',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your submitted documents and form details are associated with your account. Original files are stored privately through the PESO API in MongoDB GridFS when the backend is configured.',
            style: TextStyle(color: textLight, height: 1.45),
          ),
          const SizedBox(height: 16),
          if (artifacts.isEmpty && _hasSubmittedResumeOrForm)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_hasResumeSource)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.picture_as_pdf_outlined,
                        color: primary,
                      ),
                      title: const Text(
                        'Resume submitted',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        resumeData['fileName']?.toString().isNotEmpty == true
                            ? resumeData['fileName'].toString()
                            : 'Resume Builder fields are saved to your profile',
                      ),
                    ),
                  if (_hasNsrpSource)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.assignment_outlined, color: primary),
                      title: const Text(
                        'NSRP Form 1 submitted',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${_formEntries.length} form entries saved to your profile',
                      ),
                    ),
                  const SizedBox(height: 6),
                  const Text(
                    'The structured details were saved, but the original PDF is not available to open yet. Check the PESO API and MongoDB GridFS configuration, then upload or submit the document again.',
                  ),
                ],
              ),
            )
          else if (artifacts.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Text(
                'No saved document files yet. Complete onboarding with a resume and the NSRP form to add them here.',
              ),
            )
          else
            ...artifacts.map((artifact) {
              final category = artifact['category']?.toString() ?? '';
              final title = switch (category) {
                'resume_upload' => 'Uploaded Resume',
                'resume_builder' => 'Resume Builder PDF',
                'nsrp_form' => 'NSRP Form 1 PDF',
                _ => 'Profile Document',
              };
              final sizeBytes = artifact['sizeBytes'] is num
                  ? (artifact['sizeBytes'] as num).toInt()
                  : 0;
              final fileName = artifact['fileName']?.toString() ?? 'Document';
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  leading: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      category == 'nsrp_form'
                          ? Icons.assignment_outlined
                          : Icons.picture_as_pdf_outlined,
                      color: primary,
                    ),
                  ),
                  title: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '$fileName${sizeBytes > 0 ? ' · ${_formatSize(sizeBytes)}' : ''}',
                  ),
                  trailing: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 0,
                    children: [
                      if (category == 'nsrp_form' && onRebuildNsrp != null)
                        IconButton(
                          tooltip: 'Edit full NSRP Form 1 and regenerate PDF',
                          icon: Icon(
                            Icons.description_outlined,
                            color: primary,
                          ),
                          onPressed: onRebuildNsrp,
                        ),
                      if (category == 'nsrp_form' && onSaveNsrp != null)
                        IconButton(
                          tooltip: 'Edit NSRP form details',
                          icon: Icon(Icons.edit_note_rounded, color: primary),
                          onPressed: () => _editNsrp(context),
                        ),
                      IconButton(
                        tooltip: 'Preview document',
                        icon: Icon(Icons.visibility_outlined, color: primary),
                        onPressed: () => _openArtifact(context, artifact),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildNsrpDetailsSection(BuildContext context) {
    return SectionWrapper(
      title: 'NSRP Form 1 — Saved Entries',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onRebuildNsrp != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton.icon(
                onPressed: onRebuildNsrp,
                icon: const Icon(Icons.edit_document),
                label: const Text('Edit full Form 1 and regenerate PDF'),
              ),
            ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              '${_formEntries.length} completed fields',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text(
              'Personal and employment information captured from your form',
            ),
            trailing: onSaveNsrp == null
                ? null
                : IconButton(
                    tooltip: 'Edit NSRP form details',
                    icon: Icon(Icons.edit_note_outlined, color: primary),
                    onPressed: () => _editNsrp(context),
                  ),
            children: _formEntries.map((entry) {
              final label = entry['label']?.toString().trim();
              final value = entry['value']?.toString().trim();
              if ((label == null || label.isEmpty) &&
                  (value == null || value.isEmpty)) {
                return const SizedBox.shrink();
              }
              return ListTile(
                dense: true,
                title: Text(label?.isNotEmpty == true ? label! : 'Form field'),
                subtitle: Text(value ?? ''),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildResumeDetailsSection() {
    return SectionWrapper(
      title: 'Resume Builder — Saved Content',
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(
          '${_resumeFields.length} saved resume fields',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          'Template: ${resumeData['template']?.toString() ?? 'Uploaded resume'}',
        ),
        children: _resumeFields.map((field) {
          final section = field['section']?.toString() ?? 'Resume';
          final label = field['label']?.toString() ?? 'Resume detail';
          final value = field['value']?.toString() ?? '';
          return ListTile(
            dense: true,
            title: Text('$section · $label'),
            subtitle: Text(value),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _editNsrp(BuildContext context) async {
    if (onSaveNsrp == null) return;
    await showDialog<void>(
      context: context,
      builder: (_) => NsrpEntriesEditor(
        formData: Map<String, dynamic>.from(pesoFormData),
        onSave: onSaveNsrp!,
      ),
    );
  }

  Future<void> _openArtifact(
    BuildContext context,
    Map<String, dynamic> artifact,
  ) async {
    final category = artifact['category']?.toString() ?? '';
    await showDialog<void>(
      context: context,
      builder: (_) => ProfileDocumentDialog(
        artifact: artifact,
        onReplacePdf: () => onReplacePdf == null
            ? Future<bool>.value(false)
            : onReplacePdf!(category),
        onEditNsrp: category == 'nsrp_form' && onRebuildNsrp != null
            ? onRebuildNsrp
            : null,
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _buildDesignerTextField(
    String label,
    String hint, {
    IconData? icon,
    TextEditingController? controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: textDark,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400),
            prefixIcon: icon != null
                ? Icon(icon, color: Colors.grey.shade400, size: 22)
                : null,
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 25,
              vertical: 22,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkillChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.memory, size: 18, color: Colors.blue.shade500),
          const SizedBox(width: 10),
          Flexible(
            fit: FlexFit.loose,
            child: Text(
              label,
              softWrap: true,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textDark,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared lightweight glass card for the profile and settings screens.
class SectionWrapper extends StatelessWidget {
  const SectionWrapper({
    super.key,
    required this.title,
    required this.child,
    this.actionWidget,
  });

  final String title;
  final Widget child;
  final Widget? actionWidget;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return PesoGlassSurface(
      elevated: true,
      radius: compact ? 22 : 26,
      margin: EdgeInsets.only(bottom: compact ? 20 : 28),
      padding: EdgeInsets.all(compact ? 18 : 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F2EC),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.layers_outlined,
                  color: Color(0xFF236349),
                  size: 19,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: compact ? 18 : 22,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF17352B),
                    letterSpacing: -0.35,
                  ),
                ),
              ),
            ],
          ),
          if (actionWidget != null) ...[
            const SizedBox(height: 14),
            actionWidget!,
          ],
          const SizedBox(height: 20),
          const Divider(color: Color(0xFFE0EBE4), height: 1),
          const SizedBox(height: 22),
          child,
        ],
      ),
    );
  }
}
