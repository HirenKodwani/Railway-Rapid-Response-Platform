import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/roles.dart';
import '../../core/constants/strings.dart';
import '../../core/constants/railway_data.dart';
import '../../core/services/location_service.dart';
import '../../core/utils/validators.dart';
import '../auth/auth_provider.dart';
import 'user_provider.dart';

/// Create User Screen — full form for creating subordinate users
/// Implements: phone validation, zone/division auto-assign, cascading dropdowns
class CreateUserScreen extends ConsumerStatefulWidget {
  const CreateUserScreen({super.key});

  @override
  ConsumerState<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends ConsumerState<CreateUserScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // State
  String? _selectedZone;
  String? _selectedDivision;
  String? _selectedCity;
  List<String> _cities = [];
  double? _latitude;
  double? _longitude;
  bool _isFetchingLocation = false;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  
  String _creatorRole = '';
  List<String> _subordinateRoles = [];
  String? _selectedRole;

  // Hierarchy-based field control
  bool _isZoneLocked = false;
  bool _isDivisionLocked = false;
  bool _showDivisionField = true;

  @override
  void initState() {
    super.initState();
    final authState = ref.read(authProvider);
    _creatorRole = authState.user?.role ?? '';
    _subordinateRoles = getSubordinateRoles(_creatorRole);
    if (_subordinateRoles.isNotEmpty) {
      _selectedRole = _subordinateRoles.first;
    }

    // Determine zone/division behavior based on creator's role
    _configureZoneDivisionFields(_creatorRole, _selectedRole, authState.user);
  }

  /// Configure zone and division field behavior based on hierarchy rules
  void _configureZoneDivisionFields(String creatorRole, String? targetRole, dynamic creatorUser) {
    if (targetRole == null) return;
    
    // Master Admin rules
    if (creatorRole == 'master_admin') {
      _isZoneLocked = false;
      _isDivisionLocked = false;
      _showDivisionField = (targetRole != 'super_admin');
    }
    // Super Admin rules
    else if (creatorRole == 'super_admin') {
      _isZoneLocked = true;
      _selectedZone = creatorUser?.zone;
      _isDivisionLocked = false;
      _showDivisionField = (targetRole != 'super_admin');
    }
    // Admin rules
    else if (creatorRole == 'admin') {
      _isZoneLocked = true;
      _selectedZone = creatorUser?.zone;
      _isDivisionLocked = false;
      _showDivisionField = true;
    }
    // Lead Supervisor, Supervisor rules
    else {
      _isZoneLocked = true;
      _isDivisionLocked = true;
      _selectedZone = creatorUser?.zone;
      _selectedDivision = creatorUser?.division;
      _showDivisionField = true;
      
      if (_selectedZone != null && _selectedDivision != null) {
        _cities = RailwayData.getCitiesForDivision(_selectedZone!, _selectedDivision!);
      }
    }
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
    setState(() => _isFetchingLocation = true);

    final hasPermission = await LocationService.requestPermission();

    if (!hasPermission) {
      if (mounted) {
        _showLocationDeniedDialog();
      }
      setState(() => _isFetchingLocation = false);
      return;
    }

    final result = await LocationService.getCurrentLocation();

    if (result.success) {
      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
        _isFetchingLocation = false;
      });
    } else {
      setState(() => _isFetchingLocation = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'Failed to fetch location'),
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

  void _showLocationDeniedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Location Required',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          '${AppStrings.locationDenied}\n\nPlease enable location access in your device settings to proceed.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'OK',
              style: GoogleFonts.poppins(
                color: AppColors.primaryNavy,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    // Enforce location before submit
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please fetch your location before submitting',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final userData = {
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'role': _selectedRole,

      'zone': _selectedZone,
      'division': _selectedDivision,
      'city': _selectedCity,
      'address': _addressController.text.trim(),
      'lat': _latitude,
      'lng': _longitude,
      'password': _passwordController.text,
    };

    final success =
        await ref.read(userListProvider.notifier).createUser(userData);

    setState(() => _isSubmitting = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.userCreated,
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      Navigator.of(context).pop();
    } else if (mounted) {
      final errorMsg = ref.read(userListProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMsg ?? 'Failed to create user',
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

  @override
  Widget build(BuildContext context) {
    final roleColor =
        _selectedRole != null ? getRoleColor(_selectedRole!) : AppColors.textSecondary;
    final roleDisplayName =
        _selectedRole != null ? getRoleDisplayName(_selectedRole!) : 'N/A';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryNavy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textLight),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          AppStrings.createUser,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textLight,
          ),
        ),
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
              // --- Role badge (read-only, pre-filled) ---
              _buildRoleBanner(roleDisplayName, roleColor),
              const SizedBox(height: 24),

              // --- Personal Information Section ---
              _buildSectionTitle('Personal Information'),
              const SizedBox(height: 12),
              _buildFormField(
                controller: _nameController,
                label: AppStrings.name,
                icon: Icons.person_outlined,
                validator: Validators.name,
              ),
              const SizedBox(height: 14),
              _buildFormField(
                controller: _emailController,
                label: AppStrings.email,
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: Validators.email,
              ),
              const SizedBox(height: 14),
              _buildFormField(
                controller: _phoneController,
                label: AppStrings.phone,
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: Validators.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
              ),


              const SizedBox(height: 28),

              // --- Role Selection ---
              _buildSectionTitle('Assigned Role'),
              const SizedBox(height: 12),
              _buildRoleSelectionField(),

              const SizedBox(height: 28),

              // --- Location Section ---
              _buildSectionTitle('Zone & Location'),
              const SizedBox(height: 12),
              _buildZoneField(),
              if (_showDivisionField) ...[
                const SizedBox(height: 14),
                _buildDivisionField(),
                const SizedBox(height: 14),
                _buildCityField(),
              ],
              const SizedBox(height: 14),
              _buildFormField(
                controller: _addressController,
                label: AppStrings.address,
                icon: Icons.location_on_outlined,
                maxLines: 3,
              ),
              const SizedBox(height: 14),
              _buildLocationRow(),

              const SizedBox(height: 28),

              // --- Password Section ---
              _buildSectionTitle('Security'),
              const SizedBox(height: 12),
              _buildFormField(
                controller: _passwordController,
                label: AppStrings.password,
                icon: Icons.lock_outlined,
                obscure: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: AppColors.textSubtle,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
                validator: Validators.password,
              ),
              const SizedBox(height: 14),
              _buildFormField(
                controller: _confirmPasswordController,
                label: AppStrings.confirmPassword,
                icon: Icons.lock_outline_rounded,
                obscure: _obscureConfirmPassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: AppColors.textSubtle,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() =>
                        _obscureConfirmPassword = !_obscureConfirmPassword);
                  },
                ),
                validator: (value) => Validators.confirmPassword(
                    value, _passwordController.text),
              ),

              const SizedBox(height: 36),

              // --- Submit Button ---
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentSaffron,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.accentSaffron.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 3,
                    shadowColor: AppColors.accentSaffron.withValues(alpha: 0.4),
                  ),
                  child: _isSubmitting
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              AppStrings.creatingUser,
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          AppStrings.createUser,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // --- Widget Builders ---

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildRoleBanner(String roleDisplayName, Color roleColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: roleColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: roleColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.person_add_rounded,
              color: roleColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Creating a new',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  roleDisplayName,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: roleColor,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.lock_rounded, color: roleColor.withValues(alpha: 0.5), size: 20),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffixIcon,
    int maxLines = 1,
    String? Function(String?)? validator,
    bool readOnly = false,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      maxLines: maxLines,
      readOnly: readOnly,
      inputFormatters: inputFormatters,
      style: GoogleFonts.poppins(
        fontSize: 14,
        color: AppColors.textPrimary,
      ),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(
          fontSize: 13,
          color: AppColors.textSubtle,
        ),
        prefixIcon: Icon(icon, color: AppColors.textSubtle, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
          borderSide:
              const BorderSide(color: AppColors.accentSaffron, width: 1.5),
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

  Widget _buildRoleSelectionField() {
    if (_subordinateRoles.isEmpty) return const SizedBox.shrink();
    if (_subordinateRoles.length == 1) {
      return _buildLockedRoleField(getRoleDisplayName(_subordinateRoles.first), getRoleColor(_subordinateRoles.first));
    }
    
    return DropdownButtonFormField<String>(
      value: _selectedRole,
      decoration: _dropdownDecoration(
        label: 'Select Role',
        icon: Icons.shield_rounded,
      ),
      style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textPrimary),
      dropdownColor: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      items: _subordinateRoles.map((roleStr) {
        return DropdownMenuItem(
          value: roleStr,
          child: Row(
            children: [
              Icon(Icons.shield_rounded, color: getRoleColor(roleStr), size: 18),
              const SizedBox(width: 10),
              Text(
                getRoleDisplayName(roleStr),
                style: GoogleFonts.poppins(fontSize: 14, color: getRoleColor(roleStr), fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedRole = value;
          final authState = ref.read(authProvider);
          _configureZoneDivisionFields(_creatorRole, _selectedRole, authState.user);
        });
      },
    );
  }

  Widget _buildLockedRoleField(String roleDisplayName, Color roleColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: roleColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: roleColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_rounded, color: roleColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              roleDisplayName,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: roleColor,
              ),
            ),
          ),
          Icon(Icons.lock_rounded, color: roleColor.withValues(alpha: 0.4), size: 18),
        ],
      ),
    );
  }

  /// Build zone field — either editable dropdown or locked read-only display
  Widget _buildZoneField() {
    if (_isZoneLocked) {
      // Show locked zone field
      return _buildLockedField(
        label: AppStrings.zone,
        value: _selectedZone ?? 'N/A',
        icon: Icons.location_city_outlined,
      );
    }

    // Editable zone dropdown (for Master Admin creating Super Admin)
    return DropdownButtonFormField<String>(
      initialValue: _selectedZone,
      decoration: _dropdownDecoration(
        label: AppStrings.zone,
        icon: Icons.location_city_outlined,
      ),
      style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textPrimary),
      dropdownColor: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      items: AppStrings.railwayZones.map((zone) {
        return DropdownMenuItem(
          value: zone,
          child: Text(
            zone,
            style: GoogleFonts.poppins(fontSize: 14),
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedZone = value;
          _selectedDivision = null; // Reset division when zone changes
          _selectedCity = null;
          _cities = [];
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a zone';
        }
        return null;
      },
    );
  }

  /// Build division field — cascading dropdown filtered by zone, or locked
  Widget _buildDivisionField() {
    if (_isDivisionLocked) {
      // Show locked division field
      return _buildLockedField(
        label: AppStrings.division,
        value: _selectedDivision ?? 'N/A',
        icon: Icons.map_outlined,
      );
    }

    // Get divisions for selected zone
    final divisions = RailwayData.getDivisionsForZone(_selectedZone);
    final hasDivisionOptions = divisions.isNotEmpty;
    final isEnabled = _selectedZone != null && _selectedZone!.isNotEmpty;

    return DropdownButtonFormField<String>(
      initialValue: _selectedDivision,
      decoration: _dropdownDecoration(
        label: isEnabled
            ? (hasDivisionOptions ? AppStrings.selectDivision : AppStrings.divisionComingSoon)
            : AppStrings.selectZoneFirst,
        icon: Icons.map_outlined,
      ),
      style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textPrimary),
      dropdownColor: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      items: hasDivisionOptions
          ? divisions.map((div) {
              return DropdownMenuItem(
                value: div,
                child: Text(
                  div,
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
              );
            }).toList()
          : null,
      onChanged: isEnabled && hasDivisionOptions
          ? (value) {
              setState(() {
                _selectedDivision = value;
                _selectedCity = null;
                _cities = value != null ? RailwayData.getCitiesForDivision(_selectedZone, value) : [];
              });
            }
          : null,
      validator: (value) {
        // Division is required when creating Admin (by Super Admin)
        final creatorRole = ref.read(authProvider).user?.role ?? '';
        if (creatorRole == 'super_admin' && (value == null || value.isEmpty)) {
          return 'Please select a division';
        }
        return null;
      },
    );
  }

  /// Build city field — cascading dropdown filtered by division
  Widget _buildCityField() {
    final hasCityOptions = _cities.isNotEmpty;
    final isEnabled = _selectedDivision != null && _selectedDivision!.isNotEmpty;

    return DropdownButtonFormField<String>(
      initialValue: _selectedCity,
      decoration: _dropdownDecoration(
        label: isEnabled
            ? (hasCityOptions ? AppStrings.selectCity : AppStrings.cityComingSoon)
            : AppStrings.selectDivisionFirst,
        icon: Icons.location_city_outlined,
      ),
      style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textPrimary),
      dropdownColor: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      items: hasCityOptions
          ? _cities.map((city) {
              return DropdownMenuItem(
                value: city,
                child: Text(
                  city,
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
              );
            }).toList()
          : null,
      onChanged: isEnabled && hasCityOptions
          ? (value) {
              setState(() => _selectedCity = value);
            }
          : null,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a city';
        }
        return null;
      },
    );
  }

  /// Shared dropdown decoration builder
  InputDecoration _dropdownDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(
        fontSize: 13,
        color: AppColors.textSubtle,
      ),
      prefixIcon: Icon(icon, color: AppColors.textSubtle, size: 20),
      filled: true,
      fillColor: AppColors.surface,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
        borderSide:
            const BorderSide(color: AppColors.accentSaffron, width: 1.5),
      ),
    );
  }

  /// Build a locked (read-only) field displaying zone or division
  Widget _buildLockedField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.primaryNavy.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primaryNavy.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSubtle, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textSubtle,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.lock_rounded, color: AppColors.textSubtle.withValues(alpha: 0.5), size: 16),
        ],
      ),
    );
  }

  Widget _buildLocationRow() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _latitude != null
              ? AppColors.success.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _latitude != null
                ? Icons.location_on_rounded
                : Icons.location_off_rounded,
            color: _latitude != null
                ? AppColors.success
                : AppColors.textSubtle,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.location,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textSubtle,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _latitude != null && _longitude != null
                      ? '${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}'
                      : AppStrings.locationNotFetched,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _latitude != null
                        ? AppColors.textPrimary
                        : AppColors.textSubtle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 38,
            child: ElevatedButton.icon(
              onPressed: _isFetchingLocation ? null : _fetchLocation,
              icon: _isFetchingLocation
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.my_location_rounded, size: 16),
              label: Text(
                _isFetchingLocation
                    ? 'Fetching...'
                    : (_latitude != null ? 'Refresh' : AppStrings.getLocation),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
