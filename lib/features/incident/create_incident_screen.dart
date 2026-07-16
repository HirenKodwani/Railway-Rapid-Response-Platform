import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/incident_data.dart';
import '../../core/constants/specialisations.dart';
import '../../core/services/incident_service.dart';
import '../../core/services/location_service.dart';
import '../auth/auth_provider.dart';
import 'incident_provider.dart';
import 'map_picker_screen.dart';
import 'incident_detail_screen.dart';

class CreateIncidentScreen extends ConsumerStatefulWidget {
  const CreateIncidentScreen({super.key});

  @override
  ConsumerState<CreateIncidentScreen> createState() => _CreateIncidentScreenState();
}

class _CreateIncidentScreenState extends ConsumerState<CreateIncidentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _trainNumberController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  String? _selectedCategory;
  String? _selectedSubcategory;
  String? _selectedComponent;
  int _severity = 1;
  bool _isMockDrill = false;
  final Set<String> _selectedSpecialisations = {};
  bool _useMapPicker = false;
  bool _isSubmitting = false;

  final List<Color> _severityColors = [
    const Color(0xFF4CAF50), // Green
    const Color(0xFF8BC34A), // Light green
    const Color(0xFFFFC107), // Amber
    const Color(0xFFFF9800), // Orange
    const Color(0xFFFF5722), // Deep orange
    const Color(0xFFD50000), // Red
  ];

  @override
  void dispose() {
    _trainNumberController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentLocation() async {
    final result = await LocationService.getCurrentLocation();
    if (result.success && mounted) {
      setState(() {
        _latController.text = result.latitude!.toStringAsFixed(6);
        _lngController.text = result.longitude!.toStringAsFixed(6);
      });
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Failed to get location')),
      );
    }
  }

  Future<void> _openMapPicker() async {
    final result = await Navigator.of(context).push<Map<String, double>>(
      MaterialPageRoute(builder: (_) => const MapPickerScreen()),
    );
    if (result != null && mounted) {
      setState(() {
        _latController.text = result['latitude']!.toStringAsFixed(6);
        _lngController.text = result['longitude']!.toStringAsFixed(6);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null || _selectedSubcategory == null || _selectedComponent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields.')),
      );
      return;
    }

    if (_selectedSpecialisations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one operator specialisation to notify.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final token = ref.read(authProvider).token;
    if (token == null) return;

    final result = await IncidentService.createIncident(
      token: token,
      trainNumber: _trainNumberController.text.trim(),
      latitude: double.parse(_latController.text.trim()),
      longitude: double.parse(_lngController.text.trim()),
      incidentCategory: _selectedCategory!,
      incidentSubcategory: _selectedSubcategory!,
      affectedComponent: _selectedComponent!,
      severity: _severity,
      requiredSpecialisations: _selectedSpecialisations.toList(),
      isMockDrill: _isMockDrill,
    );

    setState(() => _isSubmitting = false);

    if (mounted) {
      if (result.success) {
        ref.read(incidentListProvider.notifier).fetchIncidents();
        ref.read(activeIncidentProvider.notifier).fetchActiveIncident();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'Incident created!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => IncidentDetailScreen(incidentId: result.data!.id)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'Failed to create incident.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Incident', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.primaryNavy,
        foregroundColor: Colors.white,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppColors.darkGradient)),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Train Number
              _buildSectionLabel('Train Number'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _trainNumberController,
                decoration: _inputDecoration('e.g., 12345', Icons.train_rounded),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 20),

              // Location
              _buildSectionLabel('Incident Location'),
              const SizedBox(height: 8),
              _buildLocationToggle(),
              const SizedBox(height: 12),
              if (_useMapPicker)
                _buildMapPickerSection()
              else
                _buildManualLocationSection(),
              const SizedBox(height: 20),

              // Category
              _buildSectionLabel('Incident Category'),
              const SizedBox(height: 8),
              _buildDropdown(
                value: _selectedCategory,
                items: IncidentData.categories,
                hint: 'Select category',
                icon: Icons.category_rounded,
                onChanged: (val) {
                  setState(() {
                    _selectedCategory = val;
                    _selectedSubcategory = null;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Sub-category
              _buildSectionLabel('Sub-Category'),
              const SizedBox(height: 8),
              _buildDropdown(
                value: _selectedSubcategory,
                items: _selectedCategory != null
                    ? (IncidentData.subcategories[_selectedCategory] ?? [])
                    : [],
                hint: _selectedCategory != null ? 'Select sub-category' : 'Select category first',
                icon: Icons.list_alt_rounded,
                onChanged: _selectedCategory != null
                    ? (val) => setState(() => _selectedSubcategory = val)
                    : null,
              ),
              const SizedBox(height: 20),

              // Affected Component
              _buildSectionLabel('Affected Component / Asset'),
              const SizedBox(height: 8),
              _buildDropdown(
                value: _selectedComponent,
                items: IncidentData.affectedComponents,
                hint: 'Select component',
                icon: Icons.directions_railway_rounded,
                onChanged: (val) => setState(() => _selectedComponent = val),
              ),
              const SizedBox(height: 20),

              // Severity
              _buildSectionLabel('Severity Level'),
              const SizedBox(height: 12),
              _buildSeverityBar(),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  IncidentData.severityLabels[_severity - 1],
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _severityColors[_severity - 1],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Operator Specialisations
              _buildSectionLabel('Notify Operator Specialisations'),
              const SizedBox(height: 8),
              _buildSpecialisationsCheckboxes(),
              const SizedBox(height: 20),

              // Mock Drill Toggle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _isMockDrill ? AppColors.warning.withValues(alpha: 0.5) : Colors.grey.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.flag_rounded, color: AppColors.warning, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mock Drill', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          Text('Mark as a practice exercise', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isMockDrill,
                      onChanged: (val) => setState(() => _isMockDrill = val),
                      activeColor: AppColors.warning,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Submit
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 3,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Text('🚨  Trigger Incident Alert', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSubtle),
      prefixIcon: Icon(icon, color: AppColors.primaryNavy, size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.accentSaffron, width: 1.5)),
    );
  }

  Widget _buildLocationToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Expanded(child: _toggleOption('Manual', !_useMapPicker, () => setState(() => _useMapPicker = false))),
          Expanded(child: _toggleOption('Map Picker', _useMapPicker, () => setState(() => _useMapPicker = true))),
        ],
      ),
    );
  }

  Widget _toggleOption(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryNavy : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildManualLocationSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _latController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: _inputDecoration('Latitude', Icons.my_location_rounded),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _lngController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: _inputDecoration('Longitude', Icons.my_location_rounded),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _fetchCurrentLocation,
            icon: const Icon(Icons.gps_fixed_rounded, size: 16),
            label: Text('Use My Location', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ),
      ],
    );
  }

  Widget _buildMapPickerSection() {
    return Column(
      children: [
        if (_latController.text.isNotEmpty && _lngController.text.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Location: ${_latController.text}, ${_lngController.text}',
                    style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _openMapPicker,
            icon: const Icon(Icons.map_rounded),
            label: Text(_latController.text.isEmpty ? 'Pick Location on Map' : 'Change Location',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              side: const BorderSide(color: AppColors.primaryNavy),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required String hint,
    required IconData icon,
    required ValueChanged<String?>? onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(item, style: GoogleFonts.poppins(fontSize: 13)))).toList(),
      onChanged: onChanged,
      decoration: _inputDecoration(hint, icon),
      isExpanded: true,
      hint: Text(hint, style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSubtle)),
    );
  }

  Widget _buildSeverityBar() {
    return Row(
      children: List.generate(6, (index) {
        final level = index + 1;
        final isSelected = _severity == level;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _severity = level),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: isSelected ? 48 : 38,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: isSelected ? _severityColors[index] : _severityColors[index].withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(8),
                border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
                boxShadow: isSelected
                    ? [BoxShadow(color: _severityColors[index].withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2))]
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                '$level',
                style: GoogleFonts.poppins(
                  fontSize: isSelected ? 16 : 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : _severityColors[index],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSpecialisationsCheckboxes() {
    bool? selectAllTristate;
    if (_selectedSpecialisations.isEmpty) {
      selectAllTristate = false;
    } else if (_selectedSpecialisations.length == Specialisations.ids.length) {
      selectAllTristate = true;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          CheckboxListTile(
            title: Text('Select All', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            value: selectAllTristate,
            tristate: true,
            activeColor: AppColors.accentSaffron,
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  _selectedSpecialisations.addAll(Specialisations.ids);
                } else {
                  _selectedSpecialisations.clear();
                }
              });
            },
          ),
          const Divider(height: 1),
          ...Specialisations.ids.map((id) {
            final isChecked = _selectedSpecialisations.contains(id);
            return CheckboxListTile(
              title: Text(Specialisations.getLabel(id), style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textPrimary)),
              value: isChecked,
              activeColor: AppColors.accentSaffron,
              dense: true,
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedSpecialisations.add(id);
                  } else {
                    _selectedSpecialisations.remove(id);
                  }
                });
              },
            );
          }),
        ],
      ),
    );
  }
}
