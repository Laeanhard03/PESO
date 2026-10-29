import 'package:flutter/material.dart';

import '../../peso_services/app_toast.dart';
import '../../peso_services/peso_api_client.dart';

const _adminGreen = Color(0xFF236349);
const _adminDark = Color(0xFF193D31);
const _adminMuted = Color(0xFF64748B);
const _adminBorder = Color(0xFFE2E8F0);
const _adminRed = Color(0xFFBE123C);

/// Administrator profile and account lifecycle controls.
/// The parent performs server-side deletion and ends the Firebase session.
class AdminProfileSection extends StatefulWidget {
  final String displayName;
  final String email;
  final String uid;
  final bool emailVerified;
  final String signInProvider;
  final Future<void> Function() onDeleteAccount;

  const AdminProfileSection({
    super.key,
    required this.displayName,
    required this.email,
    required this.uid,
    required this.emailVerified,
    required this.signInProvider,
    required this.onDeleteAccount,
  });

  @override
  State<AdminProfileSection> createState() => _AdminProfileSectionState();
}

class _AdminProfileSectionState extends State<AdminProfileSection> {
  bool _deleting = false;

  Future<void> _confirmDeleteAccount() async {
    if (_deleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: _adminRed,
          size: 34,
        ),
        title: const Text('Delete your administrator account?'),
        content: const Text(
          'Are you sure you want to delete your account? Your Firebase Authentication account and PESO profile will be permanently deleted, your administrator access will be revoked, and your stored documents will be removed where possible. You will be signed out. This cannot be undone. If document cleanup is incomplete, the pending cleanup will remain available for another administrator to retry.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: _adminRed),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Delete my account'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await widget.onDeleteAccount();
    } on PesoApiException catch (error) {
      if (mounted) AppToast.error(context, error.message);
    } catch (_) {
      if (mounted) {
        AppToast.error(
          context,
          'The account could not be deleted yet. Check the PESO API and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.displayName.trim().isEmpty
        ? 'PESO Administrator'
        : widget.displayName.trim();
    final email = widget.email.trim().isEmpty
        ? 'No email available'
        : widget.email.trim();

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _AccountPageHeading(
                icon: Icons.person_outline,
                title: 'My Administrator Profile',
                subtitle: 'Review your sign-in identity and manage your own PESO account.',
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _adminBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: const Color(0xFFE8F5EE),
                      child: Text(
                        name.isNotEmpty
                            ? name.substring(0, 1).toUpperCase()
                            : 'A',
                        style: const TextStyle(
                          color: _adminGreen,
                          fontWeight: FontWeight.w900,
                          fontSize: 25,
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: _adminDark,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            email,
                            style: const TextStyle(color: _adminMuted),
                          ),
                          const SizedBox(height: 10),
                          const _AccountRoleChip(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _AccountInfoCard(
                title: 'Account information',
                icon: Icons.verified_user_outlined,
                rows: [
                  _AccountInfoRow(
                    label: 'Account role',
                    value: 'Administrator',
                    icon: Icons.admin_panel_settings_outlined,
                  ),
                  _AccountInfoRow(
                    label: 'Email verification',
                    value: widget.emailVerified ? 'Verified' : 'Not verified',
                    icon: widget.emailVerified
                        ? Icons.mark_email_read_outlined
                        : Icons.mark_email_unread_outlined,
                  ),
                  _AccountInfoRow(
                    label: 'Sign-in provider',
                    value: _providerLabel(widget.signInProvider),
                    icon: Icons.login_outlined,
                  ),
                  _AccountInfoRow(
                    label: 'Firebase user ID',
                    value: widget.uid.isEmpty ? 'Unavailable' : widget.uid,
                    icon: Icons.fingerprint_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7F7),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: _adminRed),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Danger zone',
                            style: TextStyle(
                              color: _adminRed,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Delete your own account and Firebase sign-in. You will immediately lose access to the Admin Portal. If Firebase deletion temporarily fails, your PESO access will remain revoked and you can retry this action from this page.',
                      style: TextStyle(color: Color(0xFF7F1D1D), height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: _deleting || widget.uid.trim().isEmpty
                            ? null
                            : _confirmDeleteAccount,
                        style: FilledButton.styleFrom(
                          backgroundColor: _adminRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                        ),
                        icon: _deleting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.delete_outline),
                        label: Text(
                          _deleting
                              ? 'Deleting account...'
                              : 'Delete your account',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Real, non-destructive settings page. Account deletion is intentionally kept
/// on the dedicated Profile page so users can see the full destructive warning.
class AdminSettingsSection extends StatelessWidget {
  final String email;
  final bool emailVerified;
  final String signInProvider;
  final VoidCallback onOpenProfile;
  final Future<void> Function() onSignOut;

  const AdminSettingsSection({
    super.key,
    required this.email,
    required this.emailVerified,
    required this.signInProvider,
    required this.onOpenProfile,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final accountEmail = email.trim().isEmpty
        ? 'No email available'
        : email.trim();
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _AccountPageHeading(
                icon: Icons.settings_outlined,
                title: 'Admin Settings',
                subtitle:
                    'Manage your administrator session and account access.',
              ),
              const SizedBox(height: 20),
              _AccountInfoCard(
                title: 'Security and session',
                icon: Icons.shield_outlined,
                rows: [
                  _AccountInfoRow(
                    label: 'Signed-in account',
                    value: accountEmail,
                    icon: Icons.email_outlined,
                  ),
                  _AccountInfoRow(
                    label: 'Email verification',
                    value: emailVerified ? 'Verified' : 'Not verified',
                    icon: emailVerified
                        ? Icons.verified_outlined
                        : Icons.error_outline,
                  ),
                  _AccountInfoRow(
                    label: 'Authentication provider',
                    value: _providerLabel(signInProvider),
                    icon: Icons.login_outlined,
                  ),
                  const _AccountInfoRow(
                    label: 'Authorization source',
                    value: 'PESO administrator role in MongoDB',
                    icon: Icons.admin_panel_settings_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _AccountInfoCard(
                title: 'Account actions',
                icon: Icons.manage_accounts_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Update your account details or permanently remove your own administrator account from the Profile page.',
                      style: TextStyle(color: _adminMuted, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: onOpenProfile,
                          icon: const Icon(Icons.person_outline),
                          label: const Text('Open my profile'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => onSignOut(),
                          icon: const Icon(Icons.logout),
                          label: const Text('Sign out'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _adminBorder),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: _adminGreen),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Administrator access is verified by the PESO API. Changes to role permissions and account deletion are performed server-side; this page does not store administrator credentials in the browser.',
                        style: TextStyle(color: _adminMuted, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountPageHeading extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _AccountPageHeading({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5EE),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: _adminGreen, size: 25),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: _adminDark,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: const TextStyle(color: _adminMuted, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountInfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_AccountInfoRow> rows;
  final Widget? child;

  const _AccountInfoCard({
    required this.title,
    required this.icon,
    this.rows = const [],
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _adminBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _adminGreen),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: _adminDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (rows.isNotEmpty)
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: row,
              ),
            ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class _AccountInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _AccountInfoRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: _adminMuted),
        const SizedBox(width: 10),
        SizedBox(
          width: 170,
          child: Text(
            label,
            style: const TextStyle(
              color: _adminMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(
              color: _adminDark,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _AccountRoleChip extends StatelessWidget {
  const _AccountRoleChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5EE),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_user_outlined, size: 15, color: _adminGreen),
          SizedBox(width: 6),
          Text(
            'Administrator',
            style: TextStyle(
              color: _adminGreen,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

String _providerLabel(String providerId) {
  return switch (providerId.trim().toLowerCase()) {
    'google.com' => 'Google',
    'password' => 'Email and password',
    'phone' => 'Phone',
    'facebook.com' => 'Facebook',
    'apple.com' => 'Apple',
    '' || 'unknown' => 'Unknown',
    final provider => provider,
  };
}
