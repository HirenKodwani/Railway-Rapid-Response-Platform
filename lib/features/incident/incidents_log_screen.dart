import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants/colors.dart';
import '../../core/models/incident_model.dart';
import 'incident_provider.dart';
import 'create_incident_screen.dart';
import 'incident_detail_screen.dart';

/// Incidents Log Screen — shows all past and current incidents for the supervisor
class IncidentsLogScreen extends ConsumerStatefulWidget {
  const IncidentsLogScreen({super.key});

  @override
  ConsumerState<IncidentsLogScreen> createState() => _IncidentsLogScreenState();
}

class _IncidentsLogScreenState extends ConsumerState<IncidentsLogScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(incidentListProvider.notifier).fetchIncidents());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(incidentListProvider);

    if (state.isLoading && state.incidents.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accentSaffron));
    }

    if (state.errorMessage != null && state.incidents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 56, color: AppColors.error.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text(state.errorMessage!, style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(incidentListProvider.notifier).fetchIncidents(),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryNavy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text('Retry', style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (state.incidents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryNavy.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.warning_amber_rounded, size: 40, color: AppColors.primaryNavy.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 20),
            Text('No Incidents Yet', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text('Create your first incident report', style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => ref.read(incidentListProvider.notifier).fetchIncidents(),
          color: AppColors.accentSaffron,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: state.incidents.length,
            itemBuilder: (context, index) => _buildIncidentCard(state.incidents[index]),
          ),
        ),
        // FAB
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CreateIncidentScreen()),
            ),
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: Text('New Incident', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildIncidentCard(IncidentModel incident) {
    final dateStr = incident.createdAt != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(incident.createdAt!)
        : 'Unknown date';

    final statusColor = incident.status == 'active'
        ? AppColors.error
        : incident.status == 'resolved'
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
        MaterialPageRoute(builder: (_) => IncidentDetailScreen(incidentId: incident.id)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: incident.isActive ? AppColors.error.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.1),
            width: incident.isActive ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          incident.status.toUpperCase(),
                          style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor, letterSpacing: 0.5),
                        ),
                      ),
                      if (incident.isMockDrill)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                          ),
                          child: Text('DRILL', style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.warning)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Severity indicator
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: severityColors[(incident.severity - 1).clamp(0, 5)],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text('${incident.severity}', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Incident type
            Text(
              incident.incidentSubcategory,
              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              incident.incidentCategory,
              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            // Train & Date
            Row(
              children: [
                Icon(Icons.train_rounded, size: 14, color: AppColors.primaryNavy.withValues(alpha: 0.6)),
                const SizedBox(width: 4),
                Text(incident.trainNumber, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                const SizedBox(width: 16),
                Icon(Icons.schedule_rounded, size: 14, color: AppColors.textSubtle),
                const SizedBox(width: 4),
                Text(dateStr, style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
