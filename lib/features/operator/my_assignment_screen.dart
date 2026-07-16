import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/strings.dart';
import '../../core/utils/launcher_utils.dart';
import 'operator_provider.dart';

class MyAssignmentScreen extends ConsumerStatefulWidget {
  const MyAssignmentScreen({super.key});

  @override
  ConsumerState<MyAssignmentScreen> createState() => _MyAssignmentScreenState();
}

class _MyAssignmentScreenState extends ConsumerState<MyAssignmentScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(operatorAssignmentProvider.notifier).fetchMyAssignment();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(operatorAssignmentProvider);

    if (state.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.accentSaffron)),
      );
    }

    if (state.assignment == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.roleOperator.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.assignment_late_outlined, size: 40, color: AppColors.roleOperator.withValues(alpha: 0.4)),
              ),
              const SizedBox(height: 20),
              Text(AppStrings.noAssignment, style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('You will be notified when assigned to a train', style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    final train = state.assignment!['train'];
    final supervisor = state.assignment!['supervisor'];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.accentSaffron,
        onRefresh: () => ref.read(operatorAssignmentProvider.notifier).fetchMyAssignment(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Assignment Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppColors.accentSaffron.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.train, color: AppColors.accentSaffron, size: 40),
                    ),
                    const SizedBox(height: 16),
                    Text(train['name'], style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
                    Text('${train['division']} Division', style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 16)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Supervisor Card
              Text(AppStrings.trainSupervisor, style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              if (supervisor == null)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_off, color: AppColors.textSecondary, size: 32),
                      const SizedBox(width: 16),
                      Text('No supervisor assigned yet.', style: GoogleFonts.poppins(color: AppColors.textSecondary)),
                    ],
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: AppColors.primaryNavy.withValues(alpha: 0.1),
                              child: const Icon(Icons.person, color: AppColors.primaryNavy),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(supervisor['name'], style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                                  Text(supervisor['employee_id'] ?? '', style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: AppColors.border),
                        const SizedBox(height: 8),
                        _buildInfoRow(Icons.phone_outlined, supervisor['phone'], onTap: () {
                          if (supervisor['phone'] != null) {
                            LauncherUtils.makePhoneCall(supervisor['phone'].toString());
                          }
                        }),
                        const SizedBox(height: 8),
                        _buildInfoRow(Icons.email_outlined, supervisor['email']),
                      ],
                    ),
                  ),
                ),
              
              const SizedBox(height: 24),

              // Train Info
              Text('Train Info', style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildInfoRow(Icons.people_outline, '${train['operatorCount']} Total Operators Assigned'),
                      if (train['gps_device_id'] != null && train['gps_device_id'].isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildInfoRow(Icons.gps_fixed, 'GPS Device: ${train['gps_device_id']}'),
                      ],
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Depot Location', style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 150,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: train['depot_lat'] != null && train['depot_lng'] != null
                          ? FlutterMap(
                              options: MapOptions(
                                initialCenter: LatLng(train['depot_lat'], train['depot_lng']),
                                initialZoom: 14.0,
                                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                              ),
                              children: [
                                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.indianrailways.rrs'),
                                MarkerLayer(
                                  markers: [
                                    Marker(point: LatLng(train['depot_lat'], train['depot_lng']), width: 40, height: 40, child: const Icon(Icons.location_on, color: AppColors.error, size: 40))
                                  ],
                                ),
                              ],
                            )
                          : Center(child: Text('Depot Location not set', style: GoogleFonts.poppins(color: AppColors.textSecondary))),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String value, {VoidCallback? onTap}) {
    final row = Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSubtle),
        const SizedBox(width: 12),
        Expanded(child: Text(value, style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 14))),
        if (onTap != null)
          const Icon(Icons.call_made_rounded, size: 16, color: AppColors.success),
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: row,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: row,
    );
  }
}
