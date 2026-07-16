import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/registration_service.dart';

/// Registration state
class RegistrationState {
  final bool isLoading;
  final String? errorMessage;
  final bool isSuccess;

  RegistrationState({
    this.isLoading = false,
    this.errorMessage,
    this.isSuccess = false,
  });

  RegistrationState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? isSuccess,
  }) {
    return RegistrationState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

class RegistrationNotifier extends StateNotifier<RegistrationState> {
  RegistrationNotifier() : super(RegistrationState());

  Future<bool> register(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, errorMessage: null, isSuccess: false);

    final result = await RegistrationService.registerOperator(data: data);

    if (result.success) {
      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } else {
      state = state.copyWith(isLoading: false, errorMessage: result.message);
      return false;
    }
  }

  void reset() {
    state = RegistrationState();
  }
}

final registrationProvider =
    StateNotifierProvider.autoDispose<RegistrationNotifier, RegistrationState>(
  (ref) => RegistrationNotifier(),
);
