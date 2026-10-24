
import 'dart:async';

import '../../peso_services/applicant_draft_service.dart';
import '../../peso_services/registration_draft_scope.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

import '../../peso_services/peso_api_client.dart';
import '../User/user_profile_avatar.dart';

import '../../peso_services/app_toast.dart';

import '../../peso_services/auth_service.dart';
import 'privacy_notice.dart';

class RegisterForm extends StatefulWidget {
  final Color pesoGreen;
  final bool isLight;
  final VoidCallback onSwitchToLogin;

  /// Optional test seam for browser popup cancellation.
  final Future<void> Function()? googleSignIn;

  /// Registration values handed to the onboarding step so the resume builder,
  /// the AI extractor, and the NSRP form inherit the registered applicant's
  /// names (and contact values) instead of asking for them again.
  final ValueChanged<Map<String, String>> onProceedToOnboarding;
  final ValueChanged<RegistrationVerificationRequest>
  onEmailVerificationRequired;

  const RegisterForm({
    super.key,
    required this.pesoGreen,
    required this.isLight,
    required this.onSwitchToLogin,
    this.googleSignIn,
    required this.onProceedToOnboarding,
    required this.onEmailVerificationRequired,
  });

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class RegistrationVerificationRequest {
  const RegistrationVerificationRequest({
    required this.identity,
    required this.avatarStyle,
    this.photoBytes,
    this.photoName,
    this.verificationEmailSent = false,
    this.verificationEmailError,
    this.termsAcceptedAt,
    this.personalDataConsentAt,
  });

  final Map<String, String> identity;
  final String avatarStyle;
  final Uint8List? photoBytes;
  final String? photoName;
  final bool verificationEmailSent;
  final String? verificationEmailError;
  final String? termsAcceptedAt;
  final String? personalDataConsentAt;
}

class _RegisterFormState extends State<RegisterForm> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  Timer? _draftTimer;
  bool _restoring = false;
  String _lastRestoreEmail = '';
  String _draftStatus = 'Offline Draft';
  bool _termsAccepted = false;
  bool _personalDataConsent = false;

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _emailController,
      _firstNameController,
      _lastNameController,
      _phoneController,
      _addressController,
    ]) {
      controller.addListener(_onRegistrationEdited);
    }
  }

  void _onRegistrationEdited() {
    if (_restoring) return;
    _draftTimer?.cancel();
    if (mounted) setState(() => _draftStatus = 'Saving');
    _draftTimer = Timer(const Duration(milliseconds: 750), () {
      unawaited(_persistRegistrationDraft());
    });
  }

  Future<void> _persistRegistrationDraft() async {
    final email = _emailController.text.trim().toLowerCase();
    if (!email.contains('@') || !email.contains('.')) return;
    if (_lastRestoreEmail != email) {
      _lastRestoreEmail = email;
      final stored = await ApplicantDraftService.read(
        registrationDraftScope(),
        'registration',
      );
      if (stored != null &&
          stored['email']?.toString().toLowerCase() != email) {
        // A different applicant used this tab; do not expose their fields.
        await ApplicantDraftService.clear(
          registrationDraftScope(),
          'registration',
        );
      }
      if (stored != null &&
          stored['email']?.toString().toLowerCase() == email &&
          mounted &&
          _emailController.text.trim().toLowerCase() == email) {
        _restoring = true;
        if (_firstNameController.text.isEmpty) {
          _firstNameController.text = stored['firstName']?.toString() ?? '';
        }
        if (_lastNameController.text.isEmpty) {
          _lastNameController.text = stored['lastName']?.toString() ?? '';
        }
        if (_phoneController.text.isEmpty) {
          _phoneController.text = stored['phone']?.toString() ?? '';
        }
        if (_addressController.text.isEmpty) {
          _addressController.text = stored['address']?.toString() ?? '';
        }
        final savedBarangay = stored['barangay']?.toString() ?? '';
        if (_barangay == null && barangays.contains(savedBarangay)) {
          _barangay = savedBarangay;
        }
        _restoring = false;
      }
    }
    try {
      await ApplicantDraftService.write(
        registrationDraftScope(),
        'registration',
        <String, dynamic>{
          'email': email,
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'barangay': _barangay ?? '',
          'address': _addressController.text.trim(),
          'draftUpdatedAt': DateTime.now().toUtc().toIso8601String(),
        },
      );
      if (mounted) setState(() => _draftStatus = 'Offline Draft');
    } catch (_) {
      if (mounted) setState(() => _draftStatus = 'Sync Failed');
    }
  }

  static const barangays = <String>[
    'Balite',
    'Burgos',
    'Geronimo',
    'Macabud',
    'Manggahan',
    'Mascap',
    'Puray',
    'Rosario',
    'San Isidro',
    'San Jose',
    'San Rafael',
  ];
  String? _barangay;
  bool _isLoading = false;
  bool _googlePending = false;
  int _googleRequestId = 0;
  bool _obscurePassword = true;
  int _registrationStep = 0;
  String _avatarStyle = 'person';
  Uint8List? _pendingPhoto;
  String? _pendingPhotoName;

  @override
  void dispose() {
    _draftTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = true}) {
    if (!mounted) return;
    isError
        ? AppToast.error(context, message)
        : AppToast.success(context, message);
  }

  String _friendlyError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return 'An account already exists for that email address. Try logging in.';
        case 'invalid-email':
          return 'Enter a valid email address.';
        case 'weak-password':
          return 'Choose a stronger password (at least 6 characters).';
        case 'operation-not-allowed':
          return 'This sign-in method is not enabled in Firebase Authentication yet.';
        case 'popup-closed-by-user':
        case 'web-context-cancelled':
          return 'Sign-in was cancelled.';
      }
      return error.message ?? 'Registration failed. Please try again.';
    }
    if (error is StateError || error is ArgumentError) {
      return error
          .toString()
          .replaceFirst('Bad state: ', '')
          .replaceFirst('Invalid argument(s): ', '');
    }
    return 'Something went wrong. Please try again. ($error)';
  }

  Future<void> _chooseRegistrationPhoto() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (!mounted || picked == null || picked.files.isEmpty) return;
      final file = picked.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.length > 3 * 1024 * 1024 || bytes.isEmpty) {
        _showMessage('Choose a JPG or PNG under 3 MB.');
        return;
      }
      setState(() {
        _pendingPhoto = bytes;
        _pendingPhotoName = file.name;
        _avatarStyle = 'photo';
      });
    } catch (error) {
      _showMessage(
        'Could not load that photo. Choose another JPG or PNG: $error',
      );
    }
  }

  Future<void> _persistRegistrationAvatar() async {
    if (_pendingPhoto == null && _avatarStyle == 'person') return;
    try {
      if (_pendingPhoto != null) {
        await PesoApiClient.uploadArtifact(
          fileName: _pendingPhotoName ?? 'profile.jpg',
          category: 'profile_photo',
          mimeType: (_pendingPhotoName ?? '').toLowerCase().endsWith('.png')
              ? 'image/png'
              : 'image/jpeg',
          bytes: _pendingPhoto!,
        );
      } else {
        await PesoApiClient.updateProfile({'avatarStyle': _avatarStyle});
      }
    } catch (error) {
      if (mounted) {
        _showMessage(
          'Account created, but the avatar could not be saved: $error. You can update it in My Account.',
        );
      }
    }
  }

  Future<void> _showPolicyDialog(String title, String body) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: SelectableText(
            body,
            style: Theme.of(dialogContext).textTheme.bodyMedium
                ?.copyWith(height: 1.45),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _continueToAvatar() {
    if (!_termsAccepted || !_personalDataConsent) {
      _showMessage(
        'Please agree to the Terms and Conditions, acknowledge the Privacy Notice, and consent to the processing of your submitted information.',
      );
      return;
    }
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    if (firstName.isEmpty || lastName.isEmpty || email.isEmpty ||
        _passwordController.text.isEmpty) {
      _showMessage('Complete your name, email, and password first.');
      return;
    }
    if (!AuthService.isValidPersonName(firstName) ||
        !AuthService.isValidPersonName(lastName)) {
      _showMessage('Enter a valid first and last name using letters, spaces, apostrophes, periods, or hyphens.');
      return;
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(email)) {
      _showMessage('Enter a valid email address.');
      return;
    }
    if (phone.isNotEmpty && !AuthService.isValidPhilippineMobileNumber(phone)) {
      _showMessage('Enter a valid Philippine mobile number (09XXXXXXXXX or +639XXXXXXXXX).');
      return;
    }
    if (_passwordController.text.length < 6) {
      _showMessage('Password must be at least 6 characters.');
      return;
    }
    if (_barangay == null ||
        !barangays.contains(_barangay) ||
        _addressController.text.trim().length < 5) {
      _showMessage(
        'Select your Montalban barangay and enter your complete address. PESO will verify residency.',
      );
      return;
    }
    setState(() => _registrationStep = 1);
  }

  Future<void> _registerUser() async {
    if (!_termsAccepted || !_personalDataConsent) {
      _showMessage(
        'Please agree to the Terms and Conditions, acknowledge the Privacy Notice, and consent to the processing of your submitted information.',
      );
      return;
    }
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (firstName.isEmpty ||
        lastName.isEmpty ||
        email.isEmpty ||
        password.isEmpty) {
      _showMessage('First name, last name, email, and password are required.');
      return;
    }
    if (!AuthService.isValidPersonName(firstName) ||
        !AuthService.isValidPersonName(lastName)) {
      _showMessage('Enter a valid first and last name using letters, spaces, apostrophes, periods, or hyphens.');
      return;
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(email)) {
      _showMessage('Enter a valid email address.');
      return;
    }
    if (_phoneController.text.trim().isNotEmpty &&
        !AuthService.isValidPhilippineMobileNumber(_phoneController.text)) {
      _showMessage('Enter a valid Philippine mobile number (09XXXXXXXXX or +639XXXXXXXXX).');
      return;
    }
    if (password.length < 6) {
      _showMessage('Password must be at least 6 characters.');
      return;
    }

    if (_barangay == null ||
        !barangays.contains(_barangay) ||
        _addressController.text.trim().length < 5) {
      _showMessage(
        'Choose your barangay and provide your full Montalban address.',
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final phoneNumber = _phoneController.text.trim().isEmpty
          ? ''
          : AuthService.normalizePhoneNumber(_phoneController.text);
      await AuthService.registerWithEmail(
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
      );
      var verificationSent = true;
      String? verificationError;
      try {
        await AuthService.sendEmailVerification();
      } catch (error) {
        verificationSent = false;
        verificationError = _friendlyError(error);
        _showMessage(
          'Your account was created, but the verification email could not be sent: $error',
        );
      }
      if (verificationSent) {
        _showMessage(
          'Verification email sent. Verify your email to continue.',
          isError: false,
        );
      }
      final consentAcceptedAt = DateTime.now().toUtc().toIso8601String();
      widget.onEmailVerificationRequired(
        RegistrationVerificationRequest(
          identity: <String, String>{
            'firstName': firstName,
            'lastName': lastName,
            'email': email,
            'phone': phoneNumber,
            'municipality': 'Montalban',
            'barangay': _barangay!,
            'address': _addressController.text.trim(),
          },
          avatarStyle: _avatarStyle,
          photoBytes: _pendingPhoto,
          photoName: _pendingPhotoName,
          verificationEmailSent: verificationSent,
          verificationEmailError: verificationError,
          termsAcceptedAt: consentAcceptedAt,
          personalDataConsentAt: consentAcceptedAt,
        ),
      );
    } catch (error) {
      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _cancelGoogle() {
    if (!_googlePending) return;
    ++_googleRequestId;
    setState(() {
      _googlePending = false;
      _isLoading = false;
    });
    _showMessage('Google sign-in cancelled. You can try again or use email.');
  }

  Future<void> _registerWithGoogle() async {
    if (!_termsAccepted || !_personalDataConsent) {
      _showMessage(
        'Please agree to the Terms and Conditions, acknowledge the Privacy Notice, and consent to the processing of your submitted information.',
      );
      return;
    }
    if (_isLoading) return;
    if (_barangay == null ||
        !barangays.contains(_barangay) ||
        _addressController.text.trim().length < 5) {
      _showMessage(
        'Select your barangay and enter your full address before Google sign-in.',
      );
      return;
    }
    final requestId = ++_googleRequestId;
    setState(() {
      _isLoading = true;
      _googlePending = true;
    });
    try {
      await (widget.googleSignIn?.call() ?? AuthService.signInWithGoogle());
      // Closing or cancelling the popup must not navigate later.
      if (!mounted || requestId != _googleRequestId) return;
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.emailVerified) {
        String? verificationError;
        try {
          await AuthService.sendEmailVerification();
        } catch (error) {
          verificationError = _friendlyError(error);
        }
        final consentAcceptedAt = DateTime.now().toUtc().toIso8601String();
        widget.onEmailVerificationRequired(
          RegistrationVerificationRequest(
            identity: _identityFromFirebaseUser(),
            avatarStyle: _avatarStyle,
            photoBytes: _pendingPhoto,
            photoName: _pendingPhotoName,
            verificationEmailSent: verificationError == null,
            termsAcceptedAt: consentAcceptedAt,
            personalDataConsentAt: consentAcceptedAt,
            verificationEmailError: verificationError,
          ),
        );
      } else if (mounted && requestId == _googleRequestId) {
        if (user != null) {
          await AuthService.ensureUserProfile(
            user,
            municipality: 'Montalban',
            barangay: _barangay,
          );
          try {
            await PesoApiClient.updateAccountResidency(
              barangay: _barangay!,
              address: _addressController.text.trim(),
            );
          } catch (_) {
            if (mounted) {
              _showMessage(
                'Signed in, but your residency details need synchronization.',
              );
            }
          }
        }
        final consentAcceptedAt = DateTime.now().toUtc().toIso8601String();
        await PesoApiClient.savePrivacyConsent(
          termsAcceptedAt: consentAcceptedAt,
          personalDataConsentAt: consentAcceptedAt,
          policyVersion: pesoPrivacyNoticeVersion,
        );
        await _persistRegistrationAvatar();
        await ApplicantDraftService.clear(
          registrationDraftScope(),
          'registration',
        );
        widget.onProceedToOnboarding(_identityFromFirebaseUser());
      }
    } catch (error) {
      if (mounted && requestId == _googleRequestId) {
        _showMessage(_friendlyError(error));
      }
    } finally {
      if (mounted && requestId == _googleRequestId) {
        setState(() {
          _isLoading = false;
          _googlePending = false;
        });
      }
    }
  }

  /// Google sign-up does not type a name, so inherit the Google profile name
  /// that AuthService stored on the Firebase account.
  Map<String, String> _identityFromFirebaseUser() {
    final user = FirebaseAuth.instance.currentUser;
    final parts = (user?.displayName ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    return <String, String>{
      'firstName': parts.isNotEmpty ? parts.first : '',
      'lastName': parts.length > 1 ? parts.sublist(1).join(' ') : '',
      'email': (user?.email ?? '').trim(),
      'phone': (user?.phoneNumber ?? '').trim(),
      'municipality': 'Montalban',
      'barangay': _barangay ?? '',
      'address': _addressController.text.trim(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final Color textColor = widget.isLight ? Colors.black87 : Colors.white;
    final Color subtitleColor = widget.isLight
        ? Colors.black54
        : Colors.white70;
    final Color fieldBg = widget.isLight
        ? Colors.grey.shade100
        : Colors.white.withValues(alpha: 0.05);
    final Color borderColor = widget.isLight
        ? Colors.grey.shade300
        : Colors.white.withValues(alpha: 0.1);
    final Color hintColor = widget.isLight ? Colors.black38 : Colors.white38;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _stepIndicator(widget.pesoGreen),
            const SizedBox(width: 8),
            _stepIndicator(
              _registrationStep == 1 ? widget.pesoGreen : Colors.grey.shade300,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Create Account',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: textColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 5),
        Text(
          _registrationStep == 0
              ? 'Step 1 of 2: Your account details'
              : 'Step 2 of 2: Choose your profile image',
          style: TextStyle(color: subtitleColor, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 30),
        if (_registrationStep == 0) ...[
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  'First Name',
                  Icons.person_outline,
                  _firstNameController,
                  fieldBg,
                  borderColor,
                  textColor,
                  hintColor,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r"[\p{L}\p{M} .'-]", unicode: true))],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  'Last Name',
                  null,
                  _lastNameController,
                  fieldBg,
                  borderColor,
                  textColor,
                  hintColor,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r"[\p{L}\p{M} .'-]", unicode: true))],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          _buildTextField(
            'Email Address',
            Icons.email_outlined,
            _emailController,
            fieldBg,
            borderColor,
            textColor,
            hintColor,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 15),
          _buildTextField(
            'Phone Number (optional)',
            Icons.phone_android,
            _phoneController,
            fieldBg,
            borderColor,
            textColor,
            hintColor,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ().-]'))],
            helperText:
                'Philippine numbers are automatically formatted with +63.',
          ),
          const SizedBox(height: 15),
          DropdownButtonFormField<String>(
            key: const Key('registration-barangay'),
            initialValue: _barangay,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Barangay — Montalban, Rizal (required)',
              helperText: 'Selecting a barangay does not verify residency. PESO must review eligibility.',
              helperMaxLines: 3,
              filled: true,
              fillColor: fieldBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            items: barangays
                .map((name) => DropdownMenuItem(value: name, child: Text(name)))
                .toList(),
            onChanged: (value) => setState(() => _barangay = value),
          ),
          const SizedBox(height: 15),
          _buildTextField(
            'Full residential address in Montalban, Rizal',
            Icons.home_outlined,
            _addressController,
            fieldBg,
            borderColor,
            textColor,
            hintColor,
          ),
          const SizedBox(height: 10),
          Text(
            'Draft: $_draftStatus (encrypted on this device; passwords are never saved)',
            style: TextStyle(fontSize: 12, color: subtitleColor, height: 1.4),
          ),
          const SizedBox(height: 10),
          Material(
            color: Colors.transparent,
            child: CheckboxListTile(
              value: _termsAccepted,
              onChanged: _isLoading
                  ? null
                  : (value) => setState(() => _termsAccepted = value == true),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'I agree to the Terms and Conditions and acknowledge the Privacy Notice.',
              ),
              subtitle: const Text(
                'Required before creating an account or continuing with Google.',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 8),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                TextButton(
                  key: const Key('registration-terms-link'),
                  onPressed: _isLoading
                      ? null
                      : () => _showPolicyDialog(
                          'Terms and Conditions',
                          pesoTermsAndConditionsText,
                        ),
                  child: const Text('Read Terms and Conditions'),
                ),
                TextButton(
                  key: const Key('registration-privacy-link'),
                  onPressed: _isLoading
                      ? null
                      : () => _showPolicyDialog(
                          'Privacy Notice',
                          pesoPrivacyNoticeText,
                        ),
                  child: const Text('Read Privacy Notice'),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: CheckboxListTile(
              value: _personalDataConsent,
              onChanged: _isLoading
                  ? null
                  : (value) =>
                        setState(() => _personalDataConsent = value == true),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'I consent to processing the personal information I submit, including sensitive information in NSRP Form 1 such as date of birth, sex, religion, education and documents, for the purposes described in the Privacy Notice.',
              ),
              subtitle: const Text(
                'AI-assisted compatibility is advisory only. Do not submit real applicant data to this unapproved prototype.',
              ),
            ),
          ),
          const SizedBox(height: 15),
          _buildTextField(
            'Password (at least 6 characters)',
            Icons.lock_outline,
            _passwordController,
            fieldBg,
            borderColor,
            textColor,
            hintColor,
            isPassword: true,
          ),
          const SizedBox(height: 28),
        ],
        if (_registrationStep == 1) ...[
          Container(
            key: const Key('registration-avatar-choices'),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: fieldBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: widget.pesoGreen.withValues(alpha: 0.12),
                  backgroundImage: _pendingPhoto == null
                      ? null
                      : MemoryImage(_pendingPhoto!),
                  child: _pendingPhoto == null
                      ? Icon(
                          pesoAvatarIcon(_avatarStyle),
                          color: widget.pesoGreen,
                          size: 42,
                        )
                      : null,
                ),
                const SizedBox(height: 14),
                Text(
                  'Choose an avatar or add a profile photo',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 5),
                Text(
                  'You can change this any time in your account settings.',
                  style: TextStyle(color: subtitleColor, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final style in pesoAvatarStyles)
                      ChoiceChip(
                        avatar: Icon(pesoAvatarIcon(style), size: 17),
                        label: Text(style == 'person' ? 'Classic' : style),
                        selected:
                            _avatarStyle == style && _pendingPhoto == null,
                        onSelected: _isLoading
                            ? null
                            : (_) => setState(() {
                                _avatarStyle = style;
                                _pendingPhoto = null;
                                _pendingPhotoName = null;
                              }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _chooseRegistrationPhoto,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(
                    _pendingPhoto == null
                        ? 'Upload a profile photo'
                        : 'Choose a different photo',
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 28),
        if (_registrationStep == 1)
          OutlinedButton(
            onPressed: _isLoading
                ? null
                : () => setState(() => _registrationStep = 0),
            child: const Text('Back to account details'),
          ),
        ElevatedButton(
          onPressed: _isLoading
              ? null
              : (_registrationStep == 0 ? _continueToAvatar : _registerUser),
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.pesoGreen,
            padding: const EdgeInsets.symmetric(vertical: 22),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
              : Text(
                  _registrationStep == 0
                      ? 'Continue to profile photo'
                      : 'Create account and verify email',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
        const SizedBox(height: 15),
        if (_registrationStep == 0)
          OutlinedButton.icon(
            onPressed: _googlePending
                ? _cancelGoogle
                : (_isLoading ? null : _registerWithGoogle),
            icon: Icon(
              _googlePending ? Icons.close_rounded : Icons.g_mobiledata,
              size: 28,
            ),
            label: Text(
              _googlePending
                  ? 'Cancel Google sign-in / unlock form'
                  : 'Continue with Google',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _googlePending ? Colors.orangeAccent : textColor,
              side: BorderSide(color: borderColor),
              padding: const EdgeInsets.symmetric(vertical: 17),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        const SizedBox(height: 25),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 4,
          runSpacing: 4,
          children: [
            Text(
              'Already have an account? ',
              style: TextStyle(color: subtitleColor, fontSize: 15),
            ),
            GestureDetector(
              onTap: widget.onSwitchToLogin,
              child: Text(
                'Login Here',
                style: TextStyle(
                  color: widget.pesoGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _stepIndicator(Color color) => Container(
    width: 30,
    height: 4,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(2),
    ),
  );

  Widget _buildTextField(
    String hint,
    IconData? icon,
    TextEditingController controller,
    Color background,
    Color borderColor,
    Color textColor,
    Color hintColor, {
    bool isPassword = false,
    TextInputType? keyboardType,
    String? helperText,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      key: isPassword ? const Key('registration-password-field') : null,
      controller: controller,
      obscureText: isPassword && _obscurePassword,
      keyboardType: isPassword ? TextInputType.visiblePassword : keyboardType,
      inputFormatters: inputFormatters,
      textInputAction: isPassword ? TextInputAction.done : TextInputAction.next,
      autocorrect: false,
      enableSuggestions: !isPassword,
      enableInteractiveSelection: true,
      autofillHints: isPassword ? const [AutofillHints.newPassword] : null,
      style: TextStyle(color: textColor, fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: hintColor),
        helperText: helperText,
        helperStyle: TextStyle(color: hintColor, fontSize: 11),
        prefixIcon: icon != null
            ? Icon(icon, color: hintColor, size: 22)
            : null,
        filled: true,
        fillColor: background,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: widget.pesoGreen, width: 2),
        ),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: hintColor,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              )
            : null,
      ),
    );
  }
}
