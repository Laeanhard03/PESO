import 'package:flutter/material.dart';

import 'user_job_feed_tab.dart'; // Imports FadeSlideEntrance
import '../../peso_services/profile_artifact_service.dart';

class UserAiProfileTab extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController titleController;
  final TextEditingController bioController;
  final List<String> userSkills;
  final Map<String, dynamic> aiProfileData;
  final Map<String, dynamic> resumeData;
  final Map<String, dynamic> pesoFormData;
  final List<Map<String, dynamic>> artifacts;
  final String Function(String) translate;
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
    required this.resumeData,
    required this.pesoFormData,
    required this.artifacts,
    required this.translate,
    required this.primary,
    required this.textDark,
    required this.textLight,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(50),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeSlideEntrance(
                delay: 0,
                child: Text(
                  translate('AI Extracted Profile'),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: textDark,
                    letterSpacing: -1,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              FadeSlideEntrance(
                delay: 100,
                child: Text(
                  translate(
                    'Review your AI-extracted background, submitted resume, and saved NSRP Form 1 details below.',
                  ),
                  style: TextStyle(fontSize: 18, color: textLight),
                ),
              ),
              const SizedBox(height: 40),
              FadeSlideEntrance(
                delay: 300,
                child: SectionWrapper(
                  title: 'Personal Context',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildDesignerTextField(
                              'Full Name',
                              'Name from Resume',
                              controller: nameController,
                            ),
                          ),
                          const SizedBox(width: 30),
                          Expanded(
                            child: _buildDesignerTextField(
                              'Professional Title',
                              'Title from Resume',
                              icon: Icons.badge_outlined,
                              controller: titleController,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        'AI Generated Bilingual Bio',
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
                      const SizedBox(height: 40),
                      const Text(
                        'AI Extracted Skills',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
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
              const SizedBox(height: 8),
              _buildDocumentsSection(context),
              if (_hasAiBackground) _buildAiBackgroundSection(),
              if (_formEntries.isNotEmpty) _buildNsrpDetailsSection(),
              if (_resumeFields.isNotEmpty || (resumeData['plainText']?.toString().trim().isNotEmpty ?? false))
                _buildResumeDetailsSection(),
            ],
          ),
        ),
      ),
    );
  }

  bool get _hasAiBackground =>
      _stringList('education').isNotEmpty ||
      _stringList('employmentHistory').isNotEmpty ||
      _stringList('certifications').isNotEmpty ||
      (aiProfileData['yearsExperience'] is num && (aiProfileData['yearsExperience'] as num) > 0);

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
          _buildExtractedList('Education', _stringList('education'), Icons.school_outlined),
          _buildExtractedList('Employment history', _stringList('employmentHistory'), Icons.work_outline),
          _buildExtractedList('Certifications', _stringList('certifications'), Icons.workspace_premium_outlined),
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
              Text(title, style: TextStyle(color: textDark, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          ...values.map((value) => Padding(
                padding: const EdgeInsets.only(left: 28, bottom: 8),
                child: Text(value, style: TextStyle(color: textLight, height: 1.4)),
              )),
        ],
      ),
    );
  }

  bool get _hasResumeSource {
    final fileName = resumeData['fileName']?.toString().trim() ?? '';
    final plainText = resumeData['plainText']?.toString().trim() ?? '';
    final fields = resumeData['fields'];
    return fileName.isNotEmpty || plainText.isNotEmpty || (fields is List && fields.isNotEmpty);
  }

  bool get _hasNsrpSource =>
      (pesoFormData['documentType']?.toString().isNotEmpty ?? false) || _formEntries.isNotEmpty;

  bool get _hasSubmittedResumeOrForm => _hasResumeSource || _hasNsrpSource;

  List<Map<String, dynamic>> get _formEntries {
    final raw = pesoFormData['entries'];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .where((value) => (value['value']?.toString().trim().isNotEmpty ?? false))
        .toList();
  }

  List<Map<String, dynamic>> get _resumeFields {
    final raw = resumeData['fields'];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .where((value) => (value['value']?.toString().trim().isNotEmpty ?? false))
        .toList();
  }

  Widget _buildDocumentsSection(BuildContext context) {
    return SectionWrapper(
      title: 'Saved Resumes & Forms',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your submitted documents and form details are associated with your account. Original files are stored privately when Firebase Cloud Storage is configured.',
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
                      leading: Icon(Icons.picture_as_pdf_outlined, color: primary),
                      title: const Text('Resume submitted', style: TextStyle(fontWeight: FontWeight.w800)),
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
                      title: const Text('NSRP Form 1 submitted', style: TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('${_formEntries.length} form entries saved to your profile'),
                    ),
                  const SizedBox(height: 6),
                  const Text(
                    'The structured details were saved, but the original PDF is not available to open yet. Configure Firebase Cloud Storage and repeat onboarding to store the document files.',
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      category == 'nsrp_form' ? Icons.assignment_outlined : Icons.picture_as_pdf_outlined,
                      color: primary,
                    ),
                  ),
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('$fileName${sizeBytes > 0 ? ' · ${_formatSize(sizeBytes)}' : ''}'),
                  trailing: IconButton(
                    tooltip: 'Open document',
                    icon: Icon(Icons.open_in_new_rounded, color: primary),
                    onPressed: () => _openArtifact(context, artifact),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildNsrpDetailsSection() {
    return SectionWrapper(
      title: 'NSRP Form 1 — Saved Entries',
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text('${_formEntries.length} completed fields', style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: const Text('Personal and employment information captured from your form'),
        children: _formEntries.map((entry) {
          final label = entry['label']?.toString().trim();
          final value = entry['value']?.toString().trim();
          if ((label == null || label.isEmpty) && (value == null || value.isEmpty)) {
            return const SizedBox.shrink();
          }
          return ListTile(
            dense: true,
            title: Text(label?.isNotEmpty == true ? label! : 'Form field'),
            subtitle: Text(value ?? ''),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildResumeDetailsSection() {
    return SectionWrapper(
      title: 'Resume Builder — Saved Content',
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text('${_resumeFields.length} saved resume fields', style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('Template: ${resumeData['template']?.toString() ?? 'Uploaded resume'}'),
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

  Future<void> _openArtifact(BuildContext context, Map<String, dynamic> artifact) async {
    try {
      await ProfileArtifactService.openArtifact(artifact);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open the document: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
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
          Text(
            label,
            style: TextStyle(
              color: textDark,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class SectionWrapper extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? actionWidget;

  const SectionWrapper({
    super.key,
    required this.title,
    required this.child,
    this.actionWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 40),
      padding: const EdgeInsets.all(50),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                ),
              ),
              actionWidget ?? const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 30),
          const Divider(color: Colors.black12),
          const SizedBox(height: 30),
          child,
        ],
      ),
    );
  }
}
