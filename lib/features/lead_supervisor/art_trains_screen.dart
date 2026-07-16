import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/strings.dart';
import '../../core/constants/specialisations.dart';
import '../../core/models/art_train_model.dart';
import '../../core/models/user_model.dart';
import '../../core/services/art_train_service.dart';
import '../../core/utils/launcher_utils.dart';
import '../auth/auth_provider.dart';
import 'lead_supervisor_provider.dart';
import 'create_edit_art_train_screen.dart';
import 'operator_selection_panel.dart';

class ArtTrainsScreen extends ConsumerStatefulWidget {
  const ArtTrainsScreen({super.key});

  @override
  ConsumerState<ArtTrainsScreen> createState() => _ArtTrainsScreenState();
}

class _ArtTrainsScreenState extends ConsumerState<ArtTrainsScreen> {
  // Map of trainId to list of loaded operators for that train
  final Map<String, List<UserModel>> _trainOperators = {};
  final Map<String, bool> _loadingOperators = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(artTrainsProvider.notifier).fetchTrains();
    });
  }

  Future<void> _fetchOperatorsForTrain(String trainId) async {
    setState(() => _loadingOperators[trainId] = true);
    final token = ref.read(authProvider).token;
    if (token == null) return;

    final result = await ArtTrainService.getTrainOperators(token: token, trainId: trainId);
    
    if (mounted) {
      setState(() {
        _loadingOperators[trainId] = false;
        if (result.success) {
          _trainOperators[trainId] = result.data ?? [];
        }
      });
    }
  }

  void _showAddOperatorsPanel(String trainId) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (_, controller) => OperatorSelectionPanel(trainId: trainId),
      ),
    );

    if (result == true && mounted) {
      ref.read(artTrainsProvider.notifier).fetchTrains();
      _fetchOperatorsForTrain(trainId);
    }
  }

  void _removeOperator(String trainId, String operatorId) async {
    final token = ref.read(authProvider).token;
    if (token == null) return;

    final result = await ArtTrainService.removeOperator(token: token, trainId: trainId, operatorId: operatorId);
    
    if (mounted && result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Operator removed'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      ref.read(artTrainsProvider.notifier).fetchTrains();
      _fetchOperatorsForTrain(trainId);
    }
  }

  void _confirmDelete(String trainId, String trainName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete ART Train', style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to delete "$trainName"? All assigned operators will be removed from this train.', style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(AppStrings.cancel, style: GoogleFonts.poppins(color: AppColors.textSecondary, fontWeight: FontWeight.w500))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(artTrainsProvider.notifier).deleteTrain(trainId);
            },
            child: Text(AppStrings.delete, style: GoogleFonts.poppins(color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(artTrainsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: state.isLoading && state.trains.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentSaffron))
          : state.trains.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: AppColors.accentSaffron,
                  onRefresh: () => ref.read(artTrainsProvider.notifier).fetchTrains(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16).copyWith(bottom: 80),
                    itemCount: state.trains.length,
                    itemBuilder: (context, index) {
                      final train = state.trains[index];
                      return _buildTrainCard(train);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateEditArtTrainScreen())),
        backgroundColor: AppColors.accentSaffron,
        icon: const Icon(Icons.add, color: AppColors.textLight),
        label: Text(AppStrings.createArtTrain, style: GoogleFonts.poppins(color: AppColors.textLight, fontWeight: FontWeight.w600)),
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
            child: Icon(Icons.train_outlined, size: 40, color: AppColors.primaryNavy.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 20),
          Text(AppStrings.noArtTrains, style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Tap + to create your first ART Train', style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildTrainCard(ArtTrainModel train) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      child: ExpansionTile(
        title: Text(train.name, style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16)),
        subtitle: Text('${train.division} • ${train.operatorCount} Operators', style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12)),
        childrenPadding: const EdgeInsets.all(16).copyWith(top: 0),
        iconColor: AppColors.accentSaffron,
        collapsedIconColor: AppColors.textSubtle,
        onExpansionChanged: (expanded) {
          if (expanded && !_trainOperators.containsKey(train.id)) {
            _fetchOperatorsForTrain(train.id);
          }
        },
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(Icons.edit_outlined, color: AppColors.primaryNavy, size: 20),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateEditArtTrainScreen(train: train))),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                onPressed: () => _confirmDelete(train.id, train.name),
              ),
            ],
          ),
          _buildDetailRow(Icons.person_outline, 'Supervisor', train.supervisorName ?? 'None assigned'),
          if (train.supervisorPhone != null)
            _buildDetailRow(Icons.phone_outlined, 'Sup. Phone', train.supervisorPhone!, onTap: () {
              if (train.supervisorPhone!.isNotEmpty) {
                LauncherUtils.makePhoneCall(train.supervisorPhone!);
              }
            }),
          if (train.gpsDeviceId != null && train.gpsDeviceId!.isNotEmpty) _buildDetailRow(Icons.gps_fixed, 'GPS Device', train.gpsDeviceId!),
          
          const SizedBox(height: 16),
          Divider(color: Colors.grey.withValues(alpha: 0.15)),
          const SizedBox(height: 8),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppStrings.assignedOperators, style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
              TextButton.icon(
                onPressed: () => _showAddOperatorsPanel(train.id),
                icon: const Icon(Icons.add, size: 16, color: AppColors.accentSaffron),
                label: Text(AppStrings.addOperators, style: GoogleFonts.poppins(color: AppColors.accentSaffron, fontSize: 12)),
              )
            ],
          ),
          const SizedBox(height: 8),
          
          if (_loadingOperators[train.id] == true)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: AppColors.accentSaffron)))
          else if (_trainOperators[train.id]?.isEmpty ?? true)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(AppStrings.noOperatorsAssigned, style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12, fontStyle: FontStyle.italic)),
            )
          else
            Builder(
              builder: (context) {
                final operators = _trainOperators[train.id]!;
                
                // Group by specialisation
                final grouped = <String?, List<UserModel>>{};
                for (final op in operators) {
                  final spec = op.specialisation;
                  if (!grouped.containsKey(spec)) grouped[spec] = [];
                  grouped[spec]!.add(op);
                }
                
                // Sort keys: non-null first according to Specialisations.ids order, then null
                final sortedKeys = grouped.keys.toList()..sort((a, b) {
                  if (a == null && b == null) return 0;
                  if (a == null) return 1;
                  if (b == null) return -1;
                  return Specialisations.ids.indexOf(a).compareTo(Specialisations.ids.indexOf(b));
                });

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Summary Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: sortedKeys.map((key) {
                          final ops = grouped[key]!;
                          final label = Specialisations.getLabel(key);
                          final color = Specialisations.getColor(key);
                          
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Chip(
                              label: Text('$label  ${ops.length}', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                              backgroundColor: color,
                              side: BorderSide.none,
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    
                    // Grouped List
                    ...sortedKeys.map((key) {
                      final ops = grouped[key]!;
                      final label = Specialisations.getLabel(key);
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 4),
                            child: Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          ),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: ops.length,
                            itemBuilder: (context, index) {
                              final op = ops[index];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(op.name, style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 14)),
                                subtitle: Text(
                                  '${op.phone}${op.city != null && op.city!.isNotEmpty ? ' • ${op.city}' : ''}', 
                                  style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: AppColors.error, size: 20),
                                  onPressed: () => _removeOperator(train.id, op.id),
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    }),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {VoidCallback? onTap}) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textSubtle),
        const SizedBox(width: 8),
        Text('$label: ', style: GoogleFonts.poppins(color: AppColors.textSubtle, fontSize: 13)),
        Expanded(child: Text(value, style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 13))),
        if (onTap != null)
          const Icon(Icons.call_made_rounded, size: 14, color: AppColors.success),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: row,
              ),
            )
          : row,
    );
  }
}
