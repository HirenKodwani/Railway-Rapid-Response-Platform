import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/models/incident_model.dart';
import '../../core/services/incident_service.dart';
import '../auth/auth_provider.dart';

// ──────────────────────────────────────────────
// Incident List Provider (for the log screen)
// ──────────────────────────────────────────────

class IncidentListState {
  final List<IncidentModel> incidents;
  final bool isLoading;
  final String? errorMessage;

  IncidentListState({
    this.incidents = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  IncidentListState copyWith({
    List<IncidentModel>? incidents,
    bool? isLoading,
    String? errorMessage,
  }) {
    return IncidentListState(
      incidents: incidents ?? this.incidents,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class IncidentListNotifier extends StateNotifier<IncidentListState> {
  final Ref ref;

  IncidentListNotifier(this.ref) : super(IncidentListState());

  Future<void> fetchIncidents() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    final result = await IncidentService.getIncidents(token: token);

    if (result.success) {
      state = IncidentListState(incidents: result.data ?? [], isLoading: false);
    } else {
      state = state.copyWith(isLoading: false, errorMessage: result.message);
    }
  }
}

final incidentListProvider =
    StateNotifierProvider<IncidentListNotifier, IncidentListState>(
  (ref) => IncidentListNotifier(ref),
);

// ──────────────────────────────────────────────
// Active Incident Provider (for home screen banners & alerts)
// ──────────────────────────────────────────────

class ActiveIncidentState {
  final IncidentModel? incident;
  final bool isLoading;
  final bool hasShownAlert;

  ActiveIncidentState({
    this.incident,
    this.isLoading = false,
    this.hasShownAlert = false,
  });

  ActiveIncidentState copyWith({
    IncidentModel? incident,
    bool? isLoading,
    bool? hasShownAlert,
    bool clearIncident = false,
  }) {
    return ActiveIncidentState(
      incident: clearIncident ? null : (incident ?? this.incident),
      isLoading: isLoading ?? this.isLoading,
      hasShownAlert: hasShownAlert ?? this.hasShownAlert,
    );
  }
}

class ActiveIncidentNotifier extends StateNotifier<ActiveIncidentState> {
  final Ref ref;
  Timer? _pollTimer;

  ActiveIncidentNotifier(this.ref) : super(ActiveIncidentState());

  Future<void> fetchActiveIncident() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;

    state = state.copyWith(isLoading: true);

    final result = await IncidentService.getActiveIncident(token: token);

    if (result.success) {
      final newIncident = result.data;
      final oldId = state.incident?.id;
      final newId = newIncident?.id;

      // If a new incident appeared that we haven't shown an alert for
      final shouldAlert = newIncident != null && newId != oldId;

      state = ActiveIncidentState(
        incident: newIncident,
        isLoading: false,
        hasShownAlert: shouldAlert ? false : state.hasShownAlert,
      );
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  void markAlertShown() {
    state = state.copyWith(hasShownAlert: true);
  }

  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      fetchActiveIncident();
    });
    // Also fetch immediately
    fetchActiveIncident();
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

final activeIncidentProvider =
    StateNotifierProvider<ActiveIncidentNotifier, ActiveIncidentState>(
  (ref) => ActiveIncidentNotifier(ref),
);

// ──────────────────────────────────────────────
// Operator Locations Provider (for supervisor map)
// ──────────────────────────────────────────────

class OperatorLocationsState {
  final List<OperatorLocationModel> locations;
  final bool isLoading;

  OperatorLocationsState({this.locations = const [], this.isLoading = false});
}

class OperatorLocationsNotifier extends StateNotifier<OperatorLocationsState> {
  final Ref ref;
  Timer? _pollTimer;

  OperatorLocationsNotifier(this.ref) : super(OperatorLocationsState());

  Future<void> fetchLocations(String incidentId) async {
    final token = ref.read(authProvider).token;
    if (token == null) return;

    final result = await IncidentService.getOperatorLocations(
      token: token,
      incidentId: incidentId,
    );

    if (result.success) {
      state = OperatorLocationsState(locations: result.data ?? []);
    }
  }

  void startPolling(String incidentId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      fetchLocations(incidentId);
    });
    fetchLocations(incidentId);
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

final operatorLocationsProvider =
    StateNotifierProvider<OperatorLocationsNotifier, OperatorLocationsState>(
  (ref) => OperatorLocationsNotifier(ref),
);

// ──────────────────────────────────────────────
// Location Streaming Provider (for operator — posts GPS to backend)
// ──────────────────────────────────────────────

class LocationStreamNotifier extends StateNotifier<bool> {
  final Ref ref;
  StreamSubscription<Position>? _positionStream;

  LocationStreamNotifier(this.ref) : super(false);

  void startStreaming(String incidentId) {
    _positionStream?.cancel();
    state = true;

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // minimum 5 meters
      ),
    ).listen((position) async {
      final token = ref.read(authProvider).token;
      if (token == null) return;

      await IncidentService.postLocation(
        token: token,
        incidentId: incidentId,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    });
  }

  void stopStreaming() {
    _positionStream?.cancel();
    _positionStream = null;
    state = false;
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }
}

final locationStreamProvider =
    StateNotifierProvider<LocationStreamNotifier, bool>(
  (ref) => LocationStreamNotifier(ref),
);
