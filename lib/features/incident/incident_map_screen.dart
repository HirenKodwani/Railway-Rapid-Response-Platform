import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/colors.dart';
import '../../core/models/incident_model.dart';
import '../../core/services/incident_service.dart';
import '../../core/services/railway_routing_service.dart';
import '../auth/auth_provider.dart';
import 'incident_provider.dart';

class IncidentMapScreen extends ConsumerStatefulWidget {
  final IncidentModel incident;
  const IncidentMapScreen({super.key, required this.incident});

  @override
  ConsumerState<IncidentMapScreen> createState() => _IncidentMapScreenState();
}

class _IncidentMapScreenState extends ConsumerState<IncidentMapScreen> {
  final MapController _mapController = MapController();
  
  LatLng? _artTrainLatLng;
  double? _artTrainDistKm;
  int? _artTrainEtaMin;
  List<LatLng> _artTrainRoute = [];
  
  List<LatLng> _selectedOperatorRoute = [];
  String? _selectedOperatorName;
  int? _selectedOperatorEta;
  double? _selectedOperatorDist;

  @override
  void initState() {
    super.initState();
    ref.read(operatorLocationsProvider.notifier).startPolling(widget.incident.id);
    _fetchArtTrainData();
  }

  @override
  void deactivate() {
    ref.read(operatorLocationsProvider.notifier).stopPolling();
    super.deactivate();
  }

  Future<void> _fetchArtTrainData() async {
    if (widget.incident.artTrainId == null) return;
    
    final token = ref.read(authProvider).token;
    if (token == null) return;

    // Fetch live location
    final locResult = await IncidentService.getArtTrainLocation(token: token, trainId: widget.incident.artTrainId!);
    if (locResult.success && locResult.data != null) {
      final lat = locResult.data!['latitude'] as double;
      final lng = locResult.data!['longitude'] as double;
      
      if (mounted) {
        setState(() {
          _artTrainLatLng = LatLng(lat, lng);
        });
        
        // Fetch route using RailwayRoutingService
        final routingService = RailwayRoutingService();
        final routeResult = await routingService.getRailRoute(
          startLat: lat,
          startLng: lng,
          endLat: widget.incident.latitude,
          endLng: widget.incident.longitude,
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

  Future<void> _onOperatorTapped(OperatorLocationModel opLoc) async {
    if (_artTrainLatLng == null) return;
    
    final token = ref.read(authProvider).token;
    if (token == null) return;

    final result = await IncidentService.getOperatorToArtRoute(
      token: token,
      operatorLat: opLoc.latitude,
      operatorLng: opLoc.longitude,
      artLat: _artTrainLatLng!.latitude,
      artLng: _artTrainLatLng!.longitude,
    );

    if (result.success && result.data != null && mounted) {
      final data = result.data!;
      final geojson = data['routeGeoJSON'];
      List<LatLng> routePts = [];
      
      if (geojson != null && geojson['type'] == 'LineString') {
        final coords = geojson['coordinates'] as List;
        for (var coord in coords) {
          // GeoJSON is [lng, lat]
          routePts.add(LatLng((coord[1] as num).toDouble(), (coord[0] as num).toDouble()));
        }
      }

      setState(() {
        _selectedOperatorName = opLoc.operatorName;
        _selectedOperatorRoute = routePts;
        _selectedOperatorDist = (data['distanceKm'] as num).toDouble();
        _selectedOperatorEta = (data['etaMinutes'] as num).toInt();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final locState = ref.watch(operatorLocationsProvider);
    final incident = widget.incident;
    final incidentLatLng = LatLng(incident.latitude, incident.longitude);

    // Operator markers for clustering
    final operatorMarkers = locState.locations.map((loc) {
      return Marker(
        point: LatLng(loc.latitude, loc.longitude),
        width: 100,
        height: 66,
        child: GestureDetector(
          onTap: () => _onOperatorTapped(loc),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryNavy,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  loc.operatorName,
                  style: GoogleFonts.poppins(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.person_pin_circle_rounded, color: AppColors.info, size: 30),
                  if (loc.attendanceStatus == 'PRESENT')
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.check_circle, color: AppColors.success, size: 14),
                      ),
                    )
                  else if (loc.acceptanceStatus == 'PENDING')
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.schedule, color: Colors.amber, size: 14),
                      ),
                    ),
                  if (loc.responseStatus == 'REACHED')
                    Positioned(
                      left: -4,
                      top: -4,
                      child: Container(
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.flag, color: Colors.blue, size: 14),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }).toList();

    // Static markers (Incident, ART Train)
    final staticMarkers = <Marker>[
      Marker(
        point: incidentLatLng,
        width: 130,
        height: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.red.shade800, borderRadius: BorderRadius.circular(6)),
              child: Text(
                '${incident.incidentSubcategory.split(' ').take(2).join(' ')}\n${incident.trainNumber}',
                style: GoogleFonts.poppins(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ),
            const _PulsingMarker(color: Colors.red, icon: Icons.warning_rounded),
          ],
        ),
      ),
    ];

    if (_artTrainLatLng != null) {
      staticMarkers.add(Marker(
        point: _artTrainLatLng!,
        width: 110,
        height: 66,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppColors.accentSaffron, borderRadius: BorderRadius.circular(6)),
              child: Text(
                incident.artTrainName ?? 'ART Train',
                style: GoogleFonts.poppins(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.train_rounded, color: AppColors.accentSaffron, size: 30),
          ],
        ),
      ));
    }

    final polylines = <Polyline>[];
    
    // Train to Incident line
    if (_artTrainLatLng != null && _artTrainRoute.isNotEmpty) {
      // Precise Rail Track Route from Railway Routing Service
      polylines.add(Polyline(
        points: _artTrainRoute,
        color: const Color(0xFF9C27B0).withValues(alpha: 0.8), // Unique purple
        strokeWidth: 4,
      ));
    }

    // Operator to Train line (OSRM)
    if (_selectedOperatorRoute.isNotEmpty) {
      polylines.add(Polyline(
        points: _selectedOperatorRoute,
        color: AppColors.info,
        strokeWidth: 4,
      ));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Live Incident Map', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.primaryNavy,
        foregroundColor: Colors.white,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppColors.darkGradient)),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: incidentLatLng,
              initialZoom: 13,
              onTap: (_, __) {
                if (mounted) setState(() {
                  _selectedOperatorRoute = [];
                  _selectedOperatorName = null;
                });
              }
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.indianrailways.rrs.r2p_app',
              ),
              if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 45,
                  size: const Size(40, 40),
                  markers: operatorMarkers,
                  builder: (context, markers) {
                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.info,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          markers.length.toString(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  },
                ),
              ),
              MarkerLayer(markers: staticMarkers),
            ],
          ),
          
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.97),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, -3))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${incident.incidentSubcategory} • Train ${incident.trainNumber}',
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                        child: Text('LIVE', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.error)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.warning_rounded, color: Colors.red, size: 14),
                      const SizedBox(width: 4),
                      Text('Incident', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                      const SizedBox(width: 12),
                      const Icon(Icons.train_rounded, color: AppColors.accentSaffron, size: 14),
                      const SizedBox(width: 4),
                      Text('ART Train', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                      const SizedBox(width: 12),
                      const Icon(Icons.person_pin_circle_rounded, color: AppColors.info, size: 14),
                      const SizedBox(width: 4),
                      Text('Operators (${locState.locations.length})', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                  
                  if (_selectedOperatorName != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          const Icon(Icons.directions_car_rounded, color: AppColors.info, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Route: ${_selectedOperatorName!} to ART Train', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                Text('ETA: ${_selectedOperatorEta ?? '--'} min (${_selectedOperatorDist?.toStringAsFixed(1) ?? '--'} km)', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ] else if (_artTrainDistKm != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.route_rounded, size: 14, color: AppColors.primaryNavy.withValues(alpha: 0.6)),
                        const SizedBox(width: 4),
                        Text(
                          'ART Train ETA: ~$_artTrainEtaMin min (${_artTrainDistKm!.toStringAsFixed(1)} km)',
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    Text('Route calculation includes rail-network curve factor adjustment.', style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textSubtle)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingMarker extends StatefulWidget {
  final Color color;
  final IconData icon;
  const _PulsingMarker({required this.color, required this.icon});

  @override
  State<_PulsingMarker> createState() => _PulsingMarkerState();
}

class _PulsingMarkerState extends State<_PulsingMarker> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.6, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _animation, child: Icon(widget.icon, color: widget.color, size: 36));
  }
}
