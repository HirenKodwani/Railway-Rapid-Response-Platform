import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/strings.dart';
import '../../core/constants/specialisations.dart';
import '../../core/models/user_model.dart';
import '../../core/services/art_train_service.dart';
import '../auth/auth_provider.dart';
import 'package:intl/intl.dart';

class OperatorSelectionPanel extends ConsumerStatefulWidget {
  final String trainId;

  const OperatorSelectionPanel({super.key, required this.trainId});

  @override
  ConsumerState<OperatorSelectionPanel> createState() => _OperatorSelectionPanelState();
}

class _OperatorSelectionPanelState extends ConsumerState<OperatorSelectionPanel> {
  List<UserModel> _availableOperators = [];
  bool _isLoading = true;
  String? _error;
  final Set<String> _selectedIds = {};
  String _searchQuery = '';
  String _sortBy = 'name';
  String? _expandedOperatorId;

  List<UserModel> get _filteredAndSortedOperators {
    var list = _availableOperators.where((op) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return op.name.toLowerCase().contains(query) ||
             (op.city?.toLowerCase().contains(query) ?? false) ||
             (op.employeeId?.toLowerCase().contains(query) ?? false);
    }).toList();

    list.sort((a, b) {
      if (_sortBy == 'name') {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      } else if (_sortBy == 'city') {
        final cityA = a.city ?? 'zzzzz';
        final cityB = b.city ?? 'zzzzz';
        return cityA.toLowerCase().compareTo(cityB.toLowerCase());
      }
      return 0;
    });

    return list;
  }

  @override
  void initState() {
    super.initState();
    _fetchOperators();
  }

  Future<void> _fetchOperators() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final token = ref.read(authProvider).token;
    if (token == null) return;

    final result = await ArtTrainService.getAvailableOperators(token: token, trainId: widget.trainId);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.success) {
          _availableOperators = result.data ?? [];
        } else {
          _error = result.message;
        }
      });
    }
  }

  Future<void> _handleAddSelected() async {
    if (_selectedIds.isEmpty) return;

    final token = ref.read(authProvider).token;
    if (token == null) return;

    setState(() => _isLoading = true);

    final result = await ArtTrainService.addOperators(
      token: token,
      trainId: widget.trainId,
      operatorIds: _selectedIds.toList(),
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? 'Operators added'), backgroundColor: AppColors.success),
        );
        Navigator.pop(context, true); // Return true to indicate success
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? 'Failed to add'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppStrings.availableOperators, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          const SizedBox(height: 16),
          // --- Search and Sort Controls ---
          if (!_isLoading && _availableOperators.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search by name, ID, or city...',
                      hintStyle: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSubtle),
                      prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textSubtle),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _sortBy,
                      icon: const Icon(Icons.sort_rounded, size: 16, color: AppColors.textSecondary),
                      style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textPrimary),
                      dropdownColor: AppColors.surface,
                      items: const [
                        DropdownMenuItem(value: 'name', child: Text('Name')),
                        DropdownMenuItem(value: 'city', child: Text('City')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _sortBy = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: AppColors.accentSaffron)))
          else if (_error != null)
            Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_error!, style: GoogleFonts.poppins(color: AppColors.error))))
          else if (_availableOperators.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('No approved operators available in this division.', style: GoogleFonts.poppins(color: AppColors.textSecondary)),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _filteredAndSortedOperators.length,
                separatorBuilder: (context, index) => Divider(color: Colors.grey.withValues(alpha: 0.15)),
                itemBuilder: (context, index) {
                  final op = _filteredAndSortedOperators[index];
                  final isSelected = _selectedIds.contains(op.id);
                  final isExpanded = _expandedOperatorId == op.id;

                  final specColor = Specialisations.getColor(op.specialisation);
                  final specLabel = Specialisations.getLabel(op.specialisation);

                  return Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Row(
                          children: [
                            Expanded(child: Text(op.name, style: GoogleFonts.poppins(color: AppColors.textPrimary))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: specColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: specColor.withValues(alpha: 0.3)),
                              ),
                              child: Text(specLabel, style: GoogleFonts.poppins(color: specColor, fontSize: 10, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${op.employeeId ?? ''} • ${op.phone}', style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12)),
                            if (op.city != null && op.city!.isNotEmpty)
                              Text('📍 ${op.city}', style: GoogleFonts.poppins(color: AppColors.roleSupervisor, fontSize: 11, fontWeight: FontWeight.w500)),
                          ],
                        ),
                        leading: Checkbox(
                          value: isSelected,
                          activeColor: AppColors.accentSaffron,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedIds.add(op.id);
                              } else {
                                _selectedIds.remove(op.id);
                              }
                            });
                          },
                        ),
                        trailing: IconButton(
                          icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: AppColors.textSecondary),
                          onPressed: () {
                            setState(() {
                              _expandedOperatorId = isExpanded ? null : op.id;
                            });
                          },
                        ),
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedIds.remove(op.id);
                            } else {
                              _selectedIds.add(op.id);
                            }
                          });
                        },
                      ),
                      if (isExpanded)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(left: 48, right: 16, bottom: 8),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDetailRow(Icons.person_outline, 'Full Name', op.name),
                              _buildDetailRow(Icons.badge_outlined, 'Role', 'Operator'),
                              if (op.createdAt != null)
                                _buildDetailRow(Icons.calendar_today_outlined, 'Registered', DateFormat('MMM d, yyyy').format(op.createdAt!)),
                              _buildDetailRow(Icons.train_outlined, 'ART Assignment', 'Unassigned'), // Simplified for now as we don't have this in UserModel
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _selectedIds.isEmpty || _isLoading ? null : _handleAddSelected,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentSaffron,
                foregroundColor: AppColors.textLight,
                disabledBackgroundColor: AppColors.accentSaffron.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Add Selected (${_selectedIds.length})', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.textSubtle),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textPrimary),
                children: [
                  TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
