import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/strings.dart';
import '../auth/auth_provider.dart';
import '../auth/login_screen.dart';
import '../users/users_screen.dart';
import '../lead_supervisor/approval_queue_screen.dart';
import '../lead_supervisor/art_trains_screen.dart';
import '../lead_supervisor/notifications_screen.dart';
import '../lead_supervisor/lead_supervisor_provider.dart';
import '../lead_supervisor/ls_reports_screen.dart';
import '../lead_supervisor/admin_reports_screen.dart';
import '../super_admin/super_admin_reports_screen.dart';
import '../master_admin/master_admin_reports_screen.dart';
import '../supervisor/my_art_train_screen.dart';
import '../operator/my_assignment_screen.dart';
import '../profile/profile_screen.dart';
import '../incident/incidents_log_screen.dart';
import '../incident/incident_alert_screen.dart';
import '../incident/active_incident_console_screen.dart';
import '../incident/incident_provider.dart';
import '../../core/utils/location_permission_guard.dart';
import '../../core/services/incident_service.dart';
import '../../core/services/notification_service.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'home_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../core/models/incident_model.dart';
import 'shell_provider.dart';

/// Shell Screen — persistent scaffold with AppBar + BottomNavigationBar
/// This is the main container for all authenticated screens
class ShellScreen extends ConsumerStatefulWidget {
  final String? pendingIncidentId;

  const ShellScreen({super.key, this.pendingIncidentId});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {

  // Generate screens and nav items dynamically based on role
  List<Widget> _getScreens(String role) {
    if (role == 'lead_supervisor') {
      return const [
        HomeScreen(),
        ApprovalQueueScreen(),
        ArtTrainsScreen(),
        LsReportsScreen(),
        UsersScreen(),
      ];
    } else if (role == 'super_admin') {
      return const [
        HomeScreen(),
        SuperAdminReportsScreen(),
        UsersScreen(),
      ];
    } else if (role == 'supervisor') {
      return const [
        HomeScreen(),
        MyArtTrainScreen(),
        IncidentsLogScreen(),
      ];
    } else if (role == 'master_admin') {
      return const [
        HomeScreen(),
        MasterAdminReportsScreen(),
        UsersScreen(),
      ];
    } else if (role == 'operator') {
      return const [
        HomeScreen(),
        MyAssignmentScreen(),
      ];
    } else if (role == 'admin') {
      return const [
        HomeScreen(),
        AdminReportsScreen(),
        UsersScreen(),
      ];
    } else {
      // Default roles
      return const [
        HomeScreen(),
        UsersScreen(),
      ];
    }
  }

  List<Map<String, dynamic>> _getNavItems(String role) {
    if (role == 'lead_supervisor') {
      return [
        {'icon': Icons.home_rounded, 'label': AppStrings.home},
        {'icon': Icons.how_to_reg_rounded, 'label': AppStrings.approvalQueue},
        {'icon': Icons.train_outlined, 'label': AppStrings.artTrains},
        {'icon': Icons.assessment_rounded, 'label': 'Reports'},
        {'icon': Icons.people_rounded, 'label': AppStrings.users},
      ];
    } else if (role == 'supervisor') {
      return [
        {'icon': Icons.home_rounded, 'label': AppStrings.home},
        {'icon': Icons.train, 'label': AppStrings.myArtTrain},
        {'icon': Icons.warning_amber_rounded, 'label': AppStrings.incidents},
      ];
    } else if (role == 'master_admin') {
      return [
        {'icon': Icons.home_rounded, 'label': AppStrings.home},
        {'icon': Icons.assessment_rounded, 'label': 'Reports'},
        {'icon': Icons.people_rounded, 'label': AppStrings.users},
      ];
    } else if (role == 'operator') {
      return [
        {'icon': Icons.home_rounded, 'label': AppStrings.home},
        {'icon': Icons.assignment_outlined, 'label': AppStrings.myAssignment},
      ];
    } else if (role == 'admin') {
      return [
        {'icon': Icons.home_rounded, 'label': AppStrings.home},
        {'icon': Icons.assessment_rounded, 'label': 'Reports'},
        {'icon': Icons.people_rounded, 'label': AppStrings.users},
      ];
    } else if (role == 'super_admin') {
      return [
        {'icon': Icons.home_rounded, 'label': AppStrings.home},
        {'icon': Icons.assessment_rounded, 'label': 'Reports'},
        {'icon': Icons.people_rounded, 'label': AppStrings.users},
      ];
    } else {
      // Default roles
      return [
        {'icon': Icons.home_rounded, 'label': AppStrings.home},
        {'icon': Icons.people_rounded, 'label': AppStrings.users},
      ];
    }
  }

  bool _checkedPendingIncident = false;
  late List<GlobalKey<NavigatorState>> _navigatorKeys;

  @override
  void initState() {
    super.initState();
    _navigatorKeys = List.generate(10, (_) => GlobalKey<NavigatorState>());
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      if (mounted) {
        ref.read(activeIncidentProvider.notifier).fetchActiveIncident();
        
        // Ensure sound plays and notification drops down even in foreground
        if (message.data.isNotEmpty && message.data['type'] == 'INCIDENT_ALERT') {
          final trainNumber = message.data['trainNumber'] ?? 'Unknown';
          final severity = message.data['severity'] ?? '1';
          final category = message.data['category'] ?? 'Incident';
          
          await NotificationService().showCriticalIncidentAlert(
            title: 'CRITICAL INCIDENT: $trainNumber',
            body: 'Severity: $severity - $category',
            payload: jsonEncode(message.data),
          );
        }
      }
    });
  }

  Future<void> _handlePendingIncident() async {
    if (widget.pendingIncidentId != null) {
      final authState = ref.read(authProvider);
      final token = authState.token;
      
      if (token != null) {
        // Fetch the incident by ID
        final res = await IncidentService.getIncident(
          token: token,
          incidentId: widget.pendingIncidentId!,
        );

        if (res.success && res.data != null && mounted) {
          if (res.data!.status == 'active') {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => IncidentAlertScreen(incident: res.data!),
                fullscreenDialog: true,
              ),
            );
          } else {
            NotificationService().cancelAllNotifications();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('The reported incident has already been resolved or cancelled.'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        }
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final userName = authState.user?.name ?? 'User';
    final role = authState.user?.role;

    // Show alert screen for operators if there's a new pending incident
    ref.listen<ActiveIncidentState>(activeIncidentProvider, (previous, next) {
      if (next.incident != null && !next.hasShownAlert && role == 'operator') {
        final operatorId = authState.user?.id;
        final alertedOp = next.incident!.alertedOperators.firstWhere(
          (op) => op.operatorId == operatorId,
          orElse: () => OperatorAlert(operatorId: '', response: 'pending'),
        );

        if (alertedOp.response == 'pending') {
          // Mark as shown so it doesn't pop repeatedly
          ref.read(activeIncidentProvider.notifier).markAlertShown();
          
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => IncidentAlertScreen(incident: next.incident!),
              fullscreenDialog: true,
            ),
          );
        } else if (alertedOp.response == 'accepted' && next.incident!.status == 'active') {
          // Automatic rejoin for accepted active incidents
          ref.read(activeIncidentProvider.notifier).markAlertShown();
          
          Future.microtask(() async {
            bool consent = await LocationPermissionGuard.ensureLocationPermission(context);
            if (mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ActiveIncidentConsoleScreen(
                    incident: next.incident!,
                    locationConsent: consent,
                  ),
                ),
              );
            }
          });
        }
      }
    });

    if (!_checkedPendingIncident) {
      _checkedPendingIncident = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handlePendingIncident();
        // Start polling active incident so it works even if Firebase fails (e.g. on Web)
        if (role == 'supervisor' || role == 'operator') {
          ref.read(activeIncidentProvider.notifier).startPolling();
        }
      });
    }

    return Scaffold(
      // --- AppBar ---
      appBar: AppBar(
        backgroundColor: AppColors.primaryNavy,
        elevation: 0,
        toolbarHeight: 72,
        leadingWidth: 60,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.train_rounded,
              color: AppColors.textLight,
              size: 26,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.appName,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textLight,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              'Hello, $userName',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppColors.textLight.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        actions: [
          if (authState.user?.role == 'lead_supervisor')
            _buildNotificationBell(),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: AppColors.textLight,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              if (value == 'profile') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              } else if (value == 'logout') {
                _showLogoutDialog();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'profile',
                child: Row(
                  children: [
                    const Icon(Icons.person_rounded, color: AppColors.primaryNavy, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'My Profile',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      AppStrings.logout,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.darkGradient,
          ),
        ),
      ),

      // --- Body ---
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          final screens = _getScreens(role ?? '');
          var currentIndex = ref.read(shellNavigationProvider);
          if (currentIndex >= screens.length) currentIndex = 0;
          
          final isFirstRouteInCurrentTab = !await _navigatorKeys[currentIndex].currentState!.maybePop();
          if (isFirstRouteInCurrentTab) {
            if (currentIndex != 0) {
              ref.read(shellNavigationProvider.notifier).state = 0;
            } else {
              SystemNavigator.pop();
            }
          }
        },
        child: IndexedStack(
          index: ref.watch(shellNavigationProvider) < _getScreens(role ?? '').length ? ref.watch(shellNavigationProvider) : 0,
          children: _getScreens(role ?? '').asMap().entries.map((entry) {
            final index = entry.key;
            final screen = entry.value;
            return Navigator(
              key: _navigatorKeys[index],
              onGenerateRoute: (routeSettings) {
                return MaterialPageRoute(
                  builder: (context) => screen,
                );
              },
            );
          }).toList(),
        ),
      ),

      // --- Bottom Navigation Bar ---
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _getNavItems(authState.user?.role ?? '').asMap().entries.map((entry) {
                return Expanded(
                  child: _buildNavItem(entry.value['icon'], entry.value['label'], entry.key, ref.watch(shellNavigationProvider)),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationBell() {
    final notifState = ref.watch(notificationsProvider);
    final count = notifState.unreadCount;

    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: AppColors.textLight),
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
          },
        ),
        if (count > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                count > 99 ? '99+' : count.toString(),
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, int currentIndex) {
    final isActive = currentIndex == index;
    
    int badgeCount = 0;
    if (label == AppStrings.approvalQueue) {
      final pendingState = ref.watch(pendingOperatorsProvider);
      badgeCount = pendingState.operators.length;
    }

    Widget iconWidget = Icon(
      icon,
      color: isActive ? AppColors.accentSaffron : AppColors.textSubtle,
      size: 24,
    );

    if (badgeCount > 0) {
      iconWidget = Badge(
        label: Text(
          badgeCount > 99 ? '99+' : badgeCount.toString(),
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.error,
        child: iconWidget,
      );
    }

    return GestureDetector(
      onTap: () {
        ref.read(shellNavigationProvider.notifier).state = index;
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.accentSaffron.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget,
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppColors.accentSaffron : AppColors.textSubtle,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          AppStrings.logout,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          AppStrings.logoutConfirm,
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(authProvider.notifier).logout();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              AppStrings.logout,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder screen for future features (Alerts, Reports)
class _PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;

  const _PlaceholderScreen({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
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
              icon,
              size: 40,
              color: AppColors.primaryNavy.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Coming soon in future updates',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
