import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/art_train_model.dart';
import '../../core/models/user_model.dart';
import '../../core/services/supervisor_service.dart';
import '../auth/auth_provider.dart';

class MyArtTrainState {
  final ArtTrainModel? train;
  final List<UserModel> operators;
  final bool isLoading;
  final String? errorMessage;

  MyArtTrainState({
    this.train,
    this.operators = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  MyArtTrainState copyWith({
    ArtTrainModel? train,
    List<UserModel>? operators,
    bool? isLoading,
    String? errorMessage,
  }) {
    return MyArtTrainState(
      train: train ?? this.train,
      operators: operators ?? this.operators,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class MyArtTrainNotifier extends StateNotifier<MyArtTrainState> {
  final Ref ref;

  MyArtTrainNotifier(this.ref) : super(MyArtTrainState());

  Future<void> fetchMyTrainData() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    final trainResult = await SupervisorService.getMyArtTrain(token: token);
    
    if (!trainResult.success) {
      state = state.copyWith(isLoading: false, errorMessage: trainResult.message);
      return;
    }

    if (trainResult.data == null) {
      state = MyArtTrainState(isLoading: false); // Empty state
      return;
    }

    final operatorsResult = await SupervisorService.getMyArtTrainOperators(token: token);
    
    state = MyArtTrainState(
      train: trainResult.data,
      operators: operatorsResult.success ? (operatorsResult.data ?? []) : [],
      isLoading: false,
    );
  }
}

final myArtTrainProvider = StateNotifierProvider<MyArtTrainNotifier, MyArtTrainState>(
  (ref) => MyArtTrainNotifier(ref),
);
