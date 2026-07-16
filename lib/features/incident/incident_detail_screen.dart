import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/strings.dart';
import '../../core/models/incident_model.dart';
import '../../core/services/incident_service.dart';
import '../auth/auth_provider.dart';
import 'incident_provider.dart';
import 'incident_map_screen.dart';
import 'proof_upload_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

/// Detail screen for a single incident
class IncidentDetailScreen extends ConsumerStatefulWidget {
  final String incidentId;
  const IncidentDetailScreen({super.key, required this.incidentId});

  @override
  ConsumerState<IncidentDetailScreen> createState() => _IncidentDetailScreenState();
}

class _IncidentDetailScreenState extends ConsumerState<IncidentDetailScreen> {
  IncidentModel? _incident;
  bool _isLoading = true;
  bool _isResolving = false;

  List<dynamic> _acceptanceLog = [];
  double? _avgAcceptanceDelay;
  List<dynamic> _attendanceLog = [];
  List<dynamic> _responseLog = [];
  double? _avgResponseTime;
  bool _isLogsLoading = true;

  final List<Color> _severityColors = [
    const Color(0xFF4CAF50), const Color(0xFF8BC34A), const Color(0xFFFFC107),
    const Color(0xFFFF9800), const Color(0xFFFF5722), const Color(0xFFD50000),
  ];

  List<dynamic> _proofs = [];
  bool _isProofsLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchIncident();
  }

  Future<void> _fetchIncident() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;

    final result = await IncidentService.getIncident(token: token, incidentId: widget.incidentId);
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.success) _incident = result.data;
      });
    }

    if (result.success) {
      await Future.wait([_fetchLogs(), _fetchProofs()]);
    }
  }

  Future<void> _fetchProofs() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    
    final result = await IncidentService.getProofs(token: token, incidentId: widget.incidentId);
    if (mounted) {
      setState(() {
        if (result.success && result.data != null) {
          _proofs = result.data as List<dynamic>;
        }
        _isProofsLoading = false;
      });
    }
  }

  Future<void> _fetchLogs() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    
    // Fetch logs concurrently
    final futures = await Future.wait([
      IncidentService.getAcceptanceLog(token: token, incidentId: widget.incidentId),
      IncidentService.getAttendanceLog(token: token, incidentId: widget.incidentId),
      IncidentService.getResponseLog(token: token, incidentId: widget.incidentId),
    ]);

    if (mounted) {
      setState(() {
        if (futures[0].success && futures[0].data != null) {
          _acceptanceLog = futures[0].data!['logs'] ?? [];
          _avgAcceptanceDelay = futures[0].data!['averageAcceptanceDelayMinutes']?.toDouble();
        }
        if (futures[1].success && futures[1].data != null) {
          _attendanceLog = futures[1].data!['logs'] ?? [];
        }
        if (futures[2].success && futures[2].data != null) {
          _responseLog = futures[2].data!['logs'] ?? [];
          _avgResponseTime = futures[2].data!['averageResponseTimeMinutes']?.toDouble();
        }
        _isLogsLoading = false;
      });
    }
  }

  Future<void> _resolveIncident() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Resolve Incident', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to mark this incident as resolved?', style: GoogleFonts.poppins(fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text('Resolve', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isResolving = true);
    final token = ref.read(authProvider).token;
    if (token == null) return;

    final result = await IncidentService.resolveIncident(token: token, incidentId: widget.incidentId);

    setState(() => _isResolving = false);

    if (mounted && result.success) {
      ref.read(incidentListProvider.notifier).fetchIncidents();
      ref.read(activeIncidentProvider.notifier).fetchActiveIncident();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Incident resolved.'), backgroundColor: AppColors.success),
      );
      _fetchIncident();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Failed.'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Incident Detail', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.primaryNavy,
        foregroundColor: Colors.white,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppColors.darkGradient)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentSaffron))
          : _incident == null
              ? Center(child: Text('Incident not found.', style: GoogleFonts.poppins(color: AppColors.textSecondary)))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final incident = _incident!;
    final dateStr = incident.createdAt != null ? DateFormat('dd MMM yyyy, hh:mm a').format(incident.createdAt!) : '—';
    final sevColor = _severityColors[(incident.severity - 1).clamp(0, 5)];
    final role = ref.read(authProvider).user?.role;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status + Severity header
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: (incident.isActive ? AppColors.error : AppColors.success).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  incident.status.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: incident.isActive ? AppColors.error : AppColors.success,
                  ),
                ),
              ),
              if (incident.isMockDrill)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                  ),
                  child: Text('MOCK DRILL', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.warning)),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(color: sevColor, borderRadius: BorderRadius.circular(12)),
                child: Text('Severity ${incident.severity}', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Incident type
          Text(incident.incidentSubcategory, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(incident.incidentCategory, style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 20),

          // Info cards
          _buildInfoRow(Icons.train_rounded, 'Train Number', incident.trainNumber),
          _buildInfoRow(Icons.my_location_rounded, 'Location', '${incident.latitude.toStringAsFixed(4)}, ${incident.longitude.toStringAsFixed(4)}'),
          _buildInfoRow(Icons.directions_railway_rounded, 'Affected Component', incident.affectedComponent),
          _buildInfoRow(Icons.schedule_rounded, 'Created', dateStr),
          if (incident.zone != null) _buildInfoRow(Icons.location_city_rounded, 'Zone', incident.zone!),
          if (incident.division != null) _buildInfoRow(Icons.map_rounded, 'Division', incident.division!),
          const SizedBox(height: 20),

          // Operator Responses
          Text('Operator Logs', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          
          if (_isLogsLoading)
            const Center(child: CircularProgressIndicator())
          else ...[
            _buildAcceptanceAccordion(),
            const SizedBox(height: 8),
            _buildAttendanceAccordion(),
            const SizedBox(height: 8),
            _buildResponseAccordion(),
          ],
          
          const SizedBox(height: 24),

          // Action buttons
          if (incident.isActive && role == 'supervisor') ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => IncidentMapScreen(incident: incident)),
                ),
                icon: const Icon(Icons.map_rounded),
                label: Text('View Live Map', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  side: const BorderSide(color: AppColors.primaryNavy),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isResolving ? null : _resolveIncident,
                icon: _isResolving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check_circle_rounded),
                label: Text('Resolve Incident', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],

          if (incident.status == 'resolved' && (role == 'supervisor' || role == 'lead_supervisor' || role == 'admin' || role == 'super_admin' || role == 'master_admin')) ...[
            const SizedBox(height: 24),
            Text('Final Report', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            if (incident.reportUrl != null) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse(incident.reportUrl!);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } else {
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch PDF Report.')));
                        }
                      },
                      icon: const Icon(Icons.download_rounded),
                      label: Text('Download Final PDF Report', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryNavy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.accentSaffron.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: IconButton(
                      onPressed: () {
                        Share.share(
                          'Rapid Response Report for Incident ${incident.id}:\n${incident.reportUrl}',
                          subject: 'Incident Report - ${incident.trainNumber}',
                        );
                      },
                      icon: const Icon(Icons.share_rounded, color: AppColors.accentSaffron),
                      tooltip: 'Share Report Link',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: () async {
                    final proofUrl = '${AppStrings.apiBaseUrl.replaceAll('/api', '')}/proof/${incident.id}/${incident.accessToken}';
                    final uri = Uri.parse(proofUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } else {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open proofs webpage.')));
                    }
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: Text('View Proofs Webpage', style: GoogleFonts.poppins(decoration: TextDecoration.underline)),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isGeneratingReport ? null : _generateReport,
                  icon: _isGeneratingReport ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.picture_as_pdf_rounded),
                  label: Text('Generate PDF Report', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentSaffron,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ],

          const SizedBox(height: 24),
          Text('Submitted Proofs', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          _buildProofsSection(),
        ],
      ),
    );
  }

  bool _isGeneratingReport = false;

  Future<void> _generateReport() async {
    setState(() => _isGeneratingReport = true);
    final token = ref.read(authProvider).token;
    if (token == null) return;

    final result = await IncidentService.generateReport(token: token, incidentId: widget.incidentId);
    
    if (mounted && result.success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report generated successfully!'), backgroundColor: AppColors.success));
      _fetchIncident(); // Refresh to get reportUrl
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message ?? 'Failed to generate report.'), backgroundColor: AppColors.error));
    }
    setState(() => _isGeneratingReport = false);
  }

  Widget _buildProofsSection() {
    if (_isProofsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_proofs.isEmpty) {
      return Text('No proofs have been submitted yet.', style: GoogleFonts.poppins(color: AppColors.textSecondary));
    }

    // Group by Operator
    final Map<String, List<dynamic>> grouped = {};
    for (var doc in _proofs) {
      final opName = doc['operator_name'] ?? 'Unknown Operator';
      if (!grouped.containsKey(opName)) grouped[opName] = [];
      grouped[opName]!.add(doc);
    }

    return Column(
      children: grouped.entries.map((entry) {
        return ExpansionTile(
          title: Text(entry.key, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          subtitle: Text('${entry.value.length} proofs submitted', style: GoogleFonts.poppins(fontSize: 12)),
          children: entry.value.map((data) {
            IconData icon;
            switch (data['proof_type']) {
              case 'IMAGE': icon = Icons.image; break;
              case 'VIDEO': icon = Icons.movie; break;
              case 'AUDIO': icon = Icons.audiotrack; break;
              case 'TEXT': icon = Icons.text_snippet; break;
              default: icon = Icons.insert_drive_file;
            }
            return ListTile(
              onTap: () async {
                if (data['url'] != null) {
                  final uri = Uri.parse(data['url']);
                  if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              leading: CircleAvatar(backgroundColor: AppColors.primaryNavy.withValues(alpha: 0.1), child: Icon(icon, color: AppColors.primaryNavy)),
              title: Text(data['proof_type'], style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
              subtitle: Text(
                '${data['text_content'] ?? ''}\nAt: ${DateTime.parse(data['timestamp']).toLocal().toString().split('.').first}\nLoc: ${data['geostamp']['lat'].toStringAsFixed(4)}, ${data['geostamp']['lng'].toStringAsFixed(4)}',
                style: GoogleFonts.poppins(fontSize: 11),
              ),
              trailing: data['url'] != null ? const Icon(Icons.open_in_new, size: 16) : null,
              isThreeLine: data['text_content'] != null,
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primaryNavy.withValues(alpha: 0.6)),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(label, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            flex: 3,
            child: Text(value, style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildAcceptanceAccordion() {
    return ExpansionTile(
      title: Text('Acceptance Log', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: _avgAcceptanceDelay != null ? Text('Avg Delay: ${_avgAcceptanceDelay!.toStringAsFixed(1)} min', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)) : null,
      collapsedBackgroundColor: AppColors.surface,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
      collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
      children: _acceptanceLog.isEmpty ? [const Padding(padding: EdgeInsets.all(16), child: Text('No logs available.'))] : _acceptanceLog.map((log) {
        final statusColor = log['acceptanceStatus'] == 'ACCEPTED' ? AppColors.success : Colors.amber;
        return ListTile(
          leading: Icon(Icons.check_circle, color: statusColor),
          title: Text(log['operatorName'] ?? 'Unknown', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: Text('Status: ${log['acceptanceStatus']}${log['acceptanceDelayMinutes'] != null ? ' | Delay: ${log['acceptanceDelayMinutes']!.toStringAsFixed(1)}m' : ''}', style: GoogleFonts.poppins(fontSize: 11)),
        );
      }).toList(),
    );
  }

  Widget _buildAttendanceAccordion() {
    return ExpansionTile(
      title: Text('Attendance Log (ART)', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
      collapsedBackgroundColor: AppColors.surface,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
      collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
      children: _attendanceLog.isEmpty ? [const Padding(padding: EdgeInsets.all(16), child: Text('No logs available.'))] : _attendanceLog.map((log) {
        final statusColor = log['attendanceStatus'] == 'PRESENT' ? AppColors.success : Colors.amber;
        return ListTile(
          leading: Icon(Icons.train, color: statusColor),
          title: Text(log['operatorName'] ?? 'Unknown', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: Text('Status: ${log['attendanceStatus']}${log['timeToArtMinutes'] != null ? ' | Time: ${log['timeToArtMinutes']!.toStringAsFixed(1)}m' : ''}', style: GoogleFonts.poppins(fontSize: 11)),
        );
      }).toList(),
    );
  }

  Widget _buildResponseAccordion() {
    return ExpansionTile(
      title: Text('Response Time (Site)', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: _avgResponseTime != null ? Text('Avg Time: ${_avgResponseTime!.toStringAsFixed(1)} min', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)) : null,
      collapsedBackgroundColor: AppColors.surface,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
      collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
      children: _responseLog.isEmpty ? [const Padding(padding: EdgeInsets.all(16), child: Text('No logs available.'))] : _responseLog.map((log) {
        final statusColor = log['responseStatus'] == 'REACHED' ? Colors.blue : Colors.amber;
        return ListTile(
          leading: Icon(Icons.flag, color: statusColor),
          title: Text(log['operatorName'] ?? 'Unknown', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: Text('Status: ${log['responseStatus']}${log['responseDurationMinutes'] != null ? ' | Duration: ${log['responseDurationMinutes']!.toStringAsFixed(1)}m' : ''}', style: GoogleFonts.poppins(fontSize: 11)),
        );
      }).toList(),
    );
  }
}
