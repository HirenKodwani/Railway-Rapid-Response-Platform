# Integration Report: Railway Routing Service

## 1. Modified Files
- `r2p_app/pubspec.yaml`
  - Added `dio: ^5.4.0` dependency.
- `r2p_app/lib/core/services/railway_routing_service.dart`
  - Created new service utilizing Dio with a 120s timeout configuration to interact with the new routing endpoints.
- `r2p_app/lib/features/incident/incident_map_screen.dart`
  - Removed straight-line fallback rendering logic.
  - Replaced legacy `IncidentService.getArtEta` with `RailwayRoutingService.getRailRoute`.
  - Parsed the new GeoJSON `LineString` format for accurate map display.
  - Implemented proper fallback error-handling (UI feedback via Snackbar).
- `r2p_app/lib/features/incident/active_incident_console_screen.dart`
  - Removed straight-line fallback rendering logic.
  - Replaced legacy `IncidentService.getArtEta` with `RailwayRoutingService.getRailRoute`.
  - Snapped properties are applied dynamically from the parsed `RailwayRoutingService` route response.
- `r2p_app/lib/features/supervisor/my_art_train_screen.dart`
  - Added snapping of operator/supervisor current and manually selected locations to the railway network using `POST /nearest-track`.

## 2. Architecture Changes
- Abstracted the railway routing capabilities away from the backend API calls (`IncidentService`) to a dedicated third-party microservice integration (`RailwayRoutingService`).
- Introduced direct Flutter-to-Microservice calls over Dio for map-related tasks, preventing standard backend rate limiting and optimizing latency.
- Strict mapping: Replaced approximate straight-line fallback routing with real railway curvature geometry (`LineString` rendering).

## 3. Endpoint Usage
- **Base URL:** `https://anveshr312-railway-routing-service.hf.space`
- **POST `/rail-route`:** Used in `incident_map_screen.dart` and `active_incident_console_screen.dart` to calculate the precise track distance and ETA between the ART Train depot (or current position) and the incident site.
- **POST `/nearest-track`:** Used in `my_art_train_screen.dart` to snap the raw GPS or manually selected coordinates to the closest valid railway line before updating the depot assignment.

## 4. Verification Results
- **GeoJSON Renders Correctly:** Yes. Tested and confirmed that `LineString` correctly resolves and plots precision polylines on `flutter_map`.
- **No Straight-Line Fallback Exists:** Yes. Erased previous `points: [_artTrainLatLng!, incidentLatLng]` logic.
- **Existing Map Features Continue Working:** Yes. Regular operator positions (OSRM driving directions) maintain their original implementation.
- **Flutter Analyze Passes:** Yes. No warnings or errors were introduced into the project.
