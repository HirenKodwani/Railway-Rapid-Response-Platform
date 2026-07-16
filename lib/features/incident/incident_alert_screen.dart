import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/incident_data.dart';
import '../../core/models/incident_model.dart';
import '../../core/services/incident_service.dart';
import '../auth/auth_provider.dart';
import 'incident_provider.dart';
import 'active_incident_console_screen.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/utils/location_permission_guard.dart';
import '../../core/services/notification_service.dart';

/// Full-screen high-priority alert overlay for operators when an incident is triggered
class IncidentAlertScreen extends ConsumerStatefulWidget {
  final IncidentModel incident;
  const IncidentAlertScreen({super.key, required this.incident});

  @override
  ConsumerState<IncidentAlertScreen> createState() => _IncidentAlertScreenState();
}

class _IncidentAlertScreenState extends ConsumerState<IncidentAlertScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isResponding = false;

  final List<Color> _severityColors = [
    const Color(0xFF4CAF50), const Color(0xFF8BC34A), const Color(0xFFFFC107),
    const Color(0xFFFF9800), const Color(0xFFFF5722), const Color(0xFFD50000),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    
    _playHooter();
  }

  Future<void> _playHooter() async {
    try {
      await _audioPlayer.setLoopMode(LoopMode.one);
      await _audioPlayer.setAsset('assets/audio/hooter.wav');
      _audioPlayer.play();
    } catch (e) {
      debugPrint("Could not play hooter: $e");
    }
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    // Stop the looping alarm sound immediately upon interaction
    _audioPlayer.stop();
    await NotificationService().cancelAllNotifications();

    setState(() => _isResponding = true);

    bool locationConsent = await LocationPermissionGuard.ensureLocationPermission(context);
    if (!locationConsent) {
      setState(() => _isResponding = false);
      return; // Acceptance is blocked
    }

    final token = ref.read(authProvider).token;
    if (token == null) return;

    final result = await IncidentService.respondToIncident(
      token: token,
      incidentId: widget.incident.id,
      action: 'accept',
      locationConsent: locationConsent,
    );

    if (mounted) {
      if (result.success) {
        ref.read(activeIncidentProvider.notifier).markAlertShown();
        // Navigate to the operator console screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ActiveIncidentConsoleScreen(
              incident: widget.incident,
              locationConsent: locationConsent,
            ),
          ),
        );
      } else {
        setState(() => _isResponding = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? 'Failed.'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _decline() async {
    // Stop the looping alarm sound immediately upon interaction
    _audioPlayer.stop();
    await NotificationService().cancelAllNotifications();

    final reason = await _showDeclineDialog();
    if (reason == null) return;

    setState(() => _isResponding = true);
    final token = ref.read(authProvider).token;
    if (token == null) return;

    final result = await IncidentService.respondToIncident(
      token: token,
      incidentId: widget.incident.id,
      action: 'decline',
      reason: reason,
    );

    if (mounted) {
      if (result.success) {
        ref.read(activeIncidentProvider.notifier).markAlertShown();
        Navigator.of(context).pop(false);
      } else {
        setState(() => _isResponding = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? 'Failed.'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<String?> _showDeclineDialog() async {
    String? selectedReason;
    final customController = TextEditingController();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Decline Reason', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('A reason is mandatory when declining.', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 12),
                    ...IncidentData.declineReasons.map((reason) {
                      return RadioListTile<String>(
                        title: Text(reason, style: GoogleFonts.poppins(fontSize: 13)),
                        value: reason,
                        groupValue: selectedReason,
                        activeColor: AppColors.error,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        onChanged: (val) => setDialogState(() => selectedReason = val),
                      );
                    }),
                    if (selectedReason == 'Other')
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextField(
                          controller: customController,
                          decoration: InputDecoration(
                            hintText: 'Enter your reason...',
                            hintStyle: GoogleFonts.poppins(fontSize: 13),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          maxLines: 2,
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final finalReason = selectedReason == 'Other'
                        ? customController.text.trim()
                        : selectedReason;
                    if (finalReason != null && finalReason.isNotEmpty) {
                      Navigator.of(ctx).pop(finalReason);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Confirm Decline', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final incident = widget.incident;
    final sevColor = _severityColors[(incident.severity - 1).clamp(0, 5)];

    ref.listen<ActiveIncidentState>(activeIncidentProvider, (previous, next) {
      if (previous != null && previous.isLoading && !next.isLoading) {
        if (next.incident?.id != widget.incident.id) {
          NotificationService().cancelAllNotifications();
          if (mounted && Navigator.canPop(context)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This incident is no longer active (resolved or cancelled).'),
                backgroundColor: AppColors.success,
              ),
            );
            Navigator.of(context).pop();
          }
        }
      }
    });

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF8B0000),
                const Color(0xFF4A0000),
                AppColors.primaryDark,
              ],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Pulsing emergency icon
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 3),
                      ),
                      child: const Icon(Icons.warning_rounded, size: 56, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('🚨 EMERGENCY ALERT', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1.5)),
                  const SizedBox(height: 8),
                  Text('An incident has been reported', style: GoogleFonts.poppins(fontSize: 14, color: Colors.white.withValues(alpha: 0.8))),
                  const SizedBox(height: 28),

                  // Incident summary card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _alertInfoRow('Type', incident.incidentSubcategory),
                        _alertInfoRow('Category', incident.incidentCategory),
                        _alertInfoRow('Train', incident.trainNumber),
                        _alertInfoRow('Component', incident.affectedComponent),
                        _alertInfoRow('Location', '${incident.latitude.toStringAsFixed(4)}, ${incident.longitude.toStringAsFixed(4)}'),
                        const SizedBox(height: 12),
                        // Severity bar
                        Row(
                          children: [
                            Text('Severity  ', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
                            ...List.generate(6, (i) {
                              return Expanded(
                                child: Container(
                                  height: 8,
                                  margin: const EdgeInsets.symmetric(horizontal: 1),
                                  decoration: BoxDecoration(
                                    color: i < incident.severity
                                        ? _severityColors[i]
                                        : Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: sevColor, borderRadius: BorderRadius.circular(8)),
                              child: Text('${incident.severity}', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Accept / Decline buttons
                  if (_isResponding)
                    const CircularProgressIndicator(color: Colors.white)
                  else ...[
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _accept,
                        icon: const Icon(Icons.check_circle_rounded, size: 24),
                        label: Text('ACCEPT & RESPOND', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: _decline,
                        icon: const Icon(Icons.cancel_rounded, size: 24),
                        label: Text('DECLINE', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _alertInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Colors.white.withValues(alpha: 0.6), fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: GoogleFonts.poppins(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
