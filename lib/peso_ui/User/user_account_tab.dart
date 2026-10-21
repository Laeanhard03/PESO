import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'user_profile_avatar.dart';

import '../../peso_services/app_toast.dart';
import '../../peso_services/peso_api_client.dart';
import '../../peso_services/auth_service.dart';

import '../Reusable_Designs/peso_premium_ui.dart';

class UserAccountTab extends StatefulWidget {
  final Map<String, dynamic> profile;
  final Future<void> Function(Map<String, dynamic> updates) onSave;
  final Uint8List? photoBytes;
  final Future<void> Function()? onUploadPhoto;
  final Future<void> Function(String)? onChooseAvatar;
  final Map<String, dynamic> documents;
  final VoidCallback? onEditNsrp;
  final Future<bool> Function()? onReplaceResume;
  final VoidCallback? onCreateResume;
  final VoidCallback? onReviewAi;
  final Color primary;
  final Color textDark;
  final Color textLight;

  const UserAccountTab({
    super.key,
    required this.profile,
    required this.onSave,
    this.photoBytes,
    this.onUploadPhoto,
    this.onChooseAvatar,
    this.documents = const <String, dynamic>{},
    this.onEditNsrp,
    this.onReplaceResume,
    this.onCreateResume,
    this.onReviewAi,
    required this.primary,
    required this.textDark,
    required this.textLight,
  });

  @override
  State<UserAccountTab> createState() => _UserAccountTabState();
}

class _UserAccountTabState extends State<UserAccountTab> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _locationController;
  late final TextEditingController _educationController;
  late final TextEditingController _employmentController;
  late final TextEditingController _addressController;
  String? _barangay;
  List<String> _barangays = const [
    'Balite', 'Burgos', 'Geronimo', 'Macabud', 'Manggahan', 'Mascap',
    'Puray', 'Rosario', 'San Isidro', 'San Jose', 'San Rafael',
  ];
  bool _saving = false;
  bool _applicationsLoading = true;
  String? _applicationsError;
  List<Map<String, dynamic>> _myApplications = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _phoneController = TextEditingController();
    _locationController = TextEditingController();
    _educationController = TextEditingController();
    _employmentController = TextEditingController();
    _addressController = TextEditingController();
    _applyProfile(widget.profile);
    unawaited(_loadBarangayCatalog());
    unawaited(_loadMyApplications());
  }

  @override
  void didUpdateWidget(covariant UserAccountTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile != widget.profile) _applyProfile(widget.profile);
  }

  Future<void> _loadBarangayCatalog() async {
    try {
      final result = await PesoApiClient.getResidencyBarangays();
      final items = result['barangays'];
      if (!mounted || items is! List) return;
      final barangays = items.whereType<String>().toList();
      if (barangays.length == 11) {
        setState(() => _barangays = barangays);
      }
    } catch (_) {
      // The server validates the bundled 11-barangay fallback.
    }
  }

  void _applyProfile(Map<String, dynamic> data) {
    _firstNameController.text = data['firstName']?.toString() ?? '';
    _lastNameController.text = data['lastName']?.toString() ?? '';
    _phoneController.text = data['phoneNumber']?.toString() ?? '';
    _locationController.text = data['location']?.toString() ?? '';
    _educationController.text = data['educationLevel']?.toString() ?? '';
    _employmentController.text =
        data['employmentStatus']?.toString() ?? 'Looking for work';
    _addressController.text = data['address']?.toString() ?? '';
    final proposedBarangay = data['barangay']?.toString() ?? '';
    _barangay = _barangays.contains(proposedBarangay) ? proposedBarangay : null;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _educationController.dispose();
    _employmentController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final supportsPassword = user.providerData.any(
      (provider) => provider.providerId == 'password');
    if (!supportsPassword) {
      AppToast.warning(context,
        'This account uses Google or another sign-in provider. Update its password with that provider.');
      return;
    }
    final current = TextEditingController();
    final newer = TextEditingController();
    final confirm = TextEditingController();
    try {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Change password'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: current, obscureText: true,
                decoration: const InputDecoration(labelText: 'Current password')),
              const SizedBox(height: 12),
              TextField(controller: newer, obscureText: true,
                decoration: const InputDecoration(labelText: 'New password (8+ characters)')),
              const SizedBox(height: 12),
              TextField(controller: confirm, obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm new password')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Update password')),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
      if (newer.text.length < 8 || newer.text != confirm.text) {
        AppToast.error(context, 'Use 8 or more characters and matching new passwords.');
        return;
      }
      await AuthService.changePassword(
        currentPassword: current.text, newPassword: newer.text);
      if (mounted) AppToast.success(context, 'Your password has been changed.');
    } catch (_) {
      if (mounted) AppToast.error(context,
        'Password change failed. Confirm your current password and retry.');
    } finally {
      current.dispose();
      newer.dispose();
      confirm.dispose();
    }
  }

  Future<void> _loadMyApplications({bool refresh = false}) async {
    if (refresh && mounted) {
      setState(() {
        _applicationsLoading = true;
        _applicationsError = null;
      });
    }
    try {
      final response = await PesoApiClient.listMyApplications(limit: 50);
      final records = response['applications'];
      if (!mounted) return;
      setState(() {
        _myApplications = records is List
            ? records.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList()
            : <Map<String, dynamic>>[];
        _applicationsError = null;
        _applicationsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _applicationsError = 'Your applications could not be loaded. Check your connection and retry.';
        _applicationsLoading = false;
      });
    }
  }
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_barangay == null || _addressController.text.trim().length < 5) {
      AppToast.warning(context,
        'Choose your Montalban barangay and enter your complete residential address.');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave({
        'firstName': _firstNameController.text,
        'lastName': _lastNameController.text,
        'phoneNumber': _phoneController.text,
        'location': _locationController.text,
        'educationLevel': _educationController.text,
        'employmentStatus': _employmentController.text,
        'municipality': 'Montalban',
        'barangay': _barangay,
        'address': _addressController.text.trim(),
      });
      if (mounted) {
        AppToast.success(context, 'Your profile was saved to your account.');
      }
    } catch (error) {
      if (mounted) {
        AppToast.error(
          context,
          'Your profile could not be saved. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.profile['email']?.toString() ?? 'No email';
    final role = widget.profile['role']?.toString() ?? 'job_seeker';
    final providers =
        (widget.profile['providerIds'] as List<dynamic>? ?? const [])
            .map((provider) => provider.toString())
            .toSet()
            .toList();
    final isEmailVerified = widget.profile['emailVerified'] == true;
    final isPhoneVerified = widget.profile['phoneVerified'] == true;
    final width = MediaQuery.of(context).size.width;
    final padding = width < 700 ? 20.0 : 50.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PesoPageHeader(
                title: 'My Account',
                description: 'Your details are saved to your private JobKonek profile and can be used by the matching and AI features.',
                eyebrow: 'Personal workspace',
                icon: Icons.account_circle_outlined,
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFDCE9E1))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Applicant documents', style: TextStyle(
                    color: widget.textDark, fontSize: 19, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(widget.documents.isEmpty
                    ? 'Checking saved documents?'
                    : 'Resume: ' + (widget.documents['resumeSubmitted'] == true ? 'Submitted' : 'Missing') +
                      '   ?   NSRP Form 1: ' + (widget.documents['formSubmitted'] == true ? 'Submitted' : 'Missing'),
                    style: TextStyle(color: widget.textLight, height: 1.5)),
                  const SizedBox(height: 14),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    OutlinedButton.icon(onPressed: widget.onCreateResume,
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('Create resume')),
                    OutlinedButton.icon(onPressed: widget.onReplaceResume == null ? null :
                      () => unawaited(widget.onReplaceResume!()),
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload / replace resume')),
                    OutlinedButton.icon(onPressed: widget.onEditNsrp,
                      icon: const Icon(Icons.edit_document),
                      label: const Text('Complete / edit NSRP')),
                    OutlinedButton.icon(onPressed: widget.onReviewAi,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('AI extraction & verification')),
                  ]),
                ]),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFFFFF), Color(0xFFF0F8F3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFDCE9E1)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x10173E31),
                      blurRadius: 22,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        PesoProfileAvatar(
                          radius: 27,
                          style:
                              widget.profile['avatarStyle']?.toString() ??
                              'person',
                          photoBytes: widget.photoBytes,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${widget.profile['displayName'] ?? 'Job Seeker'}',
                                style: TextStyle(
                                  color: widget.textDark,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                email,
                                style: TextStyle(
                                  color: widget.textLight,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Choose your profile picture',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: widget.textDark,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        for (final style in pesoAvatarStyles)
                          ChoiceChip(
                            label: Text(
                              style == 'person'
                                  ? 'Classic'
                                  : style[0].toUpperCase() + style.substring(1),
                            ),
                            avatar: Icon(pesoAvatarIcon(style), size: 18),
                            selected: widget.profile['avatarStyle'] == style,
                            onSelected: widget.onChooseAvatar == null
                                ? null
                                : (_) => widget.onChooseAvatar!(style),
                          ),
                        OutlinedButton.icon(
                          key: const Key('upload-profile-photo'),
                          onPressed: widget.onUploadPhoto,
                          icon: const Icon(Icons.add_a_photo_outlined),
                          label: const Text('Upload photo'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _statusChip(
                          role == 'admin' ? 'Staff account' : 'Job seeker',
                          widget.primary,
                        ),
                        _statusChip(
                          isEmailVerified
                              ? 'Email verified'
                              : 'Email not verified',
                          isEmailVerified ? Colors.green : Colors.orange,
                        ),
                        _statusChip(
                          isPhoneVerified
                              ? 'Phone verified'
                              : 'Phone not verified',
                          isPhoneVerified ? Colors.green : Colors.orange,
                        ),
                        ...providers.map(
                          (provider) => _statusChip(
                            _providerLabel(provider),
                            Colors.blueGrey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                key: const Key('change-password'),
                onPressed: _changePassword,
                icon: const Icon(Icons.lock_reset),
                label: const Text('Change password'),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(width < 700 ? 20 : 30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFDCE9E1)),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Personal Information',
                        style: TextStyle(
                          color: widget.textDark,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Keep these details current so your user dashboard reflects your real information.',
                        style: TextStyle(color: widget.textLight, height: 1.45),
                      ),
                      const SizedBox(height: 24),
                      _fieldRow(
                        width,
                        _profileField(
                          'First name',
                          _firstNameController,
                          requiredField: true,
                        ),
                        _profileField(
                          'Last name',
                          _lastNameController,
                          requiredField: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _profileField(
                        'Phone number',
                        _phoneController,
                        hint: '+639171234567',
                      ),
                      const SizedBox(height: 16),
                      _profileField(
                        'City / Municipality',
                        _locationController,
                        hint: 'Montalban, Rizal',
                      ),
                      const SizedBox(height: 16),
                      Text('Montalban, Rizal residency', style: TextStyle(
                        color: widget.textDark, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        key: ValueKey('account-barangay-' + (_barangay ?? 'unset')),
                        initialValue: _barangays.contains(_barangay) ? _barangay : null,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Barangay (required)',
                          border: OutlineInputBorder()),
                        items: _barangays.map((item) => DropdownMenuItem(
                          value: item, child: Text(item))).toList(),
                        onChanged: (value) => setState(() => _barangay = value),
                      ),
                      const SizedBox(height: 12),
                      _profileField('Full residential address', _addressController,
                        requiredField: true),
                      const SizedBox(height: 8),
                      Text('Residency status: ' +
                        (widget.profile['residency'] is Map
                          ? ((widget.profile['residency'] as Map)['status'] ?? 'Needs review').toString()
                          : 'Needs review') +
                        '. PESO verifies residency separately; a dropdown is not proof.',
                        style: TextStyle(color: widget.textLight, height: 1.5)),
                      const SizedBox(height: 16),
                      _fieldRow(
                        width,
                        _profileField(
                          'Highest education',
                          _educationController,
                          hint: 'e.g. BS Information Technology',
                        ),
                        _profileField(
                          'Employment status',
                          _employmentController,
                          hint: 'e.g. Looking for work',
                        ),
                      ),
                      const SizedBox(height: 26),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _save,
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
                          label: Text(_saving ? 'Saving…' : 'Save Profile'),
                          style: FilledButton.styleFrom(
                            backgroundColor: widget.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 19,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _myApplicationsSection(),
              const SizedBox(height: 18),
              Text(
                'Your profile data is stored privately through the PESO API. Account role is controlled by the system and verified through the signed-in session, not by this form.',
                style: TextStyle(
                  color: widget.textLight,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _myApplicationsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE9E1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D173E31),
            blurRadius: 18,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.work_history_outlined, color: widget.primary, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'My Applications',
                  style: TextStyle(
                    color: widget.textDark,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Refresh applications',
                onPressed: _applicationsLoading ? null : () => _loadMyApplications(refresh: true),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          Text(
            'Applications you submitted are tied to this signed-in account.',
            style: TextStyle(color: widget.textLight, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 16),
          if (_applicationsLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_applicationsError != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    _applicationsError!,
                    style: TextStyle(color: widget.textLight),
                  ),
                ),
                TextButton(
                  onPressed: () => _loadMyApplications(refresh: true),
                  child: const Text('Retry'),
                ),
              ],
            )
          else if (_myApplications.isEmpty)
            Text(
              'No submitted applications yet. When you apply to a job, it will appear here.',
              style: TextStyle(color: widget.textLight, height: 1.5),
            )
          else
            for (final application in _myApplications) _applicationTile(application),
        ],
      ),
    );
  }

  Widget _applicationTile(Map<String, dynamic> application) {
    final title = (application['jobTitle'] ?? 'Job application').toString();
    final employer = (application['employer'] ?? '').toString().trim();
    final status = (application['status'] ?? 'submitted').toString().trim();
    final statusWords = status.replaceAll('_', ' ');
    final statusLabel = statusWords.isEmpty
        ? 'Submitted'
        : '${statusWords[0].toUpperCase()}${statusWords.substring(1)}';
    final submittedAt = DateTime.tryParse(application['submittedAt']?.toString() ?? '')?.toLocal();
    final dateLabel = submittedAt == null
        ? 'Submission date unavailable'
        : 'Submitted ${submittedAt.year}-${submittedAt.month.toString().padLeft(2, '0')}-${submittedAt.day.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3EBE6)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: widget.primary.withValues(alpha: 0.10),
          child: Icon(Icons.business_center_outlined, color: widget.primary),
        ),
        title: Text(
          title,
          style: TextStyle(color: widget.textDark, fontWeight: FontWeight.w800),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (employer.isNotEmpty) Text(employer),
              const SizedBox(height: 4),
              Text(dateLabel),
              const SizedBox(height: 6),
              _statusChip(statusLabel, widget.primary),
            ],
          ),
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _fieldRow(double width, Widget first, Widget second) {
    if (width < 650) {
      return Column(children: [first, const SizedBox(height: 16), second]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: 16),
        Expanded(child: second),
      ],
    );
  }

  Widget _profileField(
    String label,
    TextEditingController controller, {
    bool requiredField = false,
    String? hint,
  }) {
    return TextFormField(
      controller: controller,
      validator: requiredField
          ? (value) => value == null || value.trim().isEmpty
                ? '$label is required.'
                : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
    );
  }

  Widget _statusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _providerLabel(String provider) {
    switch (provider) {
      case 'google.com':
        return 'Google sign-in';
      case 'phone':
        return 'SMS sign-in';
      case 'password':
        return 'Email and password';
      default:
        return provider;
    }
  }
}
