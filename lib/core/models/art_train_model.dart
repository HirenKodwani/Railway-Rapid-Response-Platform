/// ART Train data model — mirrors the MongoDB ArtTrain schema
class ArtTrainModel {
  final String id;
  final String name;
  final String division;
  final String? zone;
  final double? depotLat;
  final double? depotLng;
  final String? gpsDeviceId;
  final String? supervisorId;
  final String? supervisorName;
  final String? supervisorEmail;
  final String? supervisorPhone;
  final String? supervisorEmployeeId;
  final String? zoneId;
  final int operatorCount;
  final DateTime? createdAt;

  ArtTrainModel({
    required this.id,
    required this.name,
    required this.division,
    this.zone,
    this.depotLat,
    this.depotLng,
    this.gpsDeviceId,
    this.supervisorId,
    this.supervisorName,
    this.supervisorEmail,
    this.supervisorPhone,
    this.supervisorEmployeeId,
    this.zoneId,
    this.operatorCount = 0,
    this.createdAt,
  });

  factory ArtTrainModel.fromJson(Map<String, dynamic> json) {
    // Supervisor may be populated as an object or just an ID string
    final supervisor = json['supervisor_id'];
    String? supId;
    String? supName;
    String? supEmail;
    String? supPhone;
    String? supEmpId;

    if (supervisor is Map<String, dynamic>) {
      supId = supervisor['_id']?.toString() ?? supervisor['id']?.toString();
      supName = supervisor['name'];
      supEmail = supervisor['email'];
      supPhone = supervisor['phone'];
      supEmpId = supervisor['employee_id'];
    } else if (supervisor is String) {
      supId = supervisor;
    }

    return ArtTrainModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      division: json['division'] ?? '',
      zone: json['zone'],
      depotLat: json['depot_lat']?.toDouble(),
      depotLng: json['depot_lng']?.toDouble(),
      gpsDeviceId: json['gps_device_id'],
      supervisorId: supId,
      supervisorName: supName,
      supervisorEmail: supEmail,
      supervisorPhone: supPhone,
      supervisorEmployeeId: supEmpId,
      zoneId: json['zone_id'],
      operatorCount: json['operatorCount'] ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])?.toLocal()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'division': division,
      if (zone != null) 'zone': zone,
      if (depotLat != null) 'depot_lat': depotLat,
      if (depotLng != null) 'depot_lng': depotLng,
      if (gpsDeviceId != null) 'gps_device_id': gpsDeviceId,
      if (supervisorId != null) 'supervisor_id': supervisorId,
      if (zoneId != null) 'zone_id': zoneId,
    };
  }
}
