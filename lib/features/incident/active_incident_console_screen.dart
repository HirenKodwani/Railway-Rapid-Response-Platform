import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/strings.dart';
import '../../core/models/incident_model.dart';
import '../../core/services/incident_service.dart';
import '../../core/services/offline_queue_service.dart';
import '../../core/services/railway_routing_service.dart';
import '../auth/auth_provider.dart';
import 'incident_provider.dart';
import 'proof_upload_screen.dart';

/// Operator's active incident workspace — shown after accepting an incident.
/// Displays incident info, a live map with ART train + incident + own position,
/// and automatically navigates back when the incident is resolved.
class ActiveIncidentConsoleScreen extends ConsumerStatefulWidget {
  final IncidentModel incident;
  final bool locationConsent;
  const ActiveIncidentConsoleScreen({super.key, required this.incident, this.locationConsent = true});

  @override
  ConsumerState<ActiveIncidentConsoleScreen> createState() =>
      _ActiveIncidentConsoleScreenState();
}

class _ActiveIncidentConsoleScreenState
    extends ConsumerState<ActiveIncidentConsoleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  LatLng? _myPosition;
  StreamSubscription<Position>? _positionStream;
  Timer? _incidentPollTimer;
  late IncidentModel _currentIncident;
  
  List<LatLng> _routePoints = [];
  double? _routeDistanceKm;
  int? _routeEtaMin;
  LatLng? _lastRouteStart;
  
  String _lastAttendanceStatus = 'PENDING';
  String _lastResponseStatus = 'PENDING';

  LatLng? _artTrainLatLng;
  double? _artTrainDistKm;
  int? _artTrainEtaMin;
  List<LatLng> _artTrainRoute = [];

  final List<Color> _severityColors = [
    const Color(0xFF4CAF50),
    const Color(0xFF8BC34A),
    const Color(0xFFFFC107),
    const Color(0xFFFF9800),
    const Color(0xFFFF5722),
    const Color(0xFFD50000),
  ];

  @override
  void initState() {
    super.initState();
    _currentIncident = widget.incident;
    _tabController = TabController(length: 2, vsync: this);
    _startLocationStream();
    _startIncidentPolling();
    _fetchArtTrainData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _positionStream?.cancel();
    _incidentPollTimer?.cancel();
    super.dispose();
  }

  /// Starts streaming operator's live GPS and posting to backend every update
  Future<void> _startLocationStream() async {
    if (!widget.locationConsent) return;

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) return;

    final token = ref.read(authProvider).token;
    if (token == null) return;

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((position) async {
      if (!mounted) return;
      setState(() {
        _myPosition = LatLng(position.latitude, position.longitude);
      });
      // Fetch proper navigated route to ART Train
      if (_artTrainLatLng != null) {
        _fetchRoute(_myPosition!, _artTrainLatLng!);
      } else {
        // Fallback to incident if ART train location unknown
        _fetchRoute(_myPosition!, LatLng(_currentIncident.latitude, _currentIncident.longitude));
      }
      
      bool geofenceCheckRequired = false;
      
      // 200m from ART train
      if (_artTrainLatLng != null && _haversineDistance(_myPosition!, _artTrainLatLng!) <= 0.2) {
        geofenceCheckRequired = true;
      }
      // 300m from accident spot
      if (_haversineDistance(_myPosition!, LatLng(_currentIncident.latitude, _currentIncident.longitude)) <= 0.3) {
        geofenceCheckRequired = true;
      }

      bool isOffline = false;
      try {
        final connectivityResult = await Connectivity().checkConnectivity();
        if (!connectivityResult.contains(ConnectivityResult.mobile) && !connectivityResult.contains(ConnectivityResult.wifi)) {
          isOffline = true;
        } else {
          try {
            final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 2));
            if (result.isEmpty || result[0].rawAddress.isEmpty) {
              isOffline = true;
            }
          } on SocketException catch (_) {
            isOffline = true;
          } on TimeoutException catch (_) {
            isOffline = true;
          }
        }
      } catch (_) {}

      if (isOffline) {
        // Queue locally
        await OfflineQueueService().insertAttendance({
          'incident_id': _currentIncident.id,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
          'geofenceCheckRequired': geofenceCheckRequired ? 1 : 0,
          'status': 'pending',
        });
        if (mounted && _lastAttendanceStatus != 'OFFLINE') {
           _lastAttendanceStatus = 'OFFLINE';
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Offline mode: Attendance queued locally.'), backgroundColor: AppColors.warning)
           );
        }
        return;
      }

      // Post location to backend
      final res = await IncidentService.postLocation(
        token: token,
        incidentId: _currentIncident.id,
        latitude: position.latitude,
        longitude: position.longitude,
        geofenceCheckRequired: geofenceCheckRequired,
        clientTimestamp: DateTime.now().toUtc().toIso8601String(),
      );

      if (res.success && res.data != null) {
        final attStatus = res.data!['attendanceStatus'] as String?;
        final resStatus = res.data!['responseStatus'] as String?;

        if (attStatus == 'PRESENT' && _lastAttendanceStatus != 'PRESENT') {
          _lastAttendanceStatus = 'PRESENT';
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Attendance marked ✓ — You have been present at ART Train for 1 minute.'),
                backgroundColor: Colors.green,
              )
            );
          }
        }

        if (resStatus == 'REACHED' && _lastResponseStatus != 'REACHED') {
          _lastResponseStatus = 'REACHED';
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Arrival at incident site logged ✓'),
                backgroundColor: Colors.green,
              )
            );
          }
        }
      } else if (!res.success && res.message == AppStrings.networkError) {
        // Fallback to queue if post failed due to network
        await OfflineQueueService().insertAttendance({
          'incident_id': _currentIncident.id,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
          'geofenceCheckRequired': geofenceCheckRequired ? 1 : 0,
          'status': 'pending',
        });
      }
    });
  }

  Future<void> _fetchRoute(LatLng start, LatLng end) async {
    // Only fetch if we haven't fetched or moved more than 200 meters to avoid spamming API
    if (_lastRouteStart != null) {
      if (_haversineDistance(_lastRouteStart!, start) < 0.2) return;
    }
    _lastRouteStart = start;

    try {
      final url = Uri.parse(
          'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List;
        if (routes.isNotEmpty) {
          final route = routes.first;
          final geometry = route['geometry'];
          final coords = geometry['coordinates'] as List;
          final points = coords.map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();
          final distance = (route['distance'] as num).toDouble() / 1000.0; // km
          final duration = (route['duration'] as num).toDouble() / 60.0; // minutes
          
          if (mounted) {
            setState(() {
              _routePoints = points;
              _routeDistanceKm = distance;
              _routeEtaMin = duration.ceil();
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch route: $e');
    }
  }

  Future<void> _fetchArtTrainData() async {
    if (_currentIncident.artTrainId == null) return;
    
    final token = ref.read(authProvider).token;
    if (token == null) return;

    // Fetch live location
    final locResult = await IncidentService.getArtTrainLocation(token: token, trainId: _currentIncident.artTrainId!);
    if (locResult.success && locResult.data != null) {
      final lat = locResult.data!['latitude'] as double;
      final lng = locResult.data!['longitude'] as double;
      
      if (mounted) {
        setState(() {
          _artTrainLatLng = LatLng(lat, lng);
        });
        
        // Update operator route to ART train if position is known
        if (_myPosition != null) {
          _fetchRoute(_myPosition!, _artTrainLatLng!);
        }
        
        // Fetch route using RailwayRoutingService
        final routingService = RailwayRoutingService();
        final routeResult = await routingService.getRailRoute(
          startLat: lat,
          startLng: lng,
          endLat: _currentIncident.latitude,
          endLng: _currentIncident.longitude,
        );

        if (routeResult != null && mounted) {
          final geojson = routeResult['geojson'];
          List<LatLng> routePts = [];

          if (geojson != null && geojson['type'] == 'Feature') {
            final geometry = geojson['geometry'];
            if (geometry != null && geometry['type'] == 'LineString') {
              final coords = geometry['coordinates'] as List;
              for (var coord in coords) {
                routePts.add(LatLng((coord[1] as num).toDouble(), (coord[0] as num).toDouble()));
              }
            }
          }

          setState(() {
            _artTrainDistKm = (routeResult['distance_meters'] as num).toDouble() / 1000.0;
            _artTrainEtaMin = (routeResult['eta_minutes'] as num).toInt();
            _artTrainRoute = routePts;

            final snappedStart = routeResult['snapped_start'] as List?;
            if (snappedStart != null && snappedStart.length >= 2) {
              _artTrainLatLng = LatLng((snappedStart[1] as num).toDouble(), (snappedStart[0] as num).toDouble());
            }
          });
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to calculate railway route.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  /// Polls incident status every 30s; navigates home if resolved/cancelled
  void _startIncidentPolling() {
    _incidentPollTimer =
        Timer.periodic(const Duration(seconds: 30), (_) async {
      final token = ref.read(authProvider).token;
      if (token == null) return;
      final result = await IncidentService.getIncident(
        token: token,
        incidentId: _currentIncident.id,
      );
      if (result.success && result.data != null) {
        final updated = result.data!;
        setState(() => _currentIncident = updated);
        if (updated.status == 'resolved' || updated.status == 'cancelled') {
          _showResolvedDialog(updated.status);
        } else {
          // Re-fetch ART train data just in case it moves
          _fetchArtTrainData();
        }
      }
    });
  }

  void _showResolvedDialog(String status) {
    _incidentPollTimer?.cancel();
    _positionStream?.cancel();
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              status == 'resolved'
                  ? Icons.check_circle_rounded
                  : Icons.cancel_rounded,
              color: status == 'resolved' ? AppColors.success : AppColors.error,
            ),
            const SizedBox(width: 10),
            Text(
              status == 'resolved' ? 'Incident Resolved' : 'Incident Cancelled',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          status == 'resolved'
              ? 'This incident has been resolved by the supervisor. Thank you for your response!'
              : 'This incident has been cancelled. You may return to standby.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (mounted) Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryNavy,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Return Home',
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  /// Haversine formula — straight-line distance between two lat/lng points (km)
  double _haversineDistance(LatLng a, LatLng b) {
    const earthR = 6371.0;
    final dLat = _toRad(b.latitude - a.latitude);
    final dLng = _toRad(b.longitude - a.longitude);
    final x = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(a.latitude)) *
            cos(_toRad(b.latitude)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return earthR * 2 * atan2(sqrt(x), sqrt(1 - x));
  }

  double _toRad(double deg) => deg * pi / 180;

  @override
  Widget build(BuildContext context) {
    final incident = _currentIncident;
    final sevColor = _severityColors[(incident.severity - 1).clamp(0, 5)];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Leave Incident?',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            content: Text(
                'Are you sure you want to leave? Location streaming will stop.',
                style: GoogleFonts.poppins(fontSize: 13)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('Stay',
                    style: GoogleFonts.poppins(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Leave',
                    style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        );
        if (leave == true && mounted) {
          _positionStream?.cancel();
          _incidentPollTimer?.cancel();
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            incident.isMockDrill ? '🔵 Mock Drill Console' : '🚨 Active Incident',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          backgroundColor: incident.isMockDrill
              ? const Color(0xFF0D1B4B)
              : const Color(0xFFB71C1C),
          foregroundColor: Colors.white,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(icon: Icon(Icons.info_outline_rounded, size: 18), text: 'Info'),
              Tab(icon: Icon(Icons.map_rounded, size: 18), text: 'Live Map'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildInfoTab(incident, sevColor),
            _buildMapTab(incident),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTab(IncidentModel incident, Color sevColor) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner for location denial
          if (!widget.locationConsent) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_off_rounded, color: AppColors.warning, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Location sharing is off. Your supervisor cannot see your position.',
                      style: GoogleFonts.poppins(fontSize: 12, color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          
          // Status banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: incident.isActive
                  ? AppColors.error.withValues(alpha: 0.08)
                  : AppColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: incident.isActive
                    ? AppColors.error.withValues(alpha: 0.3)
                    : AppColors.success.withValues(alpha: 0.3),
              ),
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(
                  incident.isActive
                      ? Icons.emergency_rounded
                      : Icons.check_circle_rounded,
                  color: incident.isActive ? AppColors.error : AppColors.success,
                  size: 22,
                ),
                Text(
                  incident.isActive ? 'ACTIVE — Respond Now' : 'RESOLVED',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: incident.isActive ? AppColors.error : AppColors.success,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: sevColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Sev ${incident.severity}',
                      style: GoogleFonts.poppins(
                          fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Upload Proof Action
          if (incident.isActive) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ProofUploadScreen(incident: incident)),
                ),
                icon: const Icon(Icons.upload_file_rounded),
                label: Text('Upload Proof of Evidence', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Incident details card
          _buildCard(children: [
            _buildInfoRow(Icons.category_rounded, 'Category', incident.incidentCategory),
            _buildInfoRow(Icons.list_alt_rounded, 'Sub-type', incident.incidentSubcategory),
            _buildInfoRow(Icons.train_rounded, 'Train No.', incident.trainNumber),
            _buildInfoRow(Icons.directions_railway_rounded, 'Affected', incident.affectedComponent),
            _buildInfoRow(Icons.location_on_rounded, 'Location',
                '${incident.latitude.toStringAsFixed(5)}, ${incident.longitude.toStringAsFixed(5)}'),
          ]),
          const SizedBox(height: 16),

          // Severity bar
          Text('Severity Level',
              style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          _buildSeverityBar(incident.severity),
          const SizedBox(height: 20),

          // Location status
          _buildCard(children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: (_myPosition != null ? AppColors.success : AppColors.warning)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _myPosition != null ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded,
                    color: _myPosition != null ? AppColors.success : AppColors.warning,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('GPS Location',
                          style: GoogleFonts.poppins(
                              fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      Text(
                        _myPosition != null
                            ? 'Streaming live — ${_myPosition!.latitude.toStringAsFixed(4)}, ${_myPosition!.longitude.toStringAsFixed(4)}'
                            : 'Acquiring GPS signal...',
                        style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildMapTab(IncidentModel incident) {
    final incidentLatLng = LatLng(incident.latitude, incident.longitude);

    // ART train location from fetched data, fallback to incident model
    LatLng? artTrainLatLng = _artTrainLatLng ?? 
        (incident.artTrainLat != null && incident.artTrainLng != null 
            ? LatLng(incident.artTrainLat!, incident.artTrainLng!) 
            : null);
    String artTrainName = incident.artTrainName ?? 'ART Train';

    final markers = <Marker>[
      // Incident marker
      Marker(
        point: incidentLatLng,
        width: 120,
        height: 70,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${incident.incidentSubcategory.split(' ').first}\n${incident.trainNumber}',
                style: GoogleFonts.poppins(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ),
            Icon(Icons.warning_rounded, color: Colors.red.shade700, size: 28),
          ],
        ),
      ),
    ];

    // My position marker
    if (_myPosition != null) {
      markers.add(Marker(
        point: _myPosition!,
        width: 80,
        height: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.info,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('You', style: GoogleFonts.poppins(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600)),
            ),
            const Icon(Icons.my_location_rounded, color: AppColors.info, size: 28),
          ],
        ),
      ));
    }

    // ART train marker if we have location
    if (artTrainLatLng != null) {
      markers.add(Marker(
        point: artTrainLatLng,
        width: 100,
        height: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accentSaffron,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(artTrainName,
                  style: GoogleFonts.poppins(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const Icon(Icons.train_rounded, color: AppColors.accentSaffron, size: 28),
          ],
        ),
      ));
    }

    // Polylines from my position to ART train
    final polylines = <Polyline>[];
    if (_routePoints.isNotEmpty) {
      polylines.add(Polyline(
        points: _routePoints,
        color: AppColors.info,
        strokeWidth: 4,
      ));
    } else if (_myPosition != null && artTrainLatLng != null) {
      polylines.add(Polyline(
        points: [_myPosition!, artTrainLatLng],
        color: AppColors.info.withValues(alpha: 0.7),
        strokeWidth: 3,
      ));
    }
    
    // Polyline from ART train to Incident
    if (artTrainLatLng != null && _artTrainRoute.isNotEmpty) {
      polylines.add(Polyline(
        points: _artTrainRoute,
        color: const Color(0xFF9C27B0).withValues(alpha: 0.8), // Unique purple for rail route
        strokeWidth: 4,
      ));
    }

    // Calculate distance
    double? distanceKm = _routeDistanceKm;
    int? etaMin = _routeEtaMin;
    if (_myPosition != null && distanceKm == null && artTrainLatLng != null) {
      distanceKm = _haversineDistance(_myPosition!, artTrainLatLng);
      etaMin = (distanceKm / 60 * 60).ceil();
    }

    final initialCenter = _myPosition ?? incidentLatLng;

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: 13,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.indianrailways.rrs.r2p_app',
            ),
            if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
            MarkerLayer(markers: markers),
          ],
        ),
        // Info panel at bottom
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.97),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, -3))
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_rounded, color: Colors.red, size: 14),
                        const SizedBox(width: 4),
                        Text('Incident',
                            style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.my_location_rounded, color: AppColors.info, size: 14),
                        const SizedBox(width: 4),
                        Text('My Position',
                            style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.train_rounded, color: AppColors.accentSaffron, size: 14),
                        const SizedBox(width: 4),
                        Text('ART Train',
                            style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
                if (distanceKm != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(Icons.directions_car_rounded,
                              size: 14, color: AppColors.info.withValues(alpha: 0.8)),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'You to ART Train: ${distanceKm.toStringAsFixed(2)} km  |  ETA: ~$etaMin min',
                            style: GoogleFonts.poppins(
                                fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                ],
                if (_artTrainDistKm != null && _artTrainEtaMin != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(Icons.train_rounded,
                            size: 14, color: const Color(0xFF9C27B0).withValues(alpha: 0.8)),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'ART Train to Incident: ${_artTrainDistKm!.toStringAsFixed(2)} km  |  ETA: ~$_artTrainEtaMin min',
                          style: GoogleFonts.poppins(
                              fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.primaryNavy.withValues(alpha: 0.6)),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildSeverityBar(int severity) {
    const colors = [
      Color(0xFF4CAF50),
      Color(0xFF8BC34A),
      Color(0xFFFFC107),
      Color(0xFFFF9800),
      Color(0xFFFF5722),
      Color(0xFFD50000),
    ];
    return Row(
      children: List.generate(6, (i) {
        final active = i < severity;
        return Expanded(
          child: Container(
            height: 10,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: active ? colors[i] : colors[i].withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}
