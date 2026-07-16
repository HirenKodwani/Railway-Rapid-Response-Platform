import '../models/user_model.dart';

/// Represents a node in the user hierarchy tree
/// Each node contains a user and a list of child nodes
class HierarchyNode {
  final UserModel user;
  final List<HierarchyNode> children;

  HierarchyNode({
    required this.user,
    this.children = const [],
  });

  /// Create HierarchyNode from JSON (recursive)
  factory HierarchyNode.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'] as Map<String, dynamic>;

    // Map fields to match UserModel.fromJson expectations
    final mappedUser = {
      '_id': userJson['id'] ?? '',
      'name': userJson['name'] ?? '',
      'email': userJson['email'] ?? '',
      'phone': userJson['phone'] ?? '',
      'role': userJson['role'] ?? '',
      'employee_id': userJson['employeeId'] ?? '',
      'zone': userJson['zone'],
      'division': userJson['division'],
      'city': userJson['city'],
      'isActive': userJson['isActive'] ?? true,
    };

    final childrenJson = json['children'] as List<dynamic>? ?? [];

    return HierarchyNode(
      user: UserModel.fromJson(mappedUser),
      children: childrenJson
          .map((c) => HierarchyNode.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Check if this node has children
  bool get hasChildren => children.isNotEmpty;

  /// Get total count of all descendants
  int get totalDescendants {
    int count = children.length;
    for (final child in children) {
      count += child.totalDescendants;
    }
    return count;
  }
}
