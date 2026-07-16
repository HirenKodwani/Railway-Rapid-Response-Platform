import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/strings.dart';
import 'lead_supervisor_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationsProvider.notifier).fetchNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppStrings.notifications, style: GoogleFonts.poppins(color: AppColors.textLight, fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.primaryNavy,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textLight),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        ),
      ),
      body: state.isLoading && state.notifications.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentSaffron))
          : state.notifications.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: AppColors.accentSaffron,
                  onRefresh: () => ref.read(notificationsProvider.notifier).fetchNotifications(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.notifications.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final notif = state.notifications[index];
                      return InkWell(
                        onTap: () {
                          if (!notif.isRead) {
                            ref.read(notificationsProvider.notifier).markRead(notif.id);
                          }
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: notif.isRead ? Colors.grey.withValues(alpha: 0.15) : AppColors.accentSaffron.withValues(alpha: 0.4),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.accentSaffron.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  notif.type == 'operator_registration' ? Icons.person_add_outlined : Icons.notifications_outlined,
                                  color: AppColors.accentSaffron,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      notif.message,
                                      style: GoogleFonts.poppins(
                                        color: AppColors.textPrimary,
                                        fontSize: 14,
                                        fontWeight: notif.isRead ? FontWeight.normal : FontWeight.w600,
                                      ),
                                    ),
                                    if (notif.createdAt != null) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        DateFormat('dd MMM yyyy, hh:mm a').format(notif.createdAt!.toLocal()),
                                        style: GoogleFonts.poppins(
                                          color: AppColors.textSubtle,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ]
                                  ],
                                ),
                              ),
                              if (!notif.isRead)
                                Container(
                                  margin: const EdgeInsets.only(top: 6),
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.accentSaffron,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
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
            child: Icon(Icons.notifications_off_outlined, size: 40, color: AppColors.primaryNavy.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 20),
          Text(AppStrings.noNotifications, style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('You\'ll see notifications here when operators register', style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}
