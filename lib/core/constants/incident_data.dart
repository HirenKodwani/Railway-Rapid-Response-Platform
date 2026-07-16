/// Incident data constants — categories, sub-categories, components, severity
/// Module 3: Rapid Response Incident Management

class IncidentData {
  IncidentData._();

  /// Level-1 incident categories
  static const List<String> categories = [
    'Accident',
    'Infrastructure Failure',
    'Natural Disaster',
    'Security Incident',
    'Passenger Emergency',
    'Operational Incident',
    'Hazardous Material',
  ];

  /// Level-2 sub-categories mapped by Level-1 category
  static const Map<String, List<String>> subcategories = {
    'Accident': [
      'Train Derailment',
      'Train Collision (Head-on)',
      'Train Collision (Rear-end)',
      'Train Collision (Side/Flank)',
      'Level Crossing Accident',
      'Train Fire',
      'Coach Fire',
      'Locomotive Failure Leading to Accident',
      'Rolling Stock Failure',
    ],
    'Infrastructure Failure': [
      'Track Failure / Rail Fracture',
      'Bridge Damage / Collapse',
      'Signal Failure',
      'OHE Failure',
      'Point & Crossing Failure',
      'Platform Damage',
      'Tunnel Incident',
    ],
    'Natural Disaster': [
      'Flooding',
      'Landslide',
      'Cyclone / Storm Damage',
      'Earthquake',
      'Lightning Strike',
      'Tree Fall on Track',
      'Washout of Track',
    ],
    'Security Incident': [
      'Bomb Threat',
      'Suspicious Object',
      'Sabotage / Vandalism',
      'Theft / Robbery',
      'Trespassing',
      'Unauthorised Track Obstruction',
      'Crowd Control Incident',
    ],
    'Passenger Emergency': [
      'Medical Emergency',
      'Passenger Injury',
      'Passenger Fatality',
      'Passenger Trapped',
      'Passenger Fall from Train',
      'Overcrowding Incident',
    ],
    'Operational Incident': [
      'Train Stuck / Immobilized',
      'Locomotive Failure',
      'Power Supply Failure',
      'Communication Failure',
      'Crew Emergency',
      'Major Service Disruption',
    ],
    'Hazardous Material': [
      'Dangerous Goods Leak',
      'Chemical Spill',
      'Fuel Leak',
      'Hazardous Cargo Fire',
    ],
  };

  /// Affected component options
  static const List<String> affectedComponents = [
    'Entire Train',
    'Multiple Coaches',
    'Front Section of Train',
    'Rear Section of Train',
    'Middle Section of Train',
  ];

  /// Severity level labels (1 = lowest, 6 = highest)
  static const List<String> severityLabels = [
    'Level 1 — Minor',
    'Level 2 — Low',
    'Level 3 — Moderate',
    'Level 4 — High',
    'Level 5 — Severe',
    'Level 6 — Critical',
  ];

  /// Predefined decline reasons for operators
  static const List<String> declineReasons = [
    'Not on duty',
    'Medical emergency (personal)',
    'Already at another location',
    'Transportation issue',
    'Unable to reach in time',
    'Other',
  ];
}
