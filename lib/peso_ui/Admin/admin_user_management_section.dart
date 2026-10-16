import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Live Firebase Authentication + Firestore user management.
/// Privileged actions are checked again by callable functions.
class AdminUserManagementSection extends StatefulWidget {
  const AdminUserManagementSection({super.key});
  @override
  State<AdminUserManagementSection> createState() => _AdminUserManagementSectionState();
}

class _AdminUserManagementSectionState extends State<AdminUserManagementSection> {
  static const _blue = Color(0xFF2563EB);
  static const _muted = Color(0xFF64748B);
  static const _line = Color(0xFFE2E8F0);
  static const _red = Color(0xFFE11D48);
  static const _green = Color(0xFF059669);

  late final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  final TextEditingController _searchController = TextEditingController();
  final List<Map<String, dynamic>> _users = [];
  String? _nextPageToken;
  String? _error;
  bool _loading = true;
  bool _loadingMore = false;
  final Set<String> _busyUsers = <String>{};

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
        _loading = true;
        _nextPageToken = null;
      } else {
        _loadingMore = true;
      }
      _error = null;
    });
    try {
      final response = await _functions.httpsCallable('adminListUsers').call(<String, dynamic>{
        if (!reset && _nextPageToken != null) 'pageToken': _nextPageToken,
      });
      final data = Map<String, dynamic>.from(response.data as Map);
      final loaded = (data['users'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item)).toList();
      if (!mounted) return;
      setState(() {
        if (reset) _users.clear();
        _users.addAll(loaded);
        _nextPageToken = data['nextPageToken'] as String?;
      });
    } on FirebaseFunctionsException catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not load registered accounts. Check your connection and retry.');
      debugPrint('[ADMIN_USERS] load failed: $error');
    } finally {
      if (mounted) setState(() { _loading = false; _loadingMore = false; });
    }
  }

  String _friendlyError(FirebaseFunctionsException error) {
    if (error.code == 'permission-denied' || error.code == 'unauthenticated') {
      return 'This action requires the verified Firebase admin custom claim. Contact the project owner if you believe you should have access.';
    }
    if (error.code == 'unavailable' || error.code == 'deadline-exceeded') {
      return 'The account service is temporarily unavailable. Retry in a moment.';
    }
    return error.message ?? 'The account service could not complete the request.';
  }

  String _text(Object? value) => value?.toString() ?? '';

  String _displayName(Map<String, dynamic> user) {
    final name = _text(user['displayName']).trim();
    if (name.isNotEmpty) return name;
    final combined = _text(user['firstName']).trim() + ' ' + _text(user['lastName']).trim();
    return combined.trim().isNotEmpty ? combined.trim() : _text(user['email']).ifEmpty('Unnamed account');
  }

  List<Map<String, dynamic>> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return List.of(_users);
    return _users.where((user) =>
      _displayName(user).toLowerCase().contains(query) ||
      _text(user['email']).toLowerCase().contains(query) ||
      _text(user['uid']).toLowerCase().contains(query)
    ).toList();
  }

  Map<String, dynamic> _payload(Map<String, dynamic> user, {
    bool? disabled, String? firstName, String? lastName, String? email,
    String? phoneNumber, String? location, String? educationLevel,
    String? employmentStatus, String? professionalTitle, String? bio,
  }) => <String, dynamic>{
    'uid': _text(user['uid']),
    'firstName': firstName ?? _text(user['firstName']),
    'lastName': lastName ?? _text(user['lastName']),
    'email': email ?? _text(user['email']),
    'phoneNumber': phoneNumber ?? _text(user['phoneNumber']),
    'location': location ?? _text(user['location']),
    'educationLevel': educationLevel ?? _text(user['educationLevel']),
    'employmentStatus': employmentStatus ?? _text(user['employmentStatus']),
    'professionalTitle': professionalTitle ?? _text(user['professionalTitle']),
    'bio': bio ?? _text(user['bio']),
    'disabled': disabled ?? (user['disabled'] == true),
  };

  Future<void> _updateUser(Map<String, dynamic> user, Map<String, dynamic> payload, {required String successMessage}) async {
    final uid = _text(user['uid']);
    if (uid.isEmpty || _busyUsers.contains(uid)) return;
    setState(() { _busyUsers.add(uid); _error = null; });
    try {
      await _functions.httpsCallable('adminUpdateUser').call(payload);
      if (!mounted) return;
      final index = _users.indexWhere((item) => _text(item['uid']) == uid);
      if (index >= 0) {
        final updated = Map<String, dynamic>.from(_users[index])..addAll(payload);
        updated['displayName'] = (_text(payload['firstName']) + ' ' + _text(payload['lastName'])).trim();
        setState(() => _users[index] = updated);
      }
      _toast(successMessage);
    } on FirebaseFunctionsException catch (error) {
      if (mounted) _toast(_friendlyError(error), error: true);
    } catch (error) {
      if (mounted) _toast('Could not update this account. Please retry.', error: true);
      debugPrint('[ADMIN_USERS] update failed: $error');
    } finally {
      if (mounted) setState(() => _busyUsers.remove(uid));
    }
  }

  Future<void> _editUser(Map<String, dynamic> user) async {
    if (_protected(user)) return;
    const fields = <String, String>{
      'firstName': 'First name',
      'lastName': 'Last name',
      'email': 'Email address',
      'phoneNumber': 'Phone number',
      'location': 'Location / barangay',
      'educationLevel': 'Education level',
      'employmentStatus': 'Employment status',
      'professionalTitle': 'Professional title',
      'bio': 'Bio',
    };
    final controllers = <String, TextEditingController>{
      for (final key in fields.keys) key: TextEditingController(text: _text(user[key])),
    };
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit registered user'),
        content: SizedBox(
          width: 560,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (final entry in fields.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      controller: controllers[entry.key],
                      keyboardType: entry.key == 'email'
                          ? TextInputType.emailAddress
                          : entry.key == 'phoneNumber' ? TextInputType.phone : TextInputType.text,
                      maxLines: entry.key == 'bio' ? 3 : 1,
                      decoration: InputDecoration(labelText: entry.value, border: const OutlineInputBorder(), isDense: true),
                      validator: (value) {
                        final text = (value ?? '').trim();
                        if ((entry.key == 'firstName' || entry.key == 'lastName' || entry.key == 'email') && text.isEmpty) {
                          return entry.value + ' is required.';
                        }
                        if (entry.key == 'email' && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) {
                          return 'Enter a valid email.';
                        }
                        return null;
                      },
                    ),
                  ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Role and account ID are protected and cannot be edited here.', style: TextStyle(fontSize: 12, color: _muted)),
                ),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton.icon(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.pop(dialogContext, <String, String>{
                for (final entry in controllers.entries) entry.key: entry.value.text.trim(),
              });
            },
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('Save changes'),
          ),
        ],
      ),
    );
    for (final controller in controllers.values) { controller.dispose(); }
    if (result == null || !mounted) return;
    await _updateUser(user, _payload(
      user,
      firstName: result['firstName'], lastName: result['lastName'],
      email: result['email'], phoneNumber: result['phoneNumber'],
      location: result['location'], educationLevel: result['educationLevel'],
      employmentStatus: result['employmentStatus'],
      professionalTitle: result['professionalTitle'], bio: result['bio'],
    ), successMessage: 'User information updated.');
  }

  bool _protected(Map<String, dynamic> user) {
    final uid = _text(user['uid']);
    return user['role'] == 'admin' || user['customAdmin'] == true ||
        uid == FirebaseAuth.instance.currentUser?.uid;
  }

  Future<void> _toggleDisabled(Map<String, dynamic> user) async {
    if (_protected(user)) return;
    final disabled = user['disabled'] != true;
    await _updateUser(user, _payload(user, disabled: disabled),
      successMessage: disabled ? 'Account disabled.' : 'Account enabled.');
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    if (_protected(user)) return;
    final uid = _text(user['uid']);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: _red, size: 32),
        title: const Text('Permanently delete this account?'),
        content: Text('This deletes ' + _displayName(user) + ' (' + _text(user['email']) + ') from Firebase Authentication and attempts to remove their profile, subcollections, and stored documents. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || uid.isEmpty) return;
    setState(() { _busyUsers.add(uid); _error = null; });
    try {
      final response = await _functions.httpsCallable('adminDeleteUser').call(<String, dynamic>{'uid': uid});
      final result = Map<String, dynamic>.from(response.data as Map);
      if (!mounted) return;
      setState(() => _users.removeWhere((item) => _text(item['uid']) == uid));
      _toast(
        result['cleanupComplete'] == true
            ? 'Account deleted and data cleanup completed.'
            : 'Account deleted. Some stored-data cleanup needs administrator review.',
        error: result['cleanupComplete'] != true,
      );
    } on FirebaseFunctionsException catch (error) {
      if (mounted) _toast(_friendlyError(error), error: true);
    } catch (error) {
      if (mounted) _toast('Could not delete this account. Please retry.', error: true);
      debugPrint('[ADMIN_USERS] delete failed: $error');
    } finally {
      if (mounted) setState(() => _busyUsers.remove(uid));
    }
  }

  void _toast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: error ? _red : _green));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(width: 320, child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Search registered users',
                hintText: 'Name, email, or account ID',
                prefixIcon: Icon(Icons.search), border: OutlineInputBorder(), isDense: true,
              ),
            )),
            OutlinedButton.icon(
              onPressed: _loading ? null : () => _loadUsers(reset: true),
              icon: const Icon(Icons.refresh), label: const Text('Refresh'),
            ),
            Text(_users.length.toString() + ' account(s) loaded', style: const TextStyle(color: _muted, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 14),
        if (_error != null)
          Container(
            width: double.infinity, margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFDA4AF))),
            child: Row(children: [
              const Icon(Icons.error_outline, color: _red), const SizedBox(width: 10),
              Expanded(child: Text(_error!, style: const TextStyle(color: _red))),
              TextButton(onPressed: () => _loadUsers(reset: true), child: const Text('Retry')),
            ]),
          ),
        Expanded(
          child: _loading && _users.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _users.isEmpty && _error == null
                  ? const Center(child: Text('No Firebase Authentication users were returned.'))
                  : filtered.isEmpty
                      ? const Center(child: Text('No accounts match that search.'))
                      : Container(
                          width: double.infinity,
                          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _line), borderRadius: BorderRadius.circular(16)),
                          child: SingleChildScrollView(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: const WidgetStatePropertyAll(Color(0xFFF1F5F9)),
                                columns: const [
                                  DataColumn(label: Text('Registered user')),
                                  DataColumn(label: Text('Email')),
                                  DataColumn(label: Text('Phone')),
                                  DataColumn(label: Text('Last sign-in')),
                                  DataColumn(label: Text('Status')),
                                  DataColumn(label: Text('Actions')),
                                ],
                                rows: filtered.map((user) {
                                  final uid = _text(user['uid']);
                                  final busy = _busyUsers.contains(uid);
                                  final protected = _protected(user);
                                  final disabled = user['disabled'] == true;
                                  return DataRow(cells: [
                                    DataCell(SizedBox(width: 180, child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(_displayName(user), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                                        Text(uid, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: _muted)),
                                      ],
                                    ))),
                                    DataCell(SizedBox(width: 190, child: Text(_text(user['email']), maxLines: 1, overflow: TextOverflow.ellipsis))),
                                    DataCell(Text(_text(user['phoneNumber']).ifEmpty('—'))),
                                    DataCell(Text(_text(user['lastSignInAt']).ifEmpty('Never'))),
                                    DataCell(Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: disabled ? const Color(0xFFFFF7ED) : const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(disabled ? 'Disabled' : 'Enabled', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: disabled ? const Color(0xFFB45309) : _green)),
                                    )),
                                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                                      IconButton(
                                        tooltip: protected ? 'Protected administrator account' : 'Edit user',
                                        onPressed: busy || protected ? null : () => _editUser(user),
                                        icon: const Icon(Icons.edit_outlined, size: 19, color: _blue),
                                      ),
                                      IconButton(
                                        tooltip: protected ? 'Protected administrator account' : (disabled ? 'Enable account' : 'Disable account'),
                                        onPressed: busy || protected ? null : () => _toggleDisabled(user),
                                        icon: Icon(disabled ? Icons.lock_open_outlined : Icons.lock_outline, size: 19, color: const Color(0xFFD97706)),
                                      ),
                                      IconButton(
                                        tooltip: protected ? 'Protected administrator account' : 'Delete account',
                                        onPressed: busy || protected ? null : () => _deleteUser(user),
                                        icon: const Icon(Icons.delete_outline, size: 19, color: _red),
                                      ),
                                      if (busy) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                                    ])),
                                  ]);
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
                icon: _loadingMore ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.expand_more),
                label: Text(_loadingMore ? 'Loading…' : 'Load more accounts'),
              ),
            ),
          ),
      ],
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}
