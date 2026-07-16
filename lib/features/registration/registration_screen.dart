import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/strings.dart';
import '../../core/utils/validators.dart';
import '../../core/constants/railway_data.dart';
import '../../core/constants/specialisations.dart';
import 'registration_provider.dart';
import 'registration_success_screen.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _selectedZone;
  String? _selectedDivision;
  String? _selectedCity;
  List<String> _divisions = [];
  List<String> _cities = [];
  String? _selectedSpecialisation;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  double? _lat;
  double? _lng;
  bool _fetchingLocation = false;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    setState(() => _fetchingLocation = true);
    try {
      final hasPermission = await _handleLocationPermission();
      if (!hasPermission) {
        setState(() => _fetchingLocation = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
        _fetchingLocation = false;
      });
      _mapController.move(LatLng(_lat!, _lng!), 15.0);
    } catch (e) {
      setState(() => _fetchingLocation = false);
    }
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Location services are disabled. Please enable them.')));
      }
      return false;
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }

  void _onZoneChanged(String? zone) {
    setState(() {
      _selectedZone = zone;
      _selectedDivision = null;
      _selectedCity = null;
      _divisions = zone != null ? RailwayData.getDivisionsForZone(zone) : [];
      _cities = [];
    });
  }

  void _onDivisionChanged(String? division) {
    setState(() {
      _selectedDivision = division;
      _selectedCity = null;
      _cities = division != null ? RailwayData.getCitiesForDivision(_selectedZone, division) : [];
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedZone == null || _selectedDivision == null || _selectedCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select Zone, Division, and City'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final data = {
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': Validators.sanitizePhone(_phoneController.text),
      'password': _passwordController.text,
      'zone': _selectedZone,
      'division': _selectedDivision,
      'city': _selectedCity,
      'specialisation': _selectedSpecialisation,
      if (_addressController.text.isNotEmpty) 'address': _addressController.text.trim(),
      if (_lat != null) 'lat': _lat,
      if (_lng != null) 'lng': _lng,
    };

    final success = await ref.read(registrationProvider.notifier).register(data);

    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const RegistrationSuccessScreen()),
      );
    } else if (mounted) {
      final errorMsg = ref.read(registrationProvider).errorMessage;
      if (errorMsg != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registrationProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppStrings.registerOperatorTitle,
            style: GoogleFonts.poppins(color: AppColors.textLight, fontWeight: FontWeight.w600)),
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- Header banner ---
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.roleOperator.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.roleOperator.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.roleOperator.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.person_add_rounded, color: AppColors.roleOperator, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.registerAsOperator,
                                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.roleOperator),
                              ),
                              Text(
                                AppStrings.registerOperatorSubtitle,
                                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- Personal Info Section ---
                  _buildSectionTitle('Personal Information'),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _nameController,
                    label: AppStrings.name,
                    icon: Icons.person_outlined,
                    validator: Validators.name,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _emailController,
                    label: AppStrings.email,
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _phoneController,
                    label: AppStrings.phone,
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: Validators.phone,
                  ),
                  const SizedBox(height: 24),

                  // --- Zone & Division ---
                  _buildSectionTitle('Zone & Location'),
                  const SizedBox(height: 12),
                  _buildDropdown(
                    label: AppStrings.zone,
                    value: _selectedZone,
                    items: RailwayData.zones,
                    onChanged: _onZoneChanged,
                    icon: Icons.map_outlined,
                  ),
                  const SizedBox(height: 14),
                  _buildDropdown(
                    label: AppStrings.division,
                    value: _selectedDivision,
                    items: _divisions,
                    onChanged: _divisions.isEmpty ? null : _onDivisionChanged,
                    icon: Icons.business_outlined,
                    hint: _divisions.isEmpty ? AppStrings.selectZoneFirst : AppStrings.selectDivision,
                  ),
                  const SizedBox(height: 14),
                  _buildDropdown(
                    label: AppStrings.city,
                    value: _selectedCity,
                    items: _cities,
                    onChanged: _cities.isEmpty ? null : (v) => setState(() => _selectedCity = v),
                    icon: Icons.location_city_outlined,
                    hint: _cities.isEmpty ? AppStrings.selectDivisionFirst : AppStrings.selectCity,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _addressController,
                    label: AppStrings.address,
                    icon: Icons.location_on_outlined,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),
                  _buildMapSection(),
                  const SizedBox(height: 24),

                  // --- Specialisation ---
                  _buildSectionTitle('Specialisation'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _selectedSpecialisation,
                    items: Specialisations.ids.map((id) => DropdownMenuItem(
                          value: id,
                          child: Text(Specialisations.getLabel(id), style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 14)),
                        )).toList(),
                    onChanged: (v) => setState(() => _selectedSpecialisation = v),
                    validator: (v) => v == null ? 'Required' : null,
                    dropdownColor: AppColors.surface,
                    icon: Icon(Icons.arrow_drop_down_rounded, color: AppColors.textSubtle),
                    style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Specialisation',
                      hintText: 'Select Specialisation',
                      hintStyle: GoogleFonts.poppins(color: AppColors.textSubtle, fontSize: 13),
                      labelStyle: GoogleFonts.poppins(color: AppColors.textSubtle, fontSize: 13),
                      prefixIcon: Icon(Icons.handyman_outlined, color: AppColors.textSubtle, size: 20),
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.accentSaffron, width: 1.5),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.error),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
                      ),
                      errorStyle: GoogleFonts.poppins(fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- Security ---
                  _buildSectionTitle('Security'),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _passwordController,
                    label: AppStrings.password,
                    icon: Icons.lock_outlined,
                    obscure: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: AppColors.textSubtle, size: 20),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    validator: Validators.password,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _confirmPasswordController,
                    label: AppStrings.confirmPassword,
                    icon: Icons.lock_outline_rounded,
                    obscure: _obscureConfirmPassword,
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirmPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: AppColors.textSubtle, size: 20),
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                    validator: (v) => Validators.confirmPassword(v, _passwordController.text),
                  ),
                  const SizedBox(height: 36),

                  // --- Submit Button ---
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: state.isLoading ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentSaffron,
                        foregroundColor: AppColors.textLight,
                        disabledBackgroundColor: AppColors.accentSaffron.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 3,
                        shadowColor: AppColors.accentSaffron.withValues(alpha: 0.4),
                      ),
                      child: state.isLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: AppColors.textLight, strokeWidth: 2.5)),
                                const SizedBox(width: 12),
                                Text('Registering...', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
                              ],
                            )
                          : Text(
                              AppStrings.registerAsOperator,
                              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
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

  Widget _buildMapSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('GPS Location (Auto-captured)', style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 13)),
            if (_fetchingLocation)
              const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentSaffron))
            else if (_lat == null)
              TextButton.icon(
                onPressed: _fetchLocation,
                icon: const Icon(Icons.my_location, size: 16, color: AppColors.accentSaffron),
                label: Text('Retry', style: GoogleFonts.poppins(color: AppColors.accentSaffron, fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 150,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          clipBehavior: Clip.antiAlias,
          child: _lat != null && _lng != null
            ? FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: LatLng(_lat!, _lng!),
                  initialZoom: 15.0,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.indianrailways.rrs',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(_lat!, _lng!),
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.location_on, color: AppColors.error, size: 40),
                      )
                    ],
                  ),
                ],
              )
            : Center(child: Text('Location not available', style: GoogleFonts.poppins(color: AppColors.textSecondary))),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffixIcon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      maxLines: maxLines,
      style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 14),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: AppColors.textSubtle, fontSize: 13),
        prefixIcon: Icon(icon, color: AppColors.textSubtle, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accentSaffron, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        errorStyle: GoogleFonts.poppins(fontSize: 11),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required void Function(String?)? onChanged,
    required IconData icon,
    String? hint,
  }) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: value,
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 14)))).toList(),
      onChanged: onChanged,
      validator: (v) => v == null ? 'Required' : null,
      dropdownColor: AppColors.surface,
      icon: Icon(Icons.arrow_drop_down_rounded, color: AppColors.textSubtle),
      style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: AppColors.textSubtle, fontSize: 13),
        labelStyle: GoogleFonts.poppins(color: AppColors.textSubtle, fontSize: 13),
        prefixIcon: Icon(icon, color: AppColors.textSubtle, size: 20),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accentSaffron, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        errorStyle: GoogleFonts.poppins(fontSize: 11),
      ),
    );
  }
}
