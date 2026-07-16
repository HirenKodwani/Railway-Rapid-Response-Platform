import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants/colors.dart';
import '../incident/incident_detail_screen.dart';

class SupervisorIncidentsScreen extends ConsumerStatefulWidget {
  final String supervisorName;
  final String supervisorEmployeeId;
  final String? artTrainName;
  final List<dynamic> incidents;

  const SupervisorIncidentsScreen({
    super.key,
    required this.supervisorName,
    required this.supervisorEmployeeId,
    this.artTrainName,
    required this.incidents,
  });

  @override
  ConsumerState<SupervisorIncidentsScreen> createState() =>
      _SupervisorIncidentsScreenState();
}

class _SupervisorIncidentsScreenState
    extends ConsumerState<SupervisorIncidentsScreen> {
  // Filters
  final TextEditingController _searchController = TextEditingController();
  String? _statusFilter;
  String? _categoryFilter;
  int? _severityFilter;
  bool? _mockDrillFilter;
  DateTime? _fromDate;
  DateTime? _toDate;

  static const List<String> _categories = [
    'Accident',
    'Infrastructure Failure',
    'Natural Disaster',
    'Security Incident',
    'Passenger Emergency',
    'Operational Incident',
    'Hazardous Material',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasActiveFilters =>
      _statusFilter != null ||
      _categoryFilter != null ||
      _severityFilter != null ||
      _mockDrillFilter != null ||
      _fromDate != null ||
      _toDate != null ||
      _searchController.text.trim().isNotEmpty;

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _statusFilter = null;
      _categoryFilter = null;
      _severityFilter = null;
      _mockDrillFilter = null;
      _fromDate = null;
      _toDate = null;
    });
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _fromDate != null && _toDate != null
          ? DateTimeRange(start: _fromDate!, end: _toDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryNavy,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
    }
  }

  List<dynamic> get _filteredIncidents {
    final query = _searchController.text.trim().toLowerCase();

    return widget.incidents.where((incident) {
      // 1. Search Query
      if (query.isNotEmpty) {
        final category = (incident['incident_category'] ?? '')
            .toString()
            .toLowerCase();
        final subcategory = (incident['incident_subcategory'] ?? '')
            .toString()
            .toLowerCase();
        final trainNum = (incident['train_number'] ?? '')
            .toString()
            .toLowerCase();
        if (!category.contains(query) &&
            !subcategory.contains(query) &&
            !trainNum.contains(query)) {
          return false;
        }
      }

      // 2. Status
      if (_statusFilter != null && incident['status'] != _statusFilter) {
        return false;
      }

      // 3. Category
      if (_categoryFilter != null &&
          incident['incident_category'] != _categoryFilter) {
        return false;
      }

      // 4. Severity
      if (_severityFilter != null && incident['severity'] != _severityFilter) {
        return false;
      }

      // 5. Mock Drill
      if (_mockDrillFilter != null) {
        final isDrill = incident['is_mock_drill'] ?? false;
        if (isDrill != _mockDrillFilter) {
          return false;
        }
      }

      // 6. Date Range
      if (_fromDate != null || _toDate != null) {
        final createdAtStr = incident['createdAt'];
        if (createdAtStr == null) return false;
        final createdAt = DateTime.tryParse(createdAtStr)?.toLocal();
        if (createdAt == null) return false;

        if (_fromDate != null && createdAt.isBefore(_fromDate!)) {
          return false;
        }
        if (_toDate != null) {
          final end = DateTime(
            _toDate!.year,
            _toDate!.month,
            _toDate!.day,
            23,
            59,
            59,
          );
          if (createdAt.isAfter(end)) {
            return false;
          }
        }
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredIncidents;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reports',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${widget.supervisorName} (${widget.supervisorEmployeeId})',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            if (widget.artTrainName != null) ...[
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.train_rounded,
                    size: 12,
                    color: AppColors.accentSaffron,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.artTrainName!,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.accentSaffron,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        backgroundColor: AppColors.primaryNavy,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        ),
      ),
      body: Column(
        children: [
          _buildSearchAndFilters(),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryStats(filtered),
                  const SizedBox(height: 20),
                  Text(
                    'Incidents',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    _buildEmptyState()
                  else
                    ...filtered.map((inc) => _buildIncidentCard(context, inc)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStats(List<dynamic> filtered) {
    int total = filtered.length;
    int active = 0;
    int resolved = 0;
    int cancelled = 0;

    for (var inc in filtered) {
      final s = inc['status'];
      if (s == 'active')
        active++;
      else if (s == 'resolved')
        resolved++;
      else if (s == 'cancelled')
        cancelled++;
    }

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total',
            total.toString(),
            Icons.assessment_rounded,
            AppColors.primaryNavy,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            'Active',
            active.toString(),
            Icons.warning_rounded,
            AppColors.error,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            'Resolved',
            resolved.toString(),
            Icons.check_circle_rounded,
            AppColors.success,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            'Cancelled',
            cancelled.toString(),
            Icons.cancel_rounded,
            AppColors.textSubtle,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.poppins(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search incident, category, train...',
              hintStyle: GoogleFonts.poppins(
                color: AppColors.textSubtle,
                fontSize: 14,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.textSubtle,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear_rounded,
                        color: AppColors.textSubtle,
                        size: 20,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Colors.grey.withValues(alpha: 0.15),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.primaryNavy,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Filter chips (horizontally scrollable)
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // Date Range
                _buildFilterChip(
                  label: _fromDate != null && _toDate != null
                      ? '${DateFormat('dd MMM').format(_fromDate!)} - ${DateFormat('dd MMM').format(_toDate!)}'
                      : 'Date Range',
                  icon: Icons.calendar_today_rounded,
                  isActive: _fromDate != null,
                  onTap: _pickDateRange,
                ),
                const SizedBox(width: 8),
                // Status
                _buildDropdownChip(
                  label: _statusFilter?.toUpperCase() ?? 'Status',
                  icon: Icons.flag_rounded,
                  isActive: _statusFilter != null,
                  items: ['active', 'resolved', 'cancelled'],
                  displayItems: ['Active', 'Resolved', 'Cancelled'],
                  onSelected: (val) {
                    setState(() => _statusFilter = val);
                  },
                ),
                const SizedBox(width: 8),
                // Category
                _buildDropdownChip(
                  label: _categoryFilter ?? 'Category',
                  icon: Icons.category_rounded,
                  isActive: _categoryFilter != null,
                  items: _categories,
                  displayItems: _categories,
                  onSelected: (val) {
                    setState(() => _categoryFilter = val);
                  },
                ),
                const SizedBox(width: 8),
                // Severity
                _buildDropdownChip(
                  label: _severityFilter != null
                      ? 'Sev $_severityFilter'
                      : 'Severity',
                  icon: Icons.warning_amber_rounded,
                  isActive: _severityFilter != null,
                  items: ['1', '2', '3', '4', '5', '6'],
                  displayItems: [
                    'Level 1',
                    'Level 2',
                    'Level 3',
                    'Level 4',
                    'Level 5',
                    'Level 6',
                  ],
                  onSelected: (val) {
                    setState(() => _severityFilter = int.tryParse(val));
                  },
                ),
                const SizedBox(width: 8),
                // Mock Drill
                _buildFilterChip(
                  label: _mockDrillFilter == true
                      ? 'Drills Only'
                      : _mockDrillFilter == false
                      ? 'Real Only'
                      : 'Mock Drill',
                  icon: Icons.sports_score_rounded,
                  isActive: _mockDrillFilter != null,
                  onTap: () {
                    setState(() {
                      if (_mockDrillFilter == null) {
                        _mockDrillFilter = true;
                      } else if (_mockDrillFilter == true) {
                        _mockDrillFilter = false;
                      } else {
                        _mockDrillFilter = null;
                      }
                    });
                  },
                ),
                const SizedBox(width: 8),
                // Clear all
                if (_hasActiveFilters)
                  _buildFilterChip(
                    label: 'Clear All',
                    icon: Icons.clear_all_rounded,
                    isActive: false,
                    isDestructive: true,
                    onTap: _clearFilters,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDestructive
              ? AppColors.error.withValues(alpha: 0.08)
              : isActive
              ? AppColors.primaryNavy.withValues(alpha: 0.1)
              : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDestructive
                ? AppColors.error.withValues(alpha: 0.4)
                : isActive
                ? AppColors.primaryNavy.withValues(alpha: 0.5)
                : Colors.grey.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isDestructive
                  ? AppColors.error
                  : isActive
                  ? AppColors.primaryNavy
                  : AppColors.textSubtle,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isDestructive
                    ? AppColors.error
                    : isActive
                    ? AppColors.primaryNavy
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownChip({
    required String label,
    required IconData icon,
    required bool isActive,
    required List<String> items,
    required List<String> displayItems,
    required Function(String) onSelected,
  }) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => List.generate(items.length, (i) {
        return PopupMenuItem<String>(
          value: items[i],
          child: Text(
            displayItems[i],
            style: GoogleFonts.poppins(fontSize: 13),
          ),
        );
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primaryNavy.withValues(alpha: 0.1)
              : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? AppColors.primaryNavy.withValues(alpha: 0.5)
                : Colors.grey.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? AppColors.primaryNavy : AppColors.textSubtle,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive
                    ? AppColors.primaryNavy
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 16,
              color: isActive ? AppColors.primaryNavy : AppColors.textSubtle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncidentCard(BuildContext context, dynamic incidentData) {
    // Parse from raw JSON map
    final id =
        incidentData['_id']?.toString() ?? incidentData['id']?.toString() ?? '';
    final status = incidentData['status'] ?? 'active';
    final category = incidentData['incident_category'] ?? '';
    final subcategory = incidentData['incident_subcategory'] ?? '';
    final trainNumber = incidentData['train_number'] ?? '';
    final severity = incidentData['severity'] ?? 1;
    final isMockDrill = incidentData['is_mock_drill'] ?? false;
    final createdAt = incidentData['createdAt'] != null
        ? DateTime.tryParse(incidentData['createdAt'])?.toLocal()
        : null;

    final dateStr = createdAt != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(createdAt)
        : 'Unknown date';

    final statusColor = status == 'active'
        ? AppColors.error
        : status == 'resolved'
        ? AppColors.success
        : AppColors.textSubtle;

    final severityColors = [
      const Color(0xFF4CAF50),
      const Color(0xFF8BC34A),
      const Color(0xFFFFC107),
      const Color(0xFFFF9800),
      const Color(0xFFFF5722),
      const Color(0xFFD50000),
    ];

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => IncidentDetailScreen(incidentId: id)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: status == 'active'
                ? AppColors.error.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.1),
            width: status == 'active' ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status.toString().toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      if (isMockDrill)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.warning.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            'DRILL',
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Severity indicator
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: severityColors[(severity as int).clamp(1, 6) - 1],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$severity',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Incident type
            Text(
              subcategory,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              category,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            // Train & Date
            Row(
              children: [
                Icon(
                  Icons.train_rounded,
                  size: 14,
                  color: AppColors.primaryNavy.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  trainNumber,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.schedule_rounded,
                  size: 14,
                  color: AppColors.textSubtle,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    dateStr,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            // Report status
            if (incidentData['reportUrl'] != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.picture_as_pdf_rounded,
                      size: 12,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Report Available',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
            child: Icon(
              Icons.warning_amber_rounded,
              size: 40,
              color: AppColors.primaryNavy.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No Incidents',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This supervisor has no incidents matching your filters',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
