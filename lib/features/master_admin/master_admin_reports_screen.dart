import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/colors.dart';
import '../users/user_provider.dart';
import '../super_admin/super_admin_reports_screen.dart';

/// Master Admin Reports Screen — Shows a list of Super Admins (Zones) under the Master Admin
class MasterAdminReportsScreen extends ConsumerStatefulWidget {
  const MasterAdminReportsScreen({super.key});

  @override
  ConsumerState<MasterAdminReportsScreen> createState() => _MasterAdminReportsScreenState();
}

class _MasterAdminReportsScreenState extends ConsumerState<MasterAdminReportsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Fetch users when the screen loads
    Future.microtask(() {
      ref.read(userListProvider.notifier).fetchMyUsers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userListState = ref.watch(userListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Zones',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.primaryNavy,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppColors.darkGradient)),
        elevation: 0,
      ),
      body: _buildBody(userListState),
    );
  }

  Widget _buildBody(UserListState state) {
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

    // Filter for Super Admins only
    var superAdmins = state.users.where((u) => u.role == 'super_admin').toList();

    // Apply search filter
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      superAdmins = superAdmins.where((u) {
        final zone = u.zone?.toLowerCase() ?? '';
        final name = u.name.toLowerCase();
        return zone.contains(query) || name.contains(query);
      }).toList();
    }

    if (superAdmins.isEmpty && query.isEmpty) {
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
                Icons.map_rounded,
                size: 40,
                color: AppColors.primaryNavy.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Zones Found',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a Super Admin to represent a zone.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(userListProvider.notifier).fetchMyUsers(),
            color: AppColors.accentSaffron,
            child: superAdmins.isEmpty
                ? Center(
                    child: Text(
                      'No zones match "$query"',
                      style: GoogleFonts.poppins(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.all(16),
                    itemCount: superAdmins.length,
                    itemBuilder: (context, index) {
                      final user = superAdmins[index];
                      return _buildSuperAdminCard(user);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        style: GoogleFonts.poppins(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search zone...',
          hintStyle: GoogleFonts.poppins(
              color: AppColors.textSubtle, fontSize: 14),
          prefixIcon:
              const Icon(Icons.search_rounded, color: AppColors.textSubtle),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      color: AppColors.textSubtle, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.background,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: AppColors.primaryNavy, width: 1.5)),
        ),
      ),
    );
  }

  Widget _buildSuperAdminCard(dynamic user) {
    final roleColor = AppColors.roleSuperAdmin;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SuperAdminReportsScreen(zone: user.zone)),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : 'Z',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: roleColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.map_rounded, size: 14, color: roleColor),
                      const SizedBox(width: 4),
                      Text(
                        'Zone',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: roleColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.zone ?? user.name,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Managed by: ${user.name}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSubtle,
            ),
          ],
        ),
      ),
    );
  }
}
