/// Incident data model — mirrors the MongoDB Incident schema
class IncidentModel {
  final String id;
  final String trainNumber;
  final double latitude;
  final double longitude;
  final String incidentCategory;
  final String incidentSubcategory;
  final String affectedComponent;
  final int severity;
  final bool isMockDrill;
  final String status;
  final String createdById;
  final String? createdByName;
  final String? artTrainId;
  final String? artTrainName;
  final double? artTrainLat;
  final double? artTrainLng;
  final String? zone;
  final String? division;
  final List<OperatorAlert> alertedOperators;
  final DateTime? resolvedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? reportUrl;
  final DateTime? reportGeneratedAt;
  final String? accessToken;

  IncidentModel({
    required this.id,
    required this.trainNumber,
    required this.latitude,
    required this.longitude,
    required this.incidentCategory,
    required this.incidentSubcategory,
    required this.affectedComponent,
    required this.severity,
    required this.isMockDrill,
    required this.status,
    required this.createdById,
    this.createdByName,
    this.artTrainId,
    this.artTrainName,
    this.artTrainLat,
    this.artTrainLng,
    this.zone,
    this.division,
    this.alertedOperators = const [],
    this.resolvedAt,
    this.createdAt,
    this.updatedAt,
    this.reportUrl,
    this.reportGeneratedAt,
    this.accessToken,
  });

  factory IncidentModel.fromJson(Map<String, dynamic> json) {
    // Parse created_by (can be object or string)
    String createdById = '';
    String? createdByName;
    final createdBy = json['created_by'];
    if (createdBy is Map<String, dynamic>) {
      createdById = createdBy['_id']?.toString() ?? createdBy['id']?.toString() ?? '';
      createdByName = createdBy['name'];
    } else if (createdBy is String) {
      createdById = createdBy;
    }

    // Parse art_train_id (can be object or string)
    String? artTrainId;
    String? artTrainName;
    double? artTrainLat;
    double? artTrainLng;
    final artTrain = json['art_train_id'];
    if (artTrain is Map<String, dynamic>) {
      artTrainId = artTrain['_id']?.toString() ?? artTrain['id']?.toString();
      artTrainName = artTrain['name'];
      artTrainLat = artTrain['depot_lat']?.toDouble();
      artTrainLng = artTrain['depot_lng']?.toDouble();
    } else if (artTrain is String) {
      artTrainId = artTrain;
    }

    // Parse alerted operators
    List<OperatorAlert> operators = [];
    if (json['alerted_operators'] is List) {
      operators = (json['alerted_operators'] as List)
          .map((op) => OperatorAlert.fromJson(op as Map<String, dynamic>))
          .toList();
    }

    return IncidentModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      trainNumber: json['train_number'] ?? '',
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      incidentCategory: json['incident_category'] ?? '',
      incidentSubcategory: json['incident_subcategory'] ?? '',
      affectedComponent: json['affected_component'] ?? '',
      severity: json['severity'] ?? 1,
      isMockDrill: json['is_mock_drill'] ?? false,
      status: json['status'] ?? 'active',
      createdById: createdById,
      createdByName: createdByName,
      artTrainId: artTrainId,
      artTrainName: artTrainName,
      artTrainLat: artTrainLat,
      artTrainLng: artTrainLng,
      zone: json['zone'],
      division: json['division'],
      alertedOperators: operators,
      resolvedAt: json['resolved_at'] != null ? DateTime.tryParse(json['resolved_at'])?.toLocal() : null,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'])?.toLocal() : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'])?.toLocal() : null,
      reportUrl: json['reportUrl'],
      reportGeneratedAt: json['reportGeneratedAt'] != null ? DateTime.tryParse(json['reportGeneratedAt'])?.toLocal() : null,
      accessToken: json['accessToken'],
    );
  }

  bool get isActive => status == 'active';
}

/// Operator alert entry within an incident
class OperatorAlert {
  final String operatorId;
  final String? operatorName;
  final String? operatorEmployeeId;
  final String response;
  final String? declineReason;
  final DateTime? respondedAt;

  OperatorAlert({
    required this.operatorId,
    this.operatorName,
    this.operatorEmployeeId,
    required this.response,
    this.declineReason,
    this.respondedAt,
  });

  factory OperatorAlert.fromJson(Map<String, dynamic> json) {
    String operatorId = '';
    String? operatorName;
    String? operatorEmployeeId;
    final op = json['operator_id'];
    if (op is Map<String, dynamic>) {
      operatorId = op['_id']?.toString() ?? op['id']?.toString() ?? '';
      operatorName = op['name'];
      operatorEmployeeId = op['employee_id'];
    } else if (op is String) {
      operatorId = op;
    }

    return OperatorAlert(
      operatorId: operatorId,
      operatorName: operatorName,
      operatorEmployeeId: operatorEmployeeId,
      response: json['response'] ?? 'pending',
      declineReason: json['decline_reason'],
      respondedAt: json['responded_at'] != null ? DateTime.tryParse(json['responded_at'])?.toLocal() : null,
    );
  }
}

/// Operator location on the map
class OperatorLocationModel {
  final String operatorId;
  final String operatorName;
  final String operatorEmployeeId;
  final double latitude;
  final double longitude;
  final DateTime? updatedAt;
  final String attendanceStatus;
  final String responseStatus;
  final String acceptanceStatus;

  OperatorLocationModel({
    required this.operatorId,
    required this.operatorName,
    this.operatorEmployeeId = '',
    required this.latitude,
    required this.longitude,
    this.updatedAt,
    this.attendanceStatus = 'PENDING',
    this.responseStatus = 'PENDING',
    this.acceptanceStatus = 'PENDING',
  });

  factory OperatorLocationModel.fromJson(Map<String, dynamic> json) {
    return OperatorLocationModel(
      operatorId: json['operator_id']?.toString() ?? '',
      operatorName: json['operator_name'] ?? 'Unknown',
      operatorEmployeeId: json['operator_employee_id'] ?? '',
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'])?.toLocal() : null,
      attendanceStatus: json['attendanceStatus'] ?? 'PENDING',
      responseStatus: json['responseStatus'] ?? 'PENDING',
      acceptanceStatus: json['acceptanceStatus'] ?? 'PENDING',
    );
  }
}
