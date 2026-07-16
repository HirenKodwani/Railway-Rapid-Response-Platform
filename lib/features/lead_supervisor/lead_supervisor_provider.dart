import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/user_model.dart';
import '../../core/models/notification_model.dart';
import '../../core/models/art_train_model.dart';
import '../../core/services/lead_supervisor_service.dart';
import '../../core/services/art_train_service.dart';
import '../auth/auth_provider.dart';

// --- Pending Operators ---
class PendingOperatorsState {
  final List<UserModel> operators;
  final bool isLoading;
  final String? errorMessage;

  PendingOperatorsState({
    this.operators = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  PendingOperatorsState copyWith({
    List<UserModel>? operators,
    bool? isLoading,
    String? errorMessage,
  }) {
    return PendingOperatorsState(
      operators: operators ?? this.operators,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class PendingOperatorsNotifier extends StateNotifier<PendingOperatorsState> {
  final Ref ref;
  Timer? _pollingTimer;

  PendingOperatorsNotifier(this.ref) : super(PendingOperatorsState()) {
    ref.listen(authProvider, (previous, current) {
      if (current.user?.role == 'lead_supervisor' && current.isAuthenticated) {
        startPolling();
      } else {
        stopPolling();
      }
    });

    final currentAuth = ref.read(authProvider);
    if (currentAuth.user?.role == 'lead_supervisor' && currentAuth.isAuthenticated) {
      startPolling();
    }
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }

  void startPolling() {
    fetchPending();
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      fetchPending();
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
  }

  Future<void> fetchPending() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);
    final result = await LeadSupervisorService.getPendingOperators(token: token);

    if (result.success && result.data != null) {
      state = PendingOperatorsState(operators: result.data!, isLoading: false);
    } else {
      state = state.copyWith(isLoading: false, errorMessage: result.message);
    }
  }

  Future<bool> approve(String id) async {
    final token = ref.read(authProvider).token;
    if (token == null) return false;

    final result = await LeadSupervisorService.approveOperator(token: token, operatorId: id);
    if (result.success) {
      state = state.copyWith(
        operators: state.operators.where((o) => o.id != id).toList(),
      );
      return true;
    }
    return false;
  }

  Future<bool> reject(String id, String? reason) async {
    final token = ref.read(authProvider).token;
    if (token == null) return false;

    final result = await LeadSupervisorService.rejectOperator(token: token, operatorId: id, reason: reason);
    if (result.success) {
      state = state.copyWith(
        operators: state.operators.where((o) => o.id != id).toList(),
      );
      return true;
    }
    return false;
  }
}

final pendingOperatorsProvider = StateNotifierProvider<PendingOperatorsNotifier, PendingOperatorsState>(
  (ref) => PendingOperatorsNotifier(ref),
);

// --- Notifications ---
class NotificationsState {
  final List<NotificationModel> notifications;
  final int unreadCount;
  final bool isLoading;

  NotificationsState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.isLoading = false,
  });

  NotificationsState copyWith({
    List<NotificationModel>? notifications,
    int? unreadCount,
    bool? isLoading,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  final Ref ref;
  Timer? _pollingTimer;

  NotificationsNotifier(this.ref) : super(NotificationsState()) {
    // Check if user is lead supervisor, then start polling
    ref.listen(authProvider, (previous, current) {
      if (current.user?.role == 'lead_supervisor' && current.isAuthenticated) {
        startPolling();
      } else {
        stopPolling();
      }
    });

    final currentAuth = ref.read(authProvider);
    if (currentAuth.user?.role == 'lead_supervisor' && currentAuth.isAuthenticated) {
      startPolling();
    }
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }

  void startPolling() {
    fetchUnreadCount();
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      fetchUnreadCount();
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
  }

  Future<void> fetchUnreadCount() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;

    final result = await LeadSupervisorService.getUnreadCount(token: token);
    if (result.success && result.data != null) {
      state = state.copyWith(unreadCount: result.data!);
    }
  }

  Future<void> fetchNotifications() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;

    state = state.copyWith(isLoading: true);
    final result = await LeadSupervisorService.getNotifications(token: token);

    if (result.success && result.data != null) {
      state = state.copyWith(notifications: result.data!, isLoading: false);
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> markRead(String id) async {
    final token = ref.read(authProvider).token;
    if (token == null) return;

    final result = await LeadSupervisorService.markNotificationRead(token: token, notificationId: id);
    if (result.success) {
      final updated = state.notifications.map((n) {
        if (n.id == id) return NotificationModel(
          id: n.id, recipientId: n.recipientId, type: n.type, message: n.message, isRead: true, createdAt: n.createdAt, referenceId: n.referenceId
        );
        return n;
      }).toList();
      state = state.copyWith(
        notifications: updated,
        unreadCount: state.unreadCount > 0 ? state.unreadCount - 1 : 0,
      );
    }
  }
}

final notificationsProvider = StateNotifierProvider<NotificationsNotifier, NotificationsState>(
  (ref) => NotificationsNotifier(ref),
);

// --- ART Trains (Lead Supervisor) ---
class ArtTrainsState {
  final List<ArtTrainModel> trains;
  final bool isLoading;
  final String? errorMessage;

  ArtTrainsState({
    this.trains = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  ArtTrainsState copyWith({
    List<ArtTrainModel>? trains,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ArtTrainsState(
      trains: trains ?? this.trains,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class ArtTrainsNotifier extends StateNotifier<ArtTrainsState> {
  final Ref ref;

  ArtTrainsNotifier(this.ref) : super(ArtTrainsState());

  Future<void> fetchTrains() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);
    final result = await ArtTrainService.getTrains(token: token);

    if (result.success && result.data != null) {
      state = ArtTrainsState(trains: result.data!, isLoading: false);
    } else {
      state = state.copyWith(isLoading: false, errorMessage: result.message);
    }
  }

  Future<bool> createTrain(Map<String, dynamic> data) async {
    final token = ref.read(authProvider).token;
    if (token == null) return false;

    final result = await ArtTrainService.createTrain(token: token, data: data);
    if (result.success && result.data != null) {
      state = state.copyWith(trains: [result.data!, ...state.trains]);
      return true;
    }
    return false;
  }

  Future<bool> updateTrain(String id, Map<String, dynamic> data) async {
    final token = ref.read(authProvider).token;
    if (token == null) return false;

    final result = await ArtTrainService.updateTrain(token: token, id: id, data: data);
    if (result.success && result.data != null) {
      state = state.copyWith(
        trains: state.trains.map((t) => t.id == id ? result.data! : t).toList(),
      );
      return true;
    }
    return false;
  }

  Future<bool> deleteTrain(String id) async {
    final token = ref.read(authProvider).token;
    if (token == null) return false;

    final result = await ArtTrainService.deleteTrain(token: token, id: id);
    if (result.success) {
      state = state.copyWith(
        trains: state.trains.where((t) => t.id != id).toList(),
      );
      return true;
    }
    return false;
  }

  Future<bool> swapSupervisor(String trainId, String supervisorId) async {
    final token = ref.read(authProvider).token;
    if (token == null) return false;

    final result = await ArtTrainService.swapSupervisor(token: token, trainId: trainId, supervisorId: supervisorId);
    if (result.success) {
      // Re-fetch to get accurate state across all trains (since old train lost supervisor)
      await fetchTrains();
      return true;
    }
    return false;
  }
}

final artTrainsProvider = StateNotifierProvider<ArtTrainsNotifier, ArtTrainsState>(
  (ref) => ArtTrainsNotifier(ref),
);
