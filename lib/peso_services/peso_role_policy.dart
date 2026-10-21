/// Normalizes a role returned by the trusted PESO API profile endpoint.
/// Unknown and missing values deliberately fail closed to a regular-user role.
const Set<String> _allowedPesoRoles = <String>{
  'admin',
  'job_seeker',
  'employer',
  'staff',
};

String normalizePesoRole(Object? value) {
  final role = value is String ? value : value?.toString();
  return _allowedPesoRoles.contains(role) ? role! : 'job_seeker';
}

/// UI routing helper only. The protected API still authorizes every Admin call.
bool shouldOpenAdminArea(String? role) => role == 'admin';
