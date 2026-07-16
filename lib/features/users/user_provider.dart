import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/user_model.dart';
import '../../core/models/hierarchy_node.dart';
import '../../core/services/user_service.dart';
import '../auth/auth_provider.dart';

/// User list state
class UserListState {
  final List<UserModel> users;
  final bool isLoading;
  final String? errorMessage;

  UserListState({
    this.users = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  UserListState copyWith({
    List<UserModel>? users,
    bool? isLoading,
    String? errorMessage,
  }) {
    return UserListState(
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

/// User list state notifier
class UserListNotifier extends StateNotifier<UserListState> {
  final Ref ref;

  UserListNotifier(this.ref) : super(UserListState());

  /// Fetch users created by the currently logged-in user
  Future<void> fetchMyUsers() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    final result = await UserService.getMyUsers(token: token);

    if (result.success && result.data != null) {
      state = UserListState(users: result.data!, isLoading: false);
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.message,
      );
    }
  }

  /// Create a new user
  /// Returns true on success, false on failure
  Future<bool> createUser(Map<String, dynamic> userData) async {
    final token = ref.read(authProvider).token;
    if (token == null) return false;

    state = state.copyWith(isLoading: true, errorMessage: null);

    final result = await UserService.createUser(
      userData: userData,
      token: token,
    );

    if (result.success && result.data != null) {
      // Add the new user to the list
      state = UserListState(
        users: [result.data!, ...state.users],
        isLoading: false,
      );
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.message,
      );
      return false;
    }
  }

  /// Update an existing user
  /// Returns true on success, false on failure
  Future<bool> updateUser(String id, Map<String, dynamic> userData) async {
    final token = ref.read(authProvider).token;
    if (token == null) return false;

    state = state.copyWith(isLoading: true, errorMessage: null);

    final result = await UserService.updateUser(
      id: id,
      userData: userData,
      token: token,
    );

    if (result.success && result.data != null) {
      // Replace the updated user in the list
      final updatedUsers = state.users.map((u) {
        if (u.id == id) return result.data!;
        return u;
      }).toList();

      state = UserListState(users: updatedUsers, isLoading: false);
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.message,
      );
      return false;
    }
  }

  /// Delete a user
  /// Returns true on success, false on failure
  Future<bool> deleteUser(String id) async {
    final token = ref.read(authProvider).token;
    if (token == null) return false;

    state = state.copyWith(isLoading: true, errorMessage: null);

    final result = await UserService.deleteUser(
      id: id,
      token: token,
    );

    if (result.success) {
      // Remove user from the list
      final updatedUsers = state.users.where((u) => u.id != id).toList();
      state = UserListState(users: updatedUsers, isLoading: false);
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.message,
      );
      return false;
    }
  }
}

/// User list provider (Riverpod)
final userListProvider =
    StateNotifierProvider<UserListNotifier, UserListState>(
  (ref) => UserListNotifier(ref),
);

// --- Hierarchy Tree State ---

/// Hierarchy tree state
class HierarchyTreeState {
  final HierarchyNode? root;
  final bool isLoading;
  final String? errorMessage;

  HierarchyTreeState({
    this.root,
    this.isLoading = false,
    this.errorMessage,
  });

  HierarchyTreeState copyWith({
    HierarchyNode? root,
    bool? isLoading,
    String? errorMessage,
  }) {
    return HierarchyTreeState(
      root: root ?? this.root,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

/// Hierarchy tree state notifier
class HierarchyTreeNotifier extends StateNotifier<HierarchyTreeState> {
  final Ref ref;

  HierarchyTreeNotifier(this.ref) : super(HierarchyTreeState());

  /// Fetch the hierarchy tree from API
  Future<void> fetchHierarchy() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;

    state = HierarchyTreeState(isLoading: true);

    final result = await UserService.getHierarchyTree(token: token);

    if (result.success && result.data != null) {
      state = HierarchyTreeState(root: result.data!, isLoading: false);
    } else {
      state = HierarchyTreeState(
        isLoading: false,
        errorMessage: result.message,
      );
    }
  }
}

/// Hierarchy tree provider (Riverpod)
final hierarchyTreeProvider =
    StateNotifierProvider<HierarchyTreeNotifier, HierarchyTreeState>(
  (ref) => HierarchyTreeNotifier(ref),
);
