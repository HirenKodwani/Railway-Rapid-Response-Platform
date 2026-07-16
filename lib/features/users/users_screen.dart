import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/roles.dart';
import '../../core/constants/strings.dart';
import '../../core/utils/launcher_utils.dart';
import '../auth/auth_provider.dart';
import 'create_user_screen.dart';
import 'edit_user_screen.dart';
import 'hierarchy_tree_screen.dart';
import 'user_provider.dart';

/// Users Screen — with two sub-tabs: "Create User" (user list + FAB) and "Hierarchy Tree"
class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _expandedUserId; // Only one card expanded at a time

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Fetch users on screen load
    Future.microtask(() {
      ref.read(userListProvider.notifier).fetchMyUsers();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userListState = ref.watch(userListProvider);
    final authState = ref.watch(authProvider);
    final currentRole = authState.user?.role ?? 'operator';
    final showFab = canCreateUsers(currentRole);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // --- Sub-tabs ---
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.accentSaffron,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: AppColors.accentSaffron,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_rounded, size: 18),
                      const SizedBox(width: 6),
                      Text(AppStrings.createUserTab),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.account_tree_rounded, size: 18),
                      const SizedBox(width: 6),
                      Text(AppStrings.hierarchyTreeTab),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- Tab content ---
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Create User — existing user list + FAB
                Stack(
                  children: [
                    RefreshIndicator(
                      onRefresh: () =>
                          ref.read(userListProvider.notifier).fetchMyUsers(),
                      color: AppColors.accentSaffron,
                      child: _buildUserListBody(userListState),
                    ),
                    // FAB positioned at bottom right
                    if (showFab)
                      Positioned(
                        bottom: 20,
                        right: 20,
                        child: FloatingActionButton.extended(
                          heroTag: 'create_user_fab',
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const CreateUserScreen(),
                              ),
                            );
                          },
                          backgroundColor: AppColors.accentSaffron,
                          foregroundColor: Colors.white,
                          icon: const Icon(Icons.person_add_rounded),
                          label: Text(
                            AppStrings.createUser,
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600),
                          ),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                  ],
                ),

                // Tab 2: Hierarchy Tree
                const HierarchyTreeScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserListBody(UserListState state) {
    if (state.isLoading && state.users.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accentSaffron),
      );
    }

    if (state.errorMessage != null && state.users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: AppColors.error.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              state.errorMessage!,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  ref.read(userListProvider.notifier).fetchMyUsers(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Retry',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    if (state.users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryNavy.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people_outline_rounded,
                size: 40,
                color: AppColors.primaryNavy.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppStrings.noUsers,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.noUsersHint,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    // Group users by role level
    final Map<String, List<dynamic>> groupedUsers = {};
    for (final role in UserRole.values) {
      final roleUsers = state.users.where((u) => u.role == role.value).toList();
      if (roleUsers.isNotEmpty) {
        groupedUsers[role.value] = roleUsers;
      }
    }

    final List<Widget> listItems = [];
    
    // Header
    listItems.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(
          '${state.users.length} Total User${state.users.length == 1 ? '' : 's'}',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      )
    );

    for (final roleStr in groupedUsers.keys) {
      final roleUsers = groupedUsers[roleStr]!;
      final roleColor = getRoleColor(roleStr);
      final roleDisplayName = getRoleDisplayName(roleStr);

      // Section header
      listItems.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          child: Row(
            children: [
              Icon(Icons.shield_rounded, color: roleColor, size: 18),
              const SizedBox(width: 8),
              Text(
                '${roleDisplayName}s (${roleUsers.length})',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: roleColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Divider(color: roleColor.withValues(alpha: 0.2)),
              ),
            ],
          ),
        )
      );

      // Users
      for (final user in roleUsers) {
        final isExpanded = _expandedUserId == user.id;
        listItems.add(
          _buildExpandableUserCard(
            user: user,
            roleColor: roleColor,
            roleDisplay: roleDisplayName,
            isExpanded: isExpanded,
          )
        );
      }
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: listItems.length,
      itemBuilder: (context, index) => listItems[index],
    );
  }

  Widget _buildExpandableUserCard({
    required dynamic user,
    required Color roleColor,
    required String roleDisplay,
    required bool isExpanded,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded
              ? roleColor.withValues(alpha: 0.3)
              : roleColor.withValues(alpha: 0.15),
          width: isExpanded ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isExpanded
                ? roleColor.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: isExpanded ? 16 : 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // --- Collapsed / Header section (always visible) ---
          InkWell(
            onTap: () {
              setState(() {
                _expandedUserId = isExpanded ? null : user.id;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: roleColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        user.name.isNotEmpty
                            ? user.name[0].toUpperCase()
                            : '?',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: roleColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Name + Role + Zone summary
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                user.name,
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: roleColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                roleDisplay,
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: roleColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Zone/Division summary line
                        Text(
                          _buildZoneDivisionSummary(user),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Expand/collapse icon
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSubtle,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- Expanded section ---
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildExpandedContent(user, roleColor),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }

  String _buildZoneDivisionSummary(dynamic user) {
    final parts = <String>[];
    if (user.zone != null && user.zone!.isNotEmpty) {
      parts.add(user.zone!);
    }
    if (user.division != null && user.division!.isNotEmpty) {
      parts.add(user.division!);
    }
    return parts.isNotEmpty ? parts.join(' • ') : 'No zone/division';
  }

  Widget _buildExpandedContent(dynamic user, Color roleColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(
            color: Colors.grey.withValues(alpha: 0.15),
            height: 1,
          ),
          const SizedBox(height: 12),

          // All user details
          _buildDetailRow(Icons.email_outlined, 'Email', user.email),
          _buildDetailRow(Icons.phone_outlined, 'Phone', user.phone, onTap: () {
            if (user.phone.isNotEmpty) {
              LauncherUtils.makePhoneCall(user.phone);
            }
          }),
          _buildDetailRow(
              Icons.badge_outlined, 'Employee ID', user.employeeId),
          if (user.zone != null && user.zone!.isNotEmpty)
            _buildDetailRow(
                Icons.location_city_outlined, 'Zone', user.zone!),
          if (user.division != null && user.division!.isNotEmpty)
            _buildDetailRow(Icons.map_outlined, 'Division', user.division!),
          if (user.address != null && user.address!.isNotEmpty)
            _buildDetailRow(
                Icons.location_on_outlined, 'Address', user.address!),

          const SizedBox(height: 16),

          // --- Action Buttons ---
          Row(
            children: [
              // Edit button
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: OutlinedButton.icon(
                    onPressed: () => _handleEdit(user),
                    icon: Icon(Icons.edit_rounded,
                        size: 18, color: AppColors.primaryNavy),
                    label: Text(
                      AppStrings.edit,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: AppColors.primaryNavy.withValues(alpha: 0.3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Delete button
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: OutlinedButton.icon(
                    onPressed: () => _showDeleteConfirmation(user),
                    icon: Icon(Icons.delete_outline_rounded,
                        size: 18, color: AppColors.error),
                    label: Text(
                      AppStrings.delete,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.error,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {VoidCallback? onTap}) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textSubtle),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textSubtle,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (onTap != null)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.call_made_rounded, size: 14, color: AppColors.success),
                ),
            ],
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: row,
              ),
            )
          : row,
    );
  }

  Future<void> _handleEdit(dynamic user) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditUserScreen(user: user),
      ),
    );

    // Refresh list if edit was successful
    if (result == true) {
      _expandedUserId = null; // Collapse after edit
    }
  }

  void _showDeleteConfirmation(dynamic user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: AppColors.error, size: 28),
            const SizedBox(width: 10),
            Text(
              AppStrings.deleteConfirmTitle,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
            children: [
              TextSpan(text: '${AppStrings.deleteConfirmPrefix} '),
              TextSpan(
                text: user.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              TextSpan(text: AppStrings.deleteConfirmSuffix),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              AppStrings.cancel,
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _performDelete(user);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              AppStrings.confirm,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performDelete(dynamic user) async {
    final success =
        await ref.read(userListProvider.notifier).deleteUser(user.id);

    if (success && mounted) {
      setState(() => _expandedUserId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.userDeleted,
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } else if (mounted) {
      final errorMsg = ref.read(userListProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMsg ?? 'Failed to delete user',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
}
