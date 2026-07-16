import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/operator_service.dart';
import '../auth/auth_provider.dart';

class OperatorAssignmentState {
  final Map<String, dynamic>? assignment;
  final bool isLoading;
  final String? errorMessage;

  OperatorAssignmentState({
    this.assignment,
    this.isLoading = false,
    this.errorMessage,
  });

  OperatorAssignmentState copyWith({
    Map<String, dynamic>? assignment,
    bool? isLoading,
    String? errorMessage,
  }) {
    return OperatorAssignmentState(
      assignment: assignment ?? this.assignment,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class OperatorAssignmentNotifier extends StateNotifier<OperatorAssignmentState> {
  final Ref ref;

  OperatorAssignmentNotifier(this.ref) : super(OperatorAssignmentState());

  Future<void> fetchMyAssignment() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    final result = await OperatorService.getMyAssignment(token: token);
    
    if (result.success) {
      state = OperatorAssignmentState(assignment: result.data, isLoading: false);
    } else {
      state = state.copyWith(isLoading: false, errorMessage: result.message);
    }
  }
}

final operatorAssignmentProvider = StateNotifierProvider<OperatorAssignmentNotifier, OperatorAssignmentState>(
  (ref) => OperatorAssignmentNotifier(ref),
);
