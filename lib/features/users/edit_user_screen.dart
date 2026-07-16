import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/roles.dart';
import '../../core/constants/strings.dart';
import '../../core/constants/railway_data.dart';
import '../../core/models/user_model.dart';
import '../../core/utils/validators.dart';
import 'user_provider.dart';

/// Edit User Screen — pre-filled form for editing existing user data
/// Zone and Division fields follow same auto-fill/lock rules as creation
class EditUserScreen extends ConsumerStatefulWidget {
  final UserModel user;

  const EditUserScreen({super.key, required this.user});

  @override
  ConsumerState<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends ConsumerState<EditUserScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _employeeIdController;
  late final TextEditingController _addressController;
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // State
  String? _selectedZone;
  String? _selectedDivision;
  String? _selectedCity;
  List<String> _cities = [];
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Hierarchy-based field control
  bool _isZoneLocked = false;
  bool _isDivisionLocked = false;
  bool _showDivisionField = true;

  @override
  void initState() {
    super.initState();

    // Pre-fill controllers from existing user data
    _nameController = TextEditingController(text: widget.user.name);
    _emailController = TextEditingController(text: widget.user.email);
    _phoneController = TextEditingController(text: widget.user.phone);
    _employeeIdController = TextEditingController(text: widget.user.employeeId);
    _addressController = TextEditingController(text: widget.user.address ?? '');

    _selectedZone = widget.user.zone;
    _selectedDivision = widget.user.division;
    _selectedCity = widget.user.city;
    
    if (_selectedZone != null && _selectedDivision != null) {
      _cities = RailwayData.getCitiesForDivision(_selectedZone!, _selectedDivision!);
    }

    // Configure zone/division lock based on the target user's role
    _configureZoneDivisionFields();
  }

  void _configureZoneDivisionFields() {
    final targetRole = widget.user.role;

    switch (targetRole) {
      case 'super_admin':
        // Super Admin owns their zone, no division
        _isZoneLocked = false;
        _isDivisionLocked = false;
        _showDivisionField = false;
        break;

      case 'admin':
        // Admin: zone locked from creator, division editable
        _isZoneLocked = true;
        _isDivisionLocked = false;
        _showDivisionField = true;
        break;

      case 'lead_supervisor':
      case 'supervisor':
      case 'operator':
        // Zone and division locked from creator
        _isZoneLocked = true;
        _isDivisionLocked = true;
        _showDivisionField = true;
        break;

      default:
        _isZoneLocked = false;
        _isDivisionLocked = false;
        _showDivisionField = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _employeeIdController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final userData = <String, dynamic>{
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'employee_id': _employeeIdController.text.trim(),
      'address': _addressController.text.trim(),
    };

    if (!_isZoneLocked) {
      userData['zone'] = _selectedZone;
    }
    if (!_isDivisionLocked && _showDivisionField) {
      userData['division'] = _selectedDivision;
    }
    
    // Always include city if available
    if (_selectedCity != null) {
      userData['city'] = _selectedCity;
    }

    // Include password only if provided
    if (_passwordController.text.isNotEmpty) {
      userData['password'] = _passwordController.text;
    }

    final success = await ref
        .read(userListProvider.notifier)
        .updateUser(widget.user.id, userData);

    setState(() => _isSubmitting = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.userUpdated,
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      Navigator.of(context).pop(true); // Return true to indicate success
    } else if (mounted) {
      final errorMsg = ref.read(userListProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMsg ?? 'Failed to update user',
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
    final roleColor = getRoleColor(widget.user.role);
    final roleDisplayName = getRoleDisplayName(widget.user.role);

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
          AppStrings.editUser,
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
              // --- Role banner (locked) ---
              _buildRoleBanner(roleDisplayName, roleColor),
              const SizedBox(height: 24),

              // --- Personal Information ---
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
              const SizedBox(height: 14),
              _buildFormField(
                controller: _employeeIdController,
                label: AppStrings.employeeId,
                icon: Icons.badge_outlined,
                validator: Validators.employeeId,
              ),

              const SizedBox(height: 28),

              // --- Role (locked) ---
              _buildSectionTitle('Role'),
              const SizedBox(height: 12),
              _buildLockedRoleField(roleDisplayName, roleColor),

              const SizedBox(height: 28),

              // --- Zone & Division ---
              _buildSectionTitle('Zone & Division'),
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

              const SizedBox(height: 28),

              // --- Password (optional) ---
              _buildSectionTitle('Change Password (Optional)'),
              const SizedBox(height: 4),
              Text(
                'Leave blank to keep current password',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.textSubtle,
                ),
              ),
              const SizedBox(height: 12),
              _buildFormField(
                controller: _passwordController,
                label: 'New Password',
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
                validator: (value) {
                  // Password is optional on edit; validate only if provided
                  if (value != null && value.isNotEmpty && value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _buildFormField(
                controller: _confirmPasswordController,
                label: 'Confirm New Password',
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
                validator: (value) {
                  if (_passwordController.text.isNotEmpty) {
                    return Validators.confirmPassword(
                        value, _passwordController.text);
                  }
                  return null;
                },
              ),

              const SizedBox(height: 36),

              // --- Save Button ---
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
                    shadowColor:
                        AppColors.accentSaffron.withValues(alpha: 0.4),
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
                              AppStrings.updatingUser,
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          'Save Changes',
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
              Icons.edit_rounded,
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
                  'Editing',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  widget.user.name,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: roleColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              roleDisplayName,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: roleColor,
              ),
            ),
          ),
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
          Icon(Icons.lock_rounded,
              color: roleColor.withValues(alpha: 0.4), size: 18),
        ],
      ),
    );
  }

  Widget _buildZoneField() {
    if (_isZoneLocked) {
      return _buildLockedField(
        label: AppStrings.zone,
        value: _selectedZone ?? 'N/A',
        icon: Icons.location_city_outlined,
      );
    }

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
          child: Text(zone, style: GoogleFonts.poppins(fontSize: 14)),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedZone = value;
          _selectedDivision = null;
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

  Widget _buildDivisionField() {
    if (_isDivisionLocked) {
      return _buildLockedField(
        label: AppStrings.division,
        value: _selectedDivision ?? 'N/A',
        icon: Icons.map_outlined,
      );
    }

    final divisions = RailwayData.getDivisionsForZone(_selectedZone);
    final hasDivisionOptions = divisions.isNotEmpty;
    final isEnabled = _selectedZone != null && _selectedZone!.isNotEmpty;

    return DropdownButtonFormField<String>(
      initialValue: _selectedDivision,
      decoration: _dropdownDecoration(
        label: isEnabled
            ? (hasDivisionOptions
                ? AppStrings.selectDivision
                : AppStrings.divisionComingSoon)
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
                child: Text(div, style: GoogleFonts.poppins(fontSize: 14)),
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
    );
  }

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
                child: Text(city, style: GoogleFonts.poppins(fontSize: 14)),
              );
            }).toList()
          : null,
      onChanged: isEnabled && hasCityOptions
          ? (value) {
              setState(() => _selectedCity = value);
            }
          : null,
    );
  }

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
          Icon(Icons.lock_rounded,
              color: AppColors.textSubtle.withValues(alpha: 0.5), size: 16),
        ],
      ),
    );
  }
}
