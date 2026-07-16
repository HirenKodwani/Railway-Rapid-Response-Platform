import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/strings.dart';
import '../../core/constants/specialisations.dart';
import '../../core/models/user_model.dart';
import 'lead_supervisor_provider.dart';

class ApprovalQueueScreen extends ConsumerStatefulWidget {
  const ApprovalQueueScreen({super.key});

  @override
  ConsumerState<ApprovalQueueScreen> createState() => _ApprovalQueueScreenState();
}

class _ApprovalQueueScreenState extends ConsumerState<ApprovalQueueScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pendingOperatorsProvider.notifier).fetchPending();
    });
  }

  void _approve(String id) async {
    final success = await ref.read(pendingOperatorsProvider.notifier).approve(id);
    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Operator approved successfully'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _reject(String id) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Reject Operator', style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        content: TextField(
          controller: reasonController,
          style: GoogleFonts.poppins(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: AppStrings.rejectReason,
            hintStyle: GoogleFonts.poppins(color: AppColors.textSubtle),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3))),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accentSaffron)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppStrings.cancel, style: GoogleFonts.poppins(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ref.read(pendingOperatorsProvider.notifier).reject(id, reasonController.text);
              if (mounted && success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Operator rejected'),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
            },
            child: Text(AppStrings.reject, style: GoogleFonts.poppins(color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pendingOperatorsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: state.isLoading && state.operators.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentSaffron))
          : state.operators.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: AppColors.accentSaffron,
                  onRefresh: () => ref.read(pendingOperatorsProvider.notifier).fetchPending(),
                  child: _buildGroupedList(state.operators),
                ),
    );
  }

  Widget _buildGroupedList(List<UserModel> operators) {
    // Group operators by specialisation
    final grouped = <String?, List<UserModel>>{};
    for (final op in operators) {
      final spec = op.specialisation;
      if (!grouped.containsKey(spec)) {
        grouped[spec] = [];
      }
      grouped[spec]!.add(op);
    }

    // Sort specialisation keys: non-null first according to Specialisations.ids order, then null at bottom
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        if (a == null && b == null) return 0;
        if (a == null) return 1;
        if (b == null) return -1;
        final indexA = Specialisations.ids.indexOf(a);
        final indexB = Specialisations.ids.indexOf(b);
        return indexA.compareTo(indexB);
      });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final key = sortedKeys[index];
        final ops = grouped[key]!;
        if (ops.isEmpty) return const SizedBox.shrink();

        final label = Specialisations.getLabel(key);
        final color = Specialisations.getColor(key);

        return Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: ExpansionTile(
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      label,
                      style: GoogleFonts.poppins(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${ops.length}',
                    style: GoogleFonts.poppins(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              childrenPadding: const EdgeInsets.all(12),
              children: ops.map((op) => _buildOperatorCard(op)).toList(),
            ),
          ),
        );
      },
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
              color: AppColors.success.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_outline, size: 40, color: AppColors.success.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 20),
          Text(AppStrings.noPendingOperators, style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('All operator requests have been processed', style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildOperatorCard(UserModel operator) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      child: ExpansionTile(
        title: Text(operator.name, style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16)),
        subtitle: Text(operator.employeeId ?? '', style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12)),
        childrenPadding: const EdgeInsets.all(16).copyWith(top: 0),
        iconColor: AppColors.accentSaffron,
        collapsedIconColor: AppColors.textSubtle,
        children: [
          Row(
            children: [
              Icon(Icons.email_outlined, size: 16, color: AppColors.textSubtle),
              const SizedBox(width: 8),
              Expanded(child: Text(operator.email, style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 14))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.phone_outlined, size: 16, color: AppColors.textSubtle),
              const SizedBox(width: 8),
              Text(operator.phone, style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 14)),
            ],
          ),
          if (operator.zone != null && operator.zone!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.map_outlined, size: 16, color: AppColors.textSubtle),
                const SizedBox(width: 8),
                Expanded(child: Text('Zone: ${operator.zone}', style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 14))),
              ],
            ),
          ],
          if (operator.division != null && operator.division!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.business_outlined, size: 16, color: AppColors.textSubtle),
                const SizedBox(width: 8),
                Expanded(child: Text('Division: ${operator.division}', style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 14))),
              ],
            ),
          ],
          if (operator.city != null && operator.city!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_city_outlined, size: 16, color: AppColors.textSubtle),
                const SizedBox(width: 8),
                Expanded(child: Text('City: ${operator.city}', style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 14))),
              ],
            ),
          ],
          if (operator.address != null && operator.address!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSubtle),
                const SizedBox(width: 8),
                Expanded(child: Text(operator.address!, style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 14))),
              ],
            ),
          ],
          if (operator.lat != null && operator.lng != null) ...[
            const SizedBox(height: 16),
            Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              clipBehavior: Clip.antiAlias,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(operator.lat!, operator.lng!),
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
                        point: LatLng(operator.lat!, operator.lng!),
                        width: 30,
                        height: 30,
                        child: const Icon(Icons.location_on, color: AppColors.error, size: 30),
                      )
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _reject(operator.id),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(AppStrings.reject, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _approve(operator.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: AppColors.textLight,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(AppStrings.approve, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
