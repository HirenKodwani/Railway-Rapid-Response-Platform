import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/strings.dart';
import '../../core/constants/specialisations.dart';
import '../../core/models/user_model.dart';
import '../../core/utils/launcher_utils.dart';
import '../../core/utils/location_permission_guard.dart';
import '../../core/services/supervisor_service.dart';
import '../../core/services/railway_routing_service.dart';
import '../auth/auth_provider.dart';
import 'supervisor_provider.dart';
import 'location_picker_screen.dart';
class MyArtTrainScreen extends ConsumerStatefulWidget {
  const MyArtTrainScreen({super.key});

  @override
  ConsumerState<MyArtTrainScreen> createState() => _MyArtTrainScreenState();
}

class _MyArtTrainScreenState extends ConsumerState<MyArtTrainScreen> {
  bool _isUpdatingLocation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(myArtTrainProvider.notifier).fetchMyTrainData();
    });
  }

  Future<void> _handleUpdateLocation(double lat, double lng) async {
    setState(() => _isUpdatingLocation = true);
    final token = ref.read(authProvider).token;
    if (token == null) {
      setState(() => _isUpdatingLocation = false);
      return;
    }

    final result = await SupervisorService.updateMyArtTrainLocation(
      token: token,
      lat: lat,
      lng: lng,
    );

    setState(() => _isUpdatingLocation = false);

    if (mounted) {
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location updated successfully!'), backgroundColor: AppColors.success),
        );
        ref.read(myArtTrainProvider.notifier).fetchMyTrainData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? 'Failed to update location.'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showLocationOptionsDialog(LatLng? currentLocation) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Update Depot Location', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.gps_fixed, color: AppColors.primaryNavy),
              title: Text('Use Current Location', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
              onTap: () async {
                Navigator.of(ctx).pop();
                bool hasPermission = await LocationPermissionGuard.ensureLocationPermission(context);
                if (hasPermission) {
                  setState(() => _isUpdatingLocation = true);
                  try {
                    final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
                    final routingService = RailwayRoutingService();
                    final snapResult = await routingService.getNearestTrack(lat: position.latitude, lng: position.longitude);
                    if (snapResult != null && snapResult['snapped_point'] != null) {
                      final point = snapResult['snapped_point'] as List;
                      await _handleUpdateLocation(point[1], point[0]);
                    } else {
                      await _handleUpdateLocation(position.latitude, position.longitude);
                    }
                  } catch (e) {
                    setState(() => _isUpdatingLocation = false);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to get or snap current location'), backgroundColor: AppColors.error));
                    }
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.map, color: AppColors.primaryNavy),
              title: Text('Select on Map', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
              onTap: () async {
                Navigator.of(ctx).pop();
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => LocationPickerScreen(initialLocation: currentLocation)),
                );
                if (result != null && result is LatLng) {
                  setState(() => _isUpdatingLocation = true);
                  final routingService = RailwayRoutingService();
                  final snapResult = await routingService.getNearestTrack(lat: result.latitude, lng: result.longitude);
                  if (snapResult != null && snapResult['snapped_point'] != null) {
                    final point = snapResult['snapped_point'] as List;
                    await _handleUpdateLocation(point[1], point[0]);
                  } else {
                    await _handleUpdateLocation(result.latitude, result.longitude);
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myArtTrainProvider);

    if (state.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.accentSaffron)),
      );
    }

    if (state.train == null) {
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
                  color: AppColors.primaryNavy.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.train_outlined, size: 40, color: AppColors.primaryNavy.withValues(alpha: 0.4)),
              ),
              const SizedBox(height: 20),
              Text('No ART Train assigned yet.', style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('You will be notified when assigned', style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    final train = state.train!;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.accentSaffron,
        onRefresh: () => ref.read(myArtTrainProvider.notifier).fetchMyTrainData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Train Details Card
              Container(
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
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.accentSaffron.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.train, color: AppColors.accentSaffron),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(train.name, style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                                Text('${train.division} Division', style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 14)),
                              ],
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (train.gpsDeviceId != null && train.gpsDeviceId!.isNotEmpty)
                        _buildInfoRow(Icons.gps_fixed, 'GPS Device', train.gpsDeviceId!),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Depot Location', style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                          if (_isUpdatingLocation)
                            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentSaffron))
                          else
                            TextButton.icon(
                              onPressed: () {
                                LatLng? currentLoc;
                                if (train.depotLat != null && train.depotLng != null) {
                                  currentLoc = LatLng(train.depotLat!, train.depotLng!);
                                }
                                _showLocationOptionsDialog(currentLoc);
                              },
                              icon: const Icon(Icons.edit_location_alt_rounded, size: 18),
                              label: Text('Edit', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                              style: TextButton.styleFrom(foregroundColor: AppColors.primaryNavy, padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 150,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: train.depotLat != null && train.depotLng != null
                          ? FlutterMap(
                              options: MapOptions(
                                initialCenter: LatLng(train.depotLat!, train.depotLng!),
                                initialZoom: 14.0,
                                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                              ),
                              children: [
                                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.indianrailways.rrs'),
                                MarkerLayer(
                                  markers: [
                                    Marker(point: LatLng(train.depotLat!, train.depotLng!), width: 40, height: 40, child: const Icon(Icons.location_on, color: AppColors.error, size: 40))
                                  ],
                                ),
                              ],
                            )
                          : Center(child: Text('Location not set', style: GoogleFonts.poppins(color: AppColors.textSecondary))),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
              Text(AppStrings.assignedOperators, style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),

              if (state.operators.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                  ),
                  child: Center(child: Text('No operators assigned.', style: GoogleFonts.poppins(color: AppColors.textSecondary))),
                )
              else
                Builder(
                  builder: (context) {
                    final operators = state.operators;
                    
                    // Group by specialisation
                    final grouped = <String?, List<UserModel>>{};
                    for (final op in operators) {
                      final spec = op.specialisation;
                      if (!grouped.containsKey(spec)) grouped[spec] = [];
                      grouped[spec]!.add(op);
                    }
                    
                    // Sort keys: non-null first according to Specialisations.ids order, then null
                    final sortedKeys = grouped.keys.toList()..sort((a, b) {
                      if (a == null && b == null) return 0;
                      if (a == null) return 1;
                      if (b == null) return -1;
                      return Specialisations.ids.indexOf(a).compareTo(Specialisations.ids.indexOf(b));
                    });

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Summary Chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            children: sortedKeys.map((key) {
                              final ops = grouped[key]!;
                              final label = Specialisations.getLabel(key);
                              final color = Specialisations.getColor(key);
                              
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Chip(
                                  label: Text('$label  ${ops.length}', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                                  backgroundColor: color,
                                  side: BorderSide.none,
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        
                        // Grouped List
                        ...sortedKeys.map((key) {
                          final ops = grouped[key]!;
                          final label = Specialisations.getLabel(key);
                          
                          return Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              initiallyExpanded: false,
                              tilePadding: EdgeInsets.zero,
                              title: Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                              children: [
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: ops.length,
                                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final op = ops[index];
                                    return Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                                      ),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: Specialisations.getColor(key).withValues(alpha: 0.12),
                                          child: Text(
                                            op.name.isNotEmpty ? op.name[0].toUpperCase() : '?',
                                            style: GoogleFonts.poppins(color: Specialisations.getColor(key), fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                        title: Text(op.name, style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                                        subtitle: Text(
                                          '${op.phone}${op.city != null && op.city!.isNotEmpty ? ' • ${op.city}' : ''}', 
                                          style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12),
                                        ),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.phone, color: AppColors.success, size: 20),
                                          onPressed: () {
                                            if (op.phone.isNotEmpty) {
                                              LauncherUtils.makePhoneCall(op.phone);
                                            }
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSubtle),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Text('$label: ', style: GoogleFonts.poppins(color: AppColors.textSubtle, fontSize: 14)),
        ),
        Expanded(
          flex: 3,
          child: Text(value, style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 14)),
        ),
      ],
    );
  }
}
