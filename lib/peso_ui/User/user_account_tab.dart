import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'user_profile_avatar.dart';

import '../../peso_services/app_toast.dart';

import '../Reusable_Designs/peso_premium_ui.dart';

class UserAccountTab extends StatefulWidget {
  final Map<String, dynamic> profile;
  final Future<void> Function(Map<String, dynamic> updates) onSave;
  final Uint8List? photoBytes;
  final Future<void> Function()? onUploadPhoto;
  final Future<void> Function(String)? onChooseAvatar;
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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _phoneController = TextEditingController();
    _locationController = TextEditingController();
    _educationController = TextEditingController();
    _employmentController = TextEditingController();
    _applyProfile(widget.profile);
  }

  @override
  void didUpdateWidget(covariant UserAccountTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile != widget.profile) _applyProfile(widget.profile);
  }

  void _applyProfile(Map<String, dynamic> data) {
    _firstNameController.text = data['firstName']?.toString() ?? '';
    _lastNameController.text = data['lastName']?.toString() ?? '';
    _phoneController.text = data['phoneNumber']?.toString() ?? '';
    _locationController.text = data['location']?.toString() ?? '';
    _educationController.text = data['educationLevel']?.toString() ?? '';
    _employmentController.text =
        data['employmentStatus']?.toString() ?? 'Looking for work';
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _educationController.dispose();
    _employmentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.onSave({
        'firstName': _firstNameController.text,
        'lastName': _lastNameController.text,
        'phoneNumber': _phoneController.text,
        'location': _locationController.text,
        'educationLevel': _educationController.text,
        'employmentStatus': _employmentController.text,
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
              const SizedBox(height: 28),
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
                        hint: 'e.g. San Mateo, Rizal',
                      ),
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
