import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/strings.dart';
import '../../core/models/art_train_model.dart';
import '../../core/services/art_train_service.dart';
import '../auth/auth_provider.dart';
import 'lead_supervisor_provider.dart';

class CreateEditArtTrainScreen extends ConsumerStatefulWidget {
  final ArtTrainModel? train; // If null, it's create mode.

  const CreateEditArtTrainScreen({super.key, this.train});

  @override
  ConsumerState<CreateEditArtTrainScreen> createState() => _CreateEditArtTrainScreenState();
}

class _CreateEditArtTrainScreenState extends ConsumerState<CreateEditArtTrainScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _gpsDeviceController = TextEditingController();
  
  List<Map<String, dynamic>> _availableSupervisors = [];
  String? _selectedSupervisorId;
  bool _isLoadingSupervisors = true;
  bool _isSaving = false;

  final MapController _mapController = MapController();
  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    if (widget.train != null) {
      _nameController.text = widget.train!.name;
      _gpsDeviceController.text = widget.train!.gpsDeviceId ?? '';
      _selectedSupervisorId = widget.train!.supervisorId;
      _lat = widget.train!.depotLat;
      _lng = widget.train!.depotLng;
    } else {
      // Default location (e.g., center of India) if no map data
      _lat = 20.5937;
      _lng = 78.9629;
    }
    _fetchSupervisors();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _gpsDeviceController.dispose();
    super.dispose();
  }

  Future<void> _fetchSupervisors() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;

    final result = await ArtTrainService.getAvailableSupervisors(token: token);
    
    if (mounted) {
      setState(() {
        _isLoadingSupervisors = false;
        if (result.success) {
          _availableSupervisors = result.data ?? [];
        }
      });
    }
  }

  void _handleMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _lat = point.latitude;
      _lng = point.longitude;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final data = {
      'name': _nameController.text.trim(),
      if (_gpsDeviceController.text.isNotEmpty) 'gps_device_id': _gpsDeviceController.text.trim(),
      if (_lat != null) 'depot_lat': _lat,
      if (_lng != null) 'depot_lng': _lng,
      if (_selectedSupervisorId != null) 'supervisor_id': _selectedSupervisorId,
    };

    bool success;
    if (widget.train == null) {
      success = await ref.read(artTrainsProvider.notifier).createTrain(data);
    } else {
      success = await ref.read(artTrainsProvider.notifier).updateTrain(widget.train!.id, data);
    }

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.train == null ? 'ART Train created' : 'ART Train updated'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ref.read(artTrainsProvider).errorMessage ?? 'Error saving train'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _handleSupervisorSelect(String? supervisorId) {
    if (supervisorId == null) {
      setState(() => _selectedSupervisorId = null);
      return;
    }

    final supervisor = _availableSupervisors.firstWhere((s) => s['_id'] == supervisorId);
    
    // If assigned to another train, prompt for force swap
    if (supervisor['isAssigned'] == true && supervisor['assignedTrainId'] != widget.train?.id) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(AppStrings.forceAssign, style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          content: Text(
            'This supervisor is already assigned to "${supervisor['assignedTrainName']}". Do you want to force swap them to this train? They will be removed from their current train.',
            style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppStrings.cancel, style: GoogleFonts.poppins(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() => _selectedSupervisorId = supervisorId);
              },
              child: Text('Yes, Swap', style: GoogleFonts.poppins(color: AppColors.accentSaffron, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    } else {
      setState(() => _selectedSupervisorId = supervisorId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.train == null ? AppStrings.createArtTrain : AppStrings.editArtTrain, style: GoogleFonts.poppins(color: AppColors.textLight, fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.primaryNavy,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textLight),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Section: Train Info ---
              _buildSectionTitle('Train Details'),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _nameController,
                label: AppStrings.trainName,
                icon: Icons.train_outlined,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              _buildTextField(
                controller: _gpsDeviceController,
                label: AppStrings.gpsDeviceId,
                icon: Icons.gps_fixed,
              ),
              const SizedBox(height: 24),
              
              // --- Section: Supervisor ---
              _buildSectionTitle('Assign Supervisor'),
              const SizedBox(height: 12),
              if (_isLoadingSupervisors)
                const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(color: AppColors.accentSaffron)))
              else
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _selectedSupervisorId,
                  items: [
                    DropdownMenuItem<String>(value: null, child: Text('None', style: GoogleFonts.poppins(color: AppColors.textSecondary))),
                    ..._availableSupervisors.map((s) {
                      String label = s['name'];
                      final isAssignedElsewhere = s['isAssigned'] == true && s['assignedTrainId'] != widget.train?.id;
                      if (isAssignedElsewhere) {
                        label += ' (Assigned to ${s['assignedTrainName']})';
                      }
                      return DropdownMenuItem<String>(
                        value: s['_id'],
                        child: Text(label, style: GoogleFonts.poppins(
                          color: isAssignedElsewhere ? AppColors.textSubtle : AppColors.textPrimary,
                          fontSize: 14,
                        )),
                      );
                    }),
                  ],
                  onChanged: _handleSupervisorSelect,
                  dropdownColor: AppColors.surface,
                  icon: Icon(Icons.arrow_drop_down_rounded, color: AppColors.textSubtle),
                  style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: AppStrings.selectSupervisor,
                    labelStyle: GoogleFonts.poppins(color: AppColors.textSubtle, fontSize: 13),
                    prefixIcon: Icon(Icons.person_outline, color: AppColors.textSubtle, size: 20),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.accentSaffron, width: 1.5)),
                  ),
                ),
              
              const SizedBox(height: 24),

              // --- Section: Map ---
              _buildSectionTitle('Depot Location'),
              const SizedBox(height: 12),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                clipBehavior: Clip.antiAlias,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(_lat!, _lng!),
                    initialZoom: widget.train == null ? 4.0 : 15.0,
                    onTap: _handleMapTap,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.indianrailways.rrs',
                    ),
                    MarkerLayer(
                      markers: [
                        if (_lat != null && _lng != null)
                          Marker(
                            point: LatLng(_lat!, _lng!),
                            width: 40,
                            height: 40,
                            child: const Icon(Icons.location_on, color: AppColors.error, size: 40),
                          )
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text('Tap on the map to set the depot location.', style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12)),
              ),
              
              const SizedBox(height: 32),

              // --- Submit ---
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentSaffron,
                    foregroundColor: AppColors.textLight,
                    disabledBackgroundColor: AppColors.accentSaffron.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 3,
                    shadowColor: AppColors.accentSaffron.withValues(alpha: 0.4),
                  ),
                  child: _isSaving 
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: AppColors.textLight, strokeWidth: 2.5))
                    : Text('Save ART Train', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 14),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: AppColors.textSubtle, fontSize: 13),
        prefixIcon: Icon(icon, color: AppColors.textSubtle, size: 20),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.accentSaffron, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.error)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.error, width: 1.5)),
        errorStyle: GoogleFonts.poppins(fontSize: 11),
      ),
    );
  }
}
