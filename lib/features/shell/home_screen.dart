import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/roles.dart';
import '../auth/auth_provider.dart';
import '../profile/profile_screen.dart';
import '../incident/create_incident_screen.dart';
import '../incident/incident_detail_screen.dart';
import '../incident/incident_map_screen.dart';
import '../incident/incident_provider.dart';
import '../incident/active_incident_console_screen.dart';
import '../../core/utils/location_permission_guard.dart';
import 'shell_provider.dart';
import '../lead_supervisor/ls_reports_screen.dart';
import '../../core/models/incident_model.dart';

/// Home Screen — role-specific dashboard placeholder with welcome card
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final roleColor = getRoleColor(user.role);
    final roleDisplayName = getRoleDisplayName(user.role);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Welcome Card ---
          _buildWelcomeCard(user.name, roleDisplayName, roleColor),
          const SizedBox(height: 20),

          // --- Active Incident Banner (for supervisor & operator) ---
          _buildActiveIncidentBanner(context, ref, user.role),

          // --- Quick Actions ---
          Text(
            'Quick Actions',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          
          InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: _buildActionTile(
              icon: Icons.person_outline_rounded,
              title: 'View Profile',
              subtitle: 'Check your info and change password',
              color: AppColors.roleLeadSupervisor,
            ),
          ),
          const SizedBox(height: 10),

          // Supervisor: Create Incident quick action
          if (user.role == 'supervisor') ...[
            InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateIncidentScreen()),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: _buildActionTile(
                icon: Icons.warning_amber_rounded,
                title: 'Create Incident',
                subtitle: 'Report a new emergency incident',
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 10),
          ],

          if (user.role != 'supervisor' && user.role != 'operator') ...[
            InkWell(
              onTap: () {
                final targetIndex = user.role == 'lead_supervisor' ? 4 : (user.role == 'admin' || user.role == 'super_admin' || user.role == 'master_admin' ? 2 : 1);
                ref.read(shellNavigationProvider.notifier).state = targetIndex;
              },
              borderRadius: BorderRadius.circular(16),
              child: _buildActionTile(
                icon: Icons.group_add_rounded,
                title: 'Manage Users',
                subtitle: 'Create and view members',
                color: AppColors.primaryNavy,
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (user.role != 'operator')
            InkWell(
              onTap: () {
                if (user.role == 'lead_supervisor') {
                  ref.read(shellNavigationProvider.notifier).state = 3;
                } else if (user.role == 'admin' || user.role == 'super_admin' || user.role == 'master_admin') {
                  ref.read(shellNavigationProvider.notifier).state = 1;
                } else if (user.role == 'supervisor') {
                  ref.read(shellNavigationProvider.notifier).state = 2; // Incidents tab
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: _buildActionTile(
                icon: Icons.assessment_rounded,
                title: 'Reports',
                subtitle: (user.role == 'lead_supervisor' || user.role == 'admin' || user.role == 'super_admin' || user.role == 'master_admin')
                    ? 'View incident reports from all supervisors'
                    : (user.role == 'supervisor' ? 'View your incident logs' : 'Coming soon — incident and performance reports'),
                color: AppColors.success,
              ),
            ),
        ],
      ),
    );
  }

  /// Builds an active incident banner if there's one currently active
  Widget _buildActiveIncidentBanner(BuildContext context, WidgetRef ref, String role) {
    final activeState = ref.watch(activeIncidentProvider);
    final incident = activeState.incident;

    if (incident == null) return const SizedBox.shrink();

    final severityColors = [
      const Color(0xFF4CAF50), const Color(0xFF8BC34A), const Color(0xFFFFC107),
      const Color(0xFFFF9800), const Color(0xFFFF5722), const Color(0xFFD50000),
    ];
    final sevColor = severityColors[(incident.severity - 1).clamp(0, 5)];

    // Determine operator response
    final operatorId = ref.watch(authProvider).user?.id;
    bool isAcceptedOperator = false;
    if (role == 'operator') {
      final alertedOp = incident.alertedOperators.firstWhere(
        (op) => op.operatorId == operatorId,
        orElse: () => OperatorAlert(operatorId: '', response: 'pending'),
      );
      isAcceptedOperator = alertedOp.response == 'accepted';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () async {
          if (role == 'supervisor') {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => IncidentDetailScreen(incidentId: incident.id)),
            );
          } else if (role == 'operator' && isAcceptedOperator) {
            bool consent = await LocationPermissionGuard.ensureLocationPermission(context);
            if (context.mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ActiveIncidentConsoleScreen(
                    incident: incident,
                    locationConsent: consent,
                  ),
                ),
              );
            }
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => IncidentMapScreen(incident: incident)),
            );
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.error, AppColors.error.withValues(alpha: 0.8)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: AppColors.error.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.warning_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          isAcceptedOperator ? 'REJOIN ACTIVE INCIDENT' : 'ACTIVE INCIDENT', 
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5)
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(color: sevColor, borderRadius: BorderRadius.circular(6)),
                          child: Text('Sev ${incident.severity}', style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                        // Show DRILL badge only for supervisors
                        if (incident.isMockDrill && role == 'supervisor')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: AppColors.warning, borderRadius: BorderRadius.circular(6)),
                            child: Text('DRILL', style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${incident.incidentSubcategory} • Train ${incident.trainNumber}',
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.8)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(String name, String role, Color roleColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryNavy,
            AppColors.primaryNavy.withValues(alpha: 0.85),
            const Color(0xFF1565C0),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryNavy.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    Text(
                      name,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: roleColor.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Text(
              role,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
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
    );
  }
}
