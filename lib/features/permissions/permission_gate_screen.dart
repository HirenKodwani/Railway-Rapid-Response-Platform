import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants/colors.dart';
import '../shell/shell_screen.dart';

class PermissionGateScreen extends StatefulWidget {
  final String? pendingIncidentId;

  const PermissionGateScreen({super.key, this.pendingIncidentId});

  @override
  State<PermissionGateScreen> createState() => _PermissionGateScreenState();
}

class _PermissionGateScreenState extends State<PermissionGateScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    bool allGranted = await _areAllPermissionsGranted();
    if (allGranted) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => ShellScreen(pendingIncidentId: widget.pendingIncidentId)),
        );
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _areAllPermissionsGranted() async {
    if (kIsWeb) return true; // Web doesn't need these specific Android permissions

    final notification = await Permission.notification.status;
    
    bool systemAlertGranted = true;
    bool exactAlarmGranted = true;
    bool dndGranted = true;
    
    if (defaultTargetPlatform == TargetPlatform.android) {
      systemAlertGranted = await Permission.systemAlertWindow.status.isGranted;
      exactAlarmGranted = await Permission.scheduleExactAlarm.status.isGranted;
      dndGranted = await Permission.accessNotificationPolicy.status.isGranted;
    }

    return notification.isGranted &&
        systemAlertGranted &&
        exactAlarmGranted &&
        dndGranted;
  }

  Future<void> _requestPermissions() async {
    setState(() => _isLoading = true);
    
    if (kIsWeb) {
      _checkPermissions();
      return;
    }
    
    // 1. Notifications
    final notifReq = await Permission.notification.request();
    if (!notifReq.isGranted) {
      _showDenialDialog('Notifications');
      setState(() => _isLoading = false);
      return;
    }

    // 2. Display over other apps (Android only)
    if (defaultTargetPlatform == TargetPlatform.android) {
      final sysReq = await Permission.systemAlertWindow.request();
      if (!sysReq.isGranted) {
        _showDenialDialog('Display over other apps');
        setState(() => _isLoading = false);
        return;
      }
    }

    // 3. Exact Alarm (Android 12+)
    if (defaultTargetPlatform == TargetPlatform.android) {
      final alarmReq = await Permission.scheduleExactAlarm.request();
      if (!alarmReq.isGranted) {
        _showDenialDialog('Exact Alarm');
        setState(() => _isLoading = false);
        return;
      }
    }

    // 4. Do Not Disturb (DND) Access
    if (defaultTargetPlatform == TargetPlatform.android) {
      final dndReq = await Permission.accessNotificationPolicy.request();
      if (!dndReq.isGranted) {
        _showDenialDialog('Do Not Disturb Access');
        setState(() => _isLoading = false);
        return;
      }
    }

    _checkPermissions();
  }

  void _showDenialDialog(String permName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Permission Denied', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppColors.error)),
        content: Text(
          'This permission ($permName) is mandatory for emergency alerts. The app cannot function without it.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => SystemNavigator.pop(), // Exit App
            child: Text('Exit App', style: GoogleFonts.poppins(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryNavy,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Grant', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.primaryNavy,
        body: Center(child: CircularProgressIndicator(color: AppColors.accentSaffron)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Critical Permissions', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.primaryNavy,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Action Required',
                      style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'To ensure you receive critical emergency alerts immediately, please grant the following permissions.',
                      style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 32),
                    
                    _buildPermCard(
                      icon: Icons.notifications_active_rounded,
                      title: 'Notifications',
                      desc: 'Required to notify you when an emergency incident is created.',
                    ),
                    const SizedBox(height: 16),
                    _buildPermCard(
                      icon: Icons.layers_rounded,
                      title: 'Display Over Other Apps',
                      desc: 'Required to show full-screen emergency alerts even if you are using another app.',
                    ),
                    const SizedBox(height: 16),
                    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) ...[
                      _buildPermCard(
                        icon: Icons.alarm_rounded,
                        title: 'Exact Alarms',
                        desc: 'Required to wake up the device and play the emergency hooter sound.',
                      ),
                      const SizedBox(height: 16),
                      _buildPermCard(
                        icon: Icons.do_not_disturb_off_rounded,
                        title: 'Do Not Disturb Access',
                        desc: 'Required to bypass Silent/DND mode so the siren always rings loudly.',
                      ),
                    ],

                    const Spacer(),
                    const SizedBox(height: 24), // Extra spacing before the button when scrolled
                    ElevatedButton(
                      onPressed: _requestPermissions,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryNavy,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Continue & Grant', style: GoogleFonts.poppins(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermCard({required IconData icon, required String title, required String desc}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryNavy.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primaryNavy, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(desc, style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
