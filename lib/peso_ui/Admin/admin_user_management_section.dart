import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../peso_services/app_toast.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../peso_services/peso_api_client.dart';

/// Admin manages Firebase Authentication accounts joined with MongoDB PESO profiles.
class AdminUserManagementSection extends StatefulWidget {
  const AdminUserManagementSection({super.key});
  @override
  State<AdminUserManagementSection> createState() =>
      _AdminUserManagementSectionState();
}

class _AdminUserManagementSectionState
    extends State<AdminUserManagementSection> {
  // Color constants
  static const _blue = Color(0xFF2563EB);
  static const _muted = Color(0xFF64748B);
  static const _line = Color(0xFFE2E8F0);
  static const _red = Color(0xFFE11D48);
  static const _green = Color(0xFF059669);

  // Status badge colors
  static const Color _matchedBg = Color(0xFF10B981); // emerald-600
  static const Color _underReviewBg = Color(0xFF06B6D4); // sky-600
  static const Color _pendingBg = Color(0xFFF59E0B); // amber-600
  static const Color _rejectedBg = Color(0xFFEF4444); // red-600
  static const Color _badgeText = Color(0xFFFFFFFF); // white

  static const int _pageSize = 100;
  final TextEditingController _searchController = TextEditingController();
  final List<Map<String, dynamic>> _users = [];
  final List<Map<String, dynamic>> _applications = [];
  String? _nextPageToken;
  String? _error;
  bool? _profileStoreReady;
  bool? _firebaseAuthSyncAvailable;
  bool _loading = true;
  bool _loadingMore = false;
  final Set<String> _busyUsers = <String>{};

  // Map of uid -> application data for merged user+application fields
  Map<String, Map<String, dynamic>> _userApplicationMap = {};

  @override
  void initState() {
    super.initState();
    _loadUsers(reset: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers({required bool reset}) async {
    setState(() {
      if (reset) {
        _users.clear();
        _nextPageToken = null;
        _profileStoreReady = null;
        _firebaseAuthSyncAvailable = null;
        _error = null;
      } else {
        _loadingMore = true;
      }
    });
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (mounted) {
          setState(
            () => _error = 'Sign in with your administrator Google account to load registered accounts.',
          );
        }
        return;
      }
      final response = await PesoApiClient.adminListUsers(
        limit: _pageSize,
        pageToken: reset ? null : _nextPageToken,
      );
      final loaded = (response['users'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (!mounted) return;
      setState(() {
        if (reset) _users.clear();
        _users.addAll(loaded);
        _nextPageToken = response['nextPageToken'] as String?;
        _profileStoreReady = response['mongoDbConnected'] == true;
        _firebaseAuthSyncAvailable =
            response['authProviderMutationsAvailable'] == true;
      });
      // After loading users, load applications and build map
      if (reset) {
        await _loadApplications();
      }
    } on PesoApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
      debugPrint('[ADMIN_USERS] API load failed: ' + error.code);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = 'Could not load accounts from the PESO API. Check the backend and MongoDB configuration, then retry.',
        );
      }
      debugPrint('[ADMIN_USERS] API load failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _loadApplications() async {
    setState(() {
      _error = null;
    });
    try {
      final response = await PesoApiClient.adminListApplications(
        limit: _pageSize,
      );
      final records = response['applications'] as List<dynamic>? ?? const [];
      final loaded = records
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (!mounted) return;
      setState(() {
        _applications.clear();
        _applications.addAll(loaded);
        _buildApplicationMap();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is PesoApiException
            ? error.message
            : 'Could not load job applications.';
      });
      debugPrint('[ADMIN_APPLICATIONS] API load failed: $error');
    } finally {
      // _loading is managed by _loadUsers; just ensure state is consistent
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _buildApplicationMap() {
    _userApplicationMap = {};
    for (final user in _users) {
      final uid = _text(user['uid']);
      if (uid.isEmpty) continue;

      // Find the user's application(s) - match by uid or applicantUid
      Map<String, dynamic>? app;
      for (final candidate in _applications) {
        if (_text(candidate['uid']) == uid ||
            _text(candidate['applicantUid']) == uid ||
            _text(candidate['applicantEmail']) == _text(user['email'])) {
          app = candidate;
          break;
        }
      }

      if (app != null) {
        _userApplicationMap[uid] = {
          'barangay': _text(user['location']),
          'targetJob': _text(app['professionalTitle']).isNotEmpty
              ? _text(app['professionalTitle'])
              : _text(app['jobTitle']),
          'registeredDate': _text(app['createdAt']).isNotEmpty
              ? _text(app['createdAt'])
              : _text(user['createdAt']),
          'yearsExperience': _text(user['yearsExperience']),
          'matchStatus': _text(app['matchStatus']),
        };
      } else {
        // No application found for this user
        _userApplicationMap[uid] = {
          'barangay': _text(user['location']),
          'targetJob': _text(user['professionalTitle']),
          'registeredDate': _text(user['createdAt']),
          'yearsExperience': _text(user['yearsExperience']),
          'matchStatus': 'pending',
        };
      }
    }
    // Rebuild table rows to reflect the new merged data
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openResume(Map<String, dynamic> user) async {
    final uid = _text(user['uid']).trim();
    if (uid.isEmpty) return;
    try {
      final response = await PesoApiClient.adminCreateResumeLink(uid);
      final url = (response['url'] ?? response['resumeUrl'])?.toString();
      final uri = Uri.tryParse(url ?? '');
      if (!mounted) return;
      if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
        _toast(
          'No accessible resume link was returned for this account.',
          error: true,
        );
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('View applicant resume'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Text(
              'A short-lived, private document link is ready for ' +
                  _displayName(user) +
                  '. Open the resume in a new browser tab to inspect the original file.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () async {
                final opened = await launchUrl(
                  uri,
                  mode: LaunchMode.platformDefault,
                  webOnlyWindowName: '_blank',
                );
                if (dialogContext.mounted && opened)
                  Navigator.pop(dialogContext);
                if (mounted && !opened) {
                  _toast(
                    'The browser blocked the resume tab. Allow popups and retry.',
                    error: true,
                  );
                }
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open resume'),
            ),
          ],
        ),
      );
    } on PesoApiException catch (error) {
      if (mounted)
        _toast(
          error.code == 'resume_not_found'
              ? 'This applicant has not uploaded a viewable resume document yet.'
              : _friendlyError(error),
          error: true,
        );
    } catch (error) {
      if (mounted)
        _toast('Could not open this resume. Check the PESO API.', error: true);
      debugPrint('[ADMIN_USERS] Resume link failed: $error');
    }
  }

  String _text(Object? value) => value?.toString() ?? '';

  String _displayDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;

    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[date.month - 1] +
        ' ' +
        date.day.toString() +
        ', ' +
        date.year.toString();
  }

  // _friendlyError, _displayName, _profileUpdate, _updateUser, _editUser,
  // _protected, _toggleDisabled, _deleteUser, _toast remain unchanged from original
  // (omitted for brevity - they are the same as in the original file)

  String _friendlyError(PesoApiException error) {
    if (error.code == 'admin_required' || error.code == 'unauthenticated') {
      return 'This action requires a PESO admin role stored in MongoDB.';
    }
    if (error.code == 'mongodb_not_ready') {
      return 'The PESO API is reachable, but MongoDB is not connected. Configure backend/.env and Atlas Network Access.';
    }
    return error.message;
  }

  String _displayName(Map<String, dynamic> user) {
    final name = _text(user['displayName']).trim();
    if (name.isNotEmpty) return name;
    final combined =
        _text(user['firstName']).trim() + ' ' + _text(user['lastName']).trim();
    return combined.trim().isNotEmpty
        ? combined.trim()
        : _text(user['email']).ifEmpty('Unnamed account');
  }

  List<Map<String, dynamic>> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return List.of(_users);
    return _users
        .where(
          (user) =>
              _displayName(user).toLowerCase().contains(query) ||
              _text(user['email']).toLowerCase().contains(query) ||
              _text(user['uid']).toLowerCase().contains(query),
        )
        .toList();
  }

  Map<String, dynamic> _profileUpdate(
    Map<String, dynamic> user, {
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? location,
    String? educationLevel,
    String? employmentStatus,
    String? professionalTitle,
    String? bio,
  }) {
    final first = firstName ?? _text(user['firstName']);
    final last = lastName ?? _text(user['lastName']);
    return <String, dynamic>{
      'firstName': first,
      'lastName': last,
      'displayName': '$first $last'.trim(),
      'phoneNumber': phoneNumber ?? _text(user['phoneNumber']),
      'location': location ?? _text(user['location']),
      'educationLevel': educationLevel ?? _text(user['educationLevel']),
      'employmentStatus': employmentStatus ?? _text(user['employmentStatus']),
      'professionalTitle':
          professionalTitle ?? _text(user['professionalTitle']),
      'bio': bio ?? _text(user['bio']),
    };
  }

  Future<void> _updateUser(
    Map<String, dynamic> user,
    Map<String, dynamic> payload, {
    required String successMessage,
  }) async {
    final uid = _text(user['uid']);
    if (uid.isEmpty || _busyUsers.contains(uid)) return;
    setState(() {
      _busyUsers.add(uid);
      _error = null;
    });
    try {
      final response = await PesoApiClient.adminUpdateProfile(uid, payload);
      final serverUser = response['user'];
      if (!mounted) return;
      final index = _users.indexWhere((item) => _text(item['uid']) == uid);
      if (index >= 0) {
        final updated = Map<String, dynamic>.from(_users[index])
          ..addAll(payload);
        if (serverUser is Map)
          updated.addAll(Map<String, dynamic>.from(serverUser));
        setState(() => _users[index] = updated);
      }
      _toast(successMessage);
    } on PesoApiException catch (error) {
      if (mounted) _toast(_friendlyError(error), error: true);
      debugPrint('[ADMIN_USERS] API profile update failed: ' + error.code);
    } catch (error) {
      if (mounted)
        _toast(
          'Could not update this profile. Check the PESO API and retry.',
          error: true,
        );
      debugPrint('[ADMIN_USERS] API profile update failed: $error');
    } finally {
      if (mounted) setState(() => _busyUsers.remove(uid));
    }
  }

  Future<void> _editUser(Map<String, dynamic> user) async {
    if (_protected(user)) return;
    const fields = <String, String>{
      'firstName': 'First name',
      'lastName': 'Last name',
      'phoneNumber': 'Phone number',
      'location': 'Location / barangay',
      'educationLevel': 'Education level',
      'employmentStatus': 'Employment status',
      'professionalTitle': 'Professional title',
      'bio': 'Bio',
    };
    final controllers = <String, TextEditingController>{
      for (final key in fields.keys)
        key: TextEditingController(text: _text(user[key])),
    };
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit user profile'),
        content: SizedBox(
          width: (MediaQuery.sizeOf(context).width - 96)
              .clamp(240.0, 560.0)
              .toDouble(),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final entry in fields.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: controllers[entry.key],
                        keyboardType: entry.key == 'email'
                            ? TextInputType.emailAddress
                            : entry.key == 'phoneNumber'
                            ? TextInputType.phone
                            : TextInputType.text,
                        maxLines: entry.key == 'bio' ? 3 : 1,
                        decoration: InputDecoration(
                          labelText: entry.value,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        validator: (value) {
                          final text = (value ?? '').trim();
                          if ((entry.key == 'firstName' ||
                                  entry.key == 'lastName' ||
                                  entry.key == 'email') &&
                              text.isEmpty) {
                            return entry.value + ' is required.';
                          }
                          if (entry.key == 'email' &&
                              !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                  .hasMatch(text)) {
                            return 'Enter a valid email.';
                          }
                          return null;
                        },
                      ),
                    ),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Role and account ID are protected and cannot be edited here.',
                      style: TextStyle(fontSize: 12, color: _muted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.pop(dialogContext, <String, String>{
                for (final entry in controllers.entries)
                  entry.key: entry.value.text.trim(),
              });
            },
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('Save changes'),
          ),
        ],
      ),
    );
    for (final controller in controllers.values) {
      controller.dispose();
    }
    if (result == null || !mounted) return;
    await _updateUser(
      user,
      _profileUpdate(
        user,
        firstName: result['firstName'],
        lastName: result['lastName'],
        phoneNumber: result['phoneNumber'],
        location: result['location'],
        educationLevel: result['educationLevel'],
        employmentStatus: result['employmentStatus'],
        professionalTitle: result['professionalTitle'],
        bio: result['bio'],
      ),
      successMessage: 'User information updated.',
    );
  }

  bool _protected(Map<String, dynamic> user) {
    final uid = _text(user['uid']);
    return user['role'] == 'admin' ||
        user['customAdmin'] == true ||
        uid == FirebaseAuth.instance.currentUser?.uid;
  }

  Future<void> _toggleDisabled(Map<String, dynamic> user) async {
    if (_protected(user)) return;
    final uid = _text(user['uid']);
    if (uid.isEmpty || _busyUsers.contains(uid)) return;
    final disabled = user['disabled'] != true;
    setState(() {
      _busyUsers.add(uid);
      _error = null;
    });
    try {
      final response = await PesoApiClient.adminSetDisabled(
        uid,
        disabled: disabled,
      );
      final serverUser = response['user'];
      final index = _users.indexWhere((item) => _text(item['uid']) == uid);
      if (index >= 0 && mounted) {
        final updated = Map<String, dynamic>.from(_users[index])
          ..['disabled'] = disabled;
        if (serverUser is Map)
          updated.addAll(Map<String, dynamic>.from(serverUser));
        setState(() => _users[index] = updated);
      }
      if (mounted)
        _toast(disabled ? 'PESO access disabled.' : 'PESO access restored.');
    } on PesoApiException catch (error) {
      if (mounted) _toast(_friendlyError(error), error: true);
    } catch (error) {
      if (mounted)
        _toast(
          'Could not change PESO access. Check the PESO API.',
          error: true,
        );
      debugPrint('[ADMIN_USERS] API status update failed: $error');
    } finally {
      if (mounted) setState(() => _busyUsers.remove(uid));
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    if (_protected(user)) return;
    final uid = _text(user['uid']);
    if (uid.isEmpty || _busyUsers.contains(uid)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: _red, size: 32),
        title: const Text('Remove this PESO account?'),
        content: Text(
          'This permanently removes the Firebase sign-in account, clears its PESO profile, and deletes stored documents for ' +
              _displayName(user) +
              ' (' +
              _text(user['email']) +
              '). If Firebase deletion cannot be verified, PESO access is revoked, private profile fields are scrubbed, and the pending deletion stays visible here for retry. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete Firebase account'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busyUsers.add(uid);
      _error = null;
    });
    try {
      final response = await PesoApiClient.adminDeleteUser(uid);
      if (!mounted) return;
      setState(() => _users.removeWhere((item) => _text(item['uid']) == uid));
      _toast(
        response['firebaseAuthAccountDeleted'] == true &&
                response['cleanupComplete'] == true
            ? 'Firebase sign-in account deleted and PESO data cleanup completed.'
            : 'Firebase account deleted, but some document cleanup needs review.',
        error:
            response['firebaseAuthAccountDeleted'] != true ||
            response['cleanupComplete'] != true,
      );
    } on PesoApiException catch (error) {
      if (mounted &&
          (error.code == 'firebase_auth_delete_failed' ||
              error.code == 'account_cleanup_pending')) {
        await _loadUsers(reset: true);
      }
      if (mounted) _toast(_friendlyError(error), error: true);
    } catch (error) {
      if (mounted)
        _toast(
          'Could not delete this account. Check the PESO API and retry.',
          error: true,
        );
      debugPrint('[ADMIN_USERS] API delete failed: $error');
    } finally {
      if (mounted) setState(() => _busyUsers.remove(uid));
    }
  }

  void _toast(String message, {bool error = false}) {
    error
        ? AppToast.error(context, message)
        : AppToast.success(context, message);
  }

  // Helper to get application data for a user
  Map<String, dynamic> _getApplicationData(Map<String, dynamic> user) {
    final uid = _text(user['uid']);
    return _userApplicationMap[uid] ??
        {
          'barangay': _text(user['location']),
          'targetJob': _text(user['professionalTitle']),
          'registeredDate': _text(user['createdAt']),
          'yearsExperience': _text(user['yearsExperience']),
          'matchStatus': 'pending',
        };
  }

  // Status badge widget
  Widget _statusBadge(String matchStatus) {
    final lower = matchStatus.toLowerCase();
    Color bg;
    Color text;
    switch (lower) {
      case 'matched':
        bg = _matchedBg;
        text = _badgeText;
        break;
      case 'under_review':
      case 'under review':
        bg = _underReviewBg;
        text = _badgeText;
        break;
      case 'pending':
        bg = _pendingBg;
        text = _badgeText;
        break;
      case 'rejected':
        bg = _rejectedBg;
        text = _badgeText;
        break;
      default:
        bg = _muted;
        text = Colors.white;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _capitalize(matchStatus.replaceAll('_', ' ')),
        style: TextStyle(
          color: text,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // Capitalize first letter
  String _capitalize(String s) =>
      s.isNotEmpty ? s[0].toUpperCase() + s.substring(1).toLowerCase() : s;

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final viewportWidth = MediaQuery.sizeOf(context).width;

    // Header subtitle helper
    Widget subHeader(String text) => Text(
      text,
      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header: "Job Applicants" with subtitle
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Job Applicants',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              subHeader('Manage and review all job applicants'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: viewportWidth < 420
                  ? (viewportWidth - 64).clamp(220.0, 320.0).toDouble()
                  : 320.0,
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Search registered users',
                  hintText: 'Name, email, or account ID',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _loading ? null : () => _loadUsers(reset: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
            Text(
              _users.length.toString() + ' account(s) loaded',
              style: const TextStyle(
                color: _muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Warning boxes (existing logic preserved)
        if (_firebaseAuthSyncAvailable == false)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDBA74)),
            ),
            child: const Text(
              'Firebase Auth synchronization is unavailable. This list currently shows MongoDB profiles only; accounts that still exist in Firebase but have no MongoDB profile cannot be listed or deleted until Firebase Admin credentials are configured on the API.',
              style: TextStyle(color: Color(0xFF9A3412), height: 1.35),
            ),
          ),
        if (_profileStoreReady == false)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDBA74)),
            ),
            child: const Text(
              'MongoDB is not connected. PESO profiles, profile edits, access-status changes, and deletion cleanup are unavailable until the Atlas connection is restored.',
              style: TextStyle(color: Color(0xFF9A3412), height: 1.35),
            ),
          ),
        if (_error != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDA4AF)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: _red),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_error!, style: const TextStyle(color: _red)),
                ),
                TextButton(
                  onPressed: () => _loadUsers(reset: true),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        // DataTable section
        Expanded(
          child: _loading && _users.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _users.isEmpty && _error == null
              ? const Center(
                  child: Text(
                    'No accounts were returned from the available Firebase/MongoDB account source. Check any sync warning above if you expected registered users.',
                  ),
                )
              : filtered.isEmpty
              ? const Center(child: Text('No accounts match that search.'))
              : Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: _line),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: const WidgetStatePropertyAll(
                          Color(0xFFF1F5F9),
                        ),
                        columns: const [
                          DataColumn(
                            label: SizedBox(
                              width: 180,
                              child: Text(
                                'Registered user',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          DataColumn(
                            label: SizedBox(
                              width: 180,
                              child: Text(
                                'Email',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          DataColumn(
                            label: SizedBox(
                              width: 120,
                              child: Text(
                                'Phone',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          // NEW columns
                          DataColumn(
                            label: SizedBox(
                              width: 130,
                              child: Text(
                                'Barangay',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          DataColumn(
                            label: SizedBox(
                              width: 150,
                              child: Text(
                                'Target job',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          DataColumn(
                            label: SizedBox(
                              width: 130,
                              child: Text(
                                'Registered date',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          DataColumn(
                            label: SizedBox(
                              width: 120,
                              child: Text(
                                'Work exp (yrs)',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          DataColumn(
                            label: SizedBox(
                              width: 120,
                              child: Text(
                                'App status',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          DataColumn(
                            label: SizedBox(
                              width: 120,
                              child: Text(
                                'Resume',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          DataColumn(
                            label: SizedBox(
                              width: 130,
                              child: Text(
                                'Last sign-in',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          DataColumn(
                            label: SizedBox(
                              width: 120,
                              child: Text(
                                'Role',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          DataColumn(
                            label: SizedBox(
                              width: 120,
                              child: Text(
                                'PESO access',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          DataColumn(
                            label: SizedBox(
                              width: 140,
                              child: Text(
                                'Actions',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                        rows: filtered.map((user) {
                          final uid = _text(user['uid']);
                          final appData = _getApplicationData(user);
                          final busy = _busyUsers.contains(uid);
                          final protected = _protected(user);
                          final profileStoreReady = _profileStoreReady == true;
                          final profileMissing = user['profileMissing'] == true;
                          final deletionPending =
                              user['deletionPending'] == true ||
                              user['deleted'] == true;
                          final role = _text(user['role'])
                              .ifEmpty('job_seeker');
                          final isAdministrator =
                              role == 'admin' || user['customAdmin'] == true;
                          return DataRow(
                            cells: [
                              // Registered user cell
                              DataCell(
                                SizedBox(
                                  width: 180,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _displayName(user),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        uid,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: _muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Email cell
                              DataCell(
                                SizedBox(
                                  width: 180,
                                  child: Text(
                                    _text(user['email']),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              // Phone cell
                              DataCell(
                                Text(_text(user['phoneNumber']).ifEmpty('—')),
                              ),
                              // Barangay cell (NEW)
                              DataCell(
                                SizedBox(
                                  width: 130,
                                  child: Text(
                                    appData['barangay'],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              ),
                              // Target job cell (NEW)
                              DataCell(
                                SizedBox(
                                  width: 150,
                                  child: Text(
                                    appData['targetJob'],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              ),
                              // Registered date cell (NEW)
                              DataCell(
                                SizedBox(
                                  width: 130,
                                  child: appData['registeredDate'].isNotEmpty
                                      ? Text(
                                          _displayDate(
                                            appData['registeredDate'],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 11),
                                        )
                                      : const Text(
                                          '—',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: _muted,
                                          ),
                                        ),
                                ),
                              ),
                              // Work experience years cell (NEW)
                              DataCell(
                                SizedBox(
                                  width: 120,
                                  child: appData['yearsExperience'].isNotEmpty
                                      ? Text(
                                          _text(appData['yearsExperience']),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        )
                                      : const Text(
                                          '0',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: _muted,
                                          ),
                                        ),
                                ),
                              ),
                              // Application status cell (NEW) - status badge
                              DataCell(
                                SizedBox(
                                  width: 120,
                                  child: _statusBadge(appData['matchStatus']),
                                ),
                              ),
                              // Viewing is read-only; mutation protection does not
                              // prevent authorized admins from inspecting a resume.
                              DataCell(
                                SizedBox(
                                  width: 120,
                                  child: IconButton(
                                    tooltip: 'View resume',
                                    icon: const Icon(
                                      Icons.description_outlined,
                                      color: _blue,
                                      size: 22,
                                    ),
                                    onPressed:
                                        !profileStoreReady ||
                                            _text(user['uid']).isEmpty
                                        ? null
                                        : () => _openResume(user),
                                  ),
                                ),
                              ),
                              // Last sign-in cell
                              DataCell(
                                Text(
                                  _text(user['lastSignInAt']).ifEmpty('Never'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: _muted,
                                  ),
                                ),
                              ),
                              // Role cell
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isAdministrator
                                        ? const Color(0xFFEFF6FF)
                                        : const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    isAdministrator
                                        ? 'Administrator'
                                        : 'Job seeker',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isAdministrator ? _blue : _green,
                                    ),
                                  ),
                                ),
                              ),
                              // PESO access cell
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        deletionPending ||
                                            user['disabled'] == true
                                        ? const Color(0xFFFFF7ED)
                                        : const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    deletionPending
                                        ? 'Deletion pending'
                                        : user['disabled'] == true
                                        ? 'Disabled'
                                        : 'Active',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color:
                                          deletionPending ||
                                              user['disabled'] == true
                                          ? const Color(0xFFB45309)
                                          : _green,
                                    ),
                                  ),
                                ),
                              ),
                              // Actions cell
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: protected
                                          ? 'Protected administrator profile'
                                          : deletionPending
                                          ? 'Deletion is pending; retry cleanup instead of editing'
                                          : profileMissing
                                          ? 'No MongoDB profile is available to edit'
                                          : !profileStoreReady
                                          ? 'MongoDB profile data is unavailable'
                                          : 'Edit profile',
                                      onPressed:
                                          busy ||
                                              protected ||
                                              profileMissing ||
                                              deletionPending ||
                                              !profileStoreReady
                                          ? null
                                          : () => _editUser(user),
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 19,
                                        color: _blue,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: protected
                                          ? 'Protected administrator PESO access'
                                          : deletionPending
                                          ? 'Deletion is pending; retry cleanup instead'
                                          : profileMissing
                                          ? 'No MongoDB profile exists; delete the Firebase-only account instead'
                                          : (user['disabled'] == true
                                                ? 'Restore PESO access'
                                                : 'Disable PESO access'),
                                      onPressed:
                                          busy ||
                                              protected ||
                                              profileMissing ||
                                              deletionPending ||
                                              !profileStoreReady
                                          ? null
                                          : () => _toggleDisabled(user),
                                      icon: Icon(
                                        Icons.lock_outline,
                                        size: 19,
                                        color: Color(0xFFD97706),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: protected
                                          ? 'Protected administrator account'
                                          : deletionPending
                                          ? 'Retry pending Firebase/document cleanup'
                                          : profileMissing
                                          ? 'Delete the Firebase-only account'
                                          : !profileStoreReady
                                          ? 'Reconnect MongoDB before deleting the account'
                                          : 'Delete Firebase account and PESO data',
                                      onPressed:
                                          busy ||
                                              protected ||
                                              !profileStoreReady
                                          ? null
                                          : () => _deleteUser(user),
                                      icon: Icon(
                                        Icons.delete_outline,
                                        size: 19,
                                        color: _red,
                                      ),
                                    ),
                                    if (busy)
                                      const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
        ),
        if (_nextPageToken != null)
          Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton.icon(
                onPressed: _loadingMore ? null : () => _loadUsers(reset: false),
                icon: _loadingMore
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more),
                label: Text(
                  _loadingMore ? 'Loading more...' : 'Load more profiles',
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// Helper extension on String
extension on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}

// Capitalize first letter of a string
String capitalize(String s) =>
    s.isNotEmpty ? s[0].toUpperCase() + s.substring(1).toLowerCase() : s;
