import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants/colors.dart';
import '../../core/services/lead_supervisor_service.dart';
import '../../core/services/auth_service.dart';
import '../auth/auth_provider.dart';
import 'supervisor_incidents_screen.dart';

/// Lead Supervisor Reports Screen — dashboard with search, filters, stats, and supervisor list
class LsReportsScreen extends ConsumerStatefulWidget {
  final String? division;
  const LsReportsScreen({super.key, this.division});

  @override
  ConsumerState<LsReportsScreen> createState() => _LsReportsScreenState();
}

class _LsReportsScreenState extends ConsumerState<LsReportsScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  List<dynamic> _supervisors = [];
  Map<String, dynamic> _summary = {};

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
  void initState() {
    super.initState();
    _fetchReports();
  }

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
      _toDate != null;

  Future<void> _fetchReports() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final token = ref.read(authProvider).token;
    if (token == null) return;

    final result = await LeadSupervisorService.getReports(
      token: token,
      division: widget.division,
      status: _statusFilter,
      category: _categoryFilter,
      severity: _severityFilter,
      fromDate: _fromDate != null
          ? DateFormat('yyyy-MM-dd').format(_fromDate!)
          : null,
      toDate:
          _toDate != null ? DateFormat('yyyy-MM-dd').format(_toDate!) : null,
      search: _searchController.text.trim().isNotEmpty
          ? _searchController.text.trim()
          : null,
      isMockDrill: _mockDrillFilter,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.success && result.data != null) {
          _supervisors = result.data!['supervisors'] ?? [];
          _summary = result.data!['summary'] ?? {};
        } else {
          _errorMessage = result.message ?? 'Failed to load reports.';
        }
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _statusFilter = null;
      _categoryFilter = null;
      _severityFilter = null;
      _mockDrillFilter = null;
      _fromDate = null;
      _toDate = null;
      _searchController.clear();
    });
    _fetchReports();
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _fromDate != null && _toDate != null
          ? DateTimeRange(start: _fromDate!, end: _toDate!)
          : null,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primaryNavy,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
      _fetchReports();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reports',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.primaryNavy,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppColors.darkGradient)),
      ),
      body: Column(
        children: [
          // Search + Filters
          _buildSearchAndFilters(),
          // Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.accentSaffron))
                : _errorMessage != null
                    ? _buildErrorState()
                    : RefreshIndicator(
                        onRefresh: _fetchReports,
                        color: AppColors.accentSaffron,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics()),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSummaryStats(),
                              const SizedBox(height: 20),
                              Text('Supervisors',
                                  style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary)),
                              const SizedBox(height: 12),
                              if (_supervisors.isEmpty)
                                _buildEmptyState()
                              else
                                ..._supervisors
                                    .map((sup) => _buildSupervisorCard(sup)),
                            ],
                          ),
                        ),
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
            onSubmitted: (_) => _fetchReports(),
            style: GoogleFonts.poppins(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search supervisor or train...',
              hintStyle: GoogleFonts.poppins(
                  color: AppColors.textSubtle, fontSize: 14),
              prefixIcon:
                  const Icon(Icons.search_rounded, color: AppColors.textSubtle),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded,
                          color: AppColors.textSubtle, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        _fetchReports();
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.background,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: AppColors.primaryNavy, width: 1.5)),
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
                    _fetchReports();
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
                    _fetchReports();
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
                    'Level 6'
                  ],
                  onSelected: (val) {
                    setState(() => _severityFilter = int.tryParse(val));
                    _fetchReports();
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
                    _fetchReports();
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
            Icon(icon,
                size: 14,
                color: isDestructive
                    ? AppColors.error
                    : isActive
                        ? AppColors.primaryNavy
                        : AppColors.textSubtle),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    color: isDestructive
                        ? AppColors.error
                        : isActive
                            ? AppColors.primaryNavy
                            : AppColors.textSecondary)),
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
          child: Text(displayItems[i], style: GoogleFonts.poppins(fontSize: 13)),
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
            Icon(icon,
                size: 14,
                color: isActive
                    ? AppColors.primaryNavy
                    : AppColors.textSubtle),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    color: isActive
                        ? AppColors.primaryNavy
                        : AppColors.textSecondary)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down_rounded,
                size: 16,
                color: isActive
                    ? AppColors.primaryNavy
                    : AppColors.textSubtle),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStats() {
    final total = _summary['totalIncidents'] ?? 0;
    final active = _summary['active'] ?? 0;
    final resolved = _summary['resolved'] ?? 0;
    final cancelled = _summary['cancelled'] ?? 0;

    return Row(
      children: [
        Expanded(
            child: _buildStatCard('Total', total.toString(),
                Icons.assessment_rounded, AppColors.primaryNavy)),
        const SizedBox(width: 10),
        Expanded(
            child: _buildStatCard(
                'Active', active.toString(), Icons.warning_rounded, AppColors.error)),
        const SizedBox(width: 10),
        Expanded(
            child: _buildStatCard('Resolved', resolved.toString(),
                Icons.check_circle_rounded, AppColors.success)),
        const SizedBox(width: 10),
        Expanded(
            child: _buildStatCard('Cancelled', cancelled.toString(),
                Icons.cancel_rounded, AppColors.textSubtle)),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildSupervisorCard(dynamic sup) {
    final name = sup['name'] ?? 'Unknown';
    final employeeId = sup['employeeId'] ?? '';
    final totalIncidents = sup['totalIncidents'] ?? 0;
    final active = sup['active'] ?? 0;
    final resolved = sup['resolved'] ?? 0;
    final cancelled = sup['cancelled'] ?? 0;
    final avgResponse = sup['avgResponseTimeMinutes'];
    final artTrain = sup['artTrain'];
    final artTrainName = artTrain != null ? artTrain['name'] : null;

    // Color-coded performance indicator
    Color performanceColor;
    String performanceLabel;
    if (avgResponse == null) {
      performanceColor = AppColors.textSubtle;
      performanceLabel = 'No data';
    } else if (avgResponse <= 10) {
      performanceColor = AppColors.success;
      performanceLabel = '${avgResponse.toStringAsFixed(1)} min';
    } else if (avgResponse <= 20) {
      performanceColor = const Color(0xFFFFA000); // amber
      performanceLabel = '${avgResponse.toStringAsFixed(1)} min';
    } else {
      performanceColor = AppColors.error;
      performanceLabel = '${avgResponse.toStringAsFixed(1)} min';
    }

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SupervisorIncidentsScreen(
              supervisorName: name,
              supervisorEmployeeId: employeeId,
              artTrainName: artTrainName,
              incidents: sup['incidents'] ?? [],
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Name + Performance badge
            Row(
              children: [
                // Avatar with performance ring
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: performanceColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: performanceColor.withValues(alpha: 0.5),
                        width: 2),
                  ),
                  child:
                      Icon(Icons.person_rounded, color: performanceColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (artTrainName != null) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.train_rounded, size: 12, color: AppColors.primaryNavy),
                            const SizedBox(width: 4),
                            Text(artTrainName,
                                style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryNavy)),
                          ],
                        ),
                        const SizedBox(height: 2),
                      ] else ...[
                        Text('No ART Train Assigned',
                            style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                                color: AppColors.textSubtle)),
                        const SizedBox(height: 2),
                      ],
                      Text(name,
                          style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      Text('ID: $employeeId',
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                // Avg Response badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: performanceColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: performanceColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.speed_rounded,
                          size: 12, color: performanceColor),
                      const SizedBox(width: 4),
                      Text(performanceLabel,
                          style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: performanceColor)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Incident count badges
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildCountBadge('Total', totalIncidents, AppColors.primaryNavy),
                      _buildCountBadge('Active', active, AppColors.error),
                      _buildCountBadge('Resolved', resolved, AppColors.success),
                      _buildCountBadge('Cancelled', cancelled, AppColors.textSubtle),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: AppColors.textSubtle),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountBadge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text('$count',
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color)),
          const SizedBox(width: 3),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: color.withValues(alpha: 0.8))),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
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
              child: Icon(Icons.assessment_rounded,
                  size: 40,
                  color: AppColors.primaryNavy.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 20),
            Text(
              _hasActiveFilters
                  ? 'No Results Found'
                  : 'No Supervisors Yet',
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              _hasActiveFilters
                  ? 'Try adjusting your filters'
                  : 'There are no supervisors in your division',
              style: GoogleFonts.poppins(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
            if (_hasActiveFilters) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.clear_all_rounded, size: 18),
                label: Text('Clear Filters',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 56, color: AppColors.error.withValues(alpha: 0.6)),
          const SizedBox(height: 16),
          Text(_errorMessage!,
              style: GoogleFonts.poppins(
                  fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchReports,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child:
                Text('Retry', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
