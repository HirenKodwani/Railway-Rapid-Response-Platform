// Role definitions and hierarchy for the Indian Railways RRS
// Supports 6-level role hierarchy: master_admin > super_admin > admin > lead_supervisor > supervisor > operator

/// All available roles in the system, ordered by hierarchy level
enum UserRole {
  masterAdmin('master_admin', 'Master Admin', 1),
  superAdmin('super_admin', 'Super Admin', 2),
  admin('admin', 'Admin', 3),
  leadSupervisor('lead_supervisor', 'Lead Supervisor', 4),
  supervisor('supervisor', 'Supervisor', 5),
  operator('operator', 'Operator', 6);

  const UserRole(this.value, this.displayName, this.level);

  /// The string value matching the backend role enum
  final String value;

  /// Human-readable display name
  final String displayName;

  /// Hierarchy level (1 = highest)
  final int level;

  /// Get UserRole from string value
  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => UserRole.operator,
    );
  }
}

/// Returns a list of all subordinate roles that a given role can create
List<String> getSubordinateRoles(String creatorRole) {
  final creator = UserRole.fromString(creatorRole);
  if (creator == UserRole.operator) return [];
  
  return UserRole.values
      .where((role) => role.level > creator.level)
      .map((role) => role.value)
      .toList();
}

/// Returns true if the given role can create other users
bool canCreateUsers(String role) {
  return getSubordinateRoles(role).isNotEmpty;
}

/// Display name mapping for roles
const Map<String, String> roleDisplayNames = {
  'master_admin': 'Master Admin',
  'super_admin': 'Super Admin',
  'admin': 'Admin',
  'lead_supervisor': 'Lead Supervisor',
  'supervisor': 'Supervisor',
  'operator': 'Operator',
};

/// Get a human-readable display name for a role string
String getRoleDisplayName(String role) {
  return roleDisplayNames[role] ?? role;
}
