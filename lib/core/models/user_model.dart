/// User data model — mirrors the MongoDB User schema
class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String employeeId;
  final String? zone;
  final String? division;
  final String? city;
  final double? lat;
  final double? lng;
  final String? address;
  final String? specialisation;
  final String? status;
  final bool isActive;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.employeeId,
    this.zone,
    this.division,
    this.city,
    this.lat,
    this.lng,
    this.address,
    this.specialisation,
    this.status,
    this.isActive = true,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  /// Create UserModel from JSON (API response)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? '',
      employeeId: json['employee_id'] ?? '',
      zone: json['zone'],
      division: json['division'],
      city: json['city'],
      lat: json['lat']?.toDouble(),
      lng: json['lng']?.toDouble(),
      address: json['address'],
      specialisation: json['specialisation'],
      status: json['status'],
      isActive: json['isActive'] ?? true,
      createdBy: json['createdBy'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])?.toLocal()
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'])?.toLocal()
          : null,
    );
  }

  /// Convert UserModel to JSON (for API request)
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'employee_id': employeeId,
      if (zone != null) 'zone': zone,
      if (division != null) 'division': division,
      if (city != null) 'city': city,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (address != null) 'address': address,
      if (specialisation != null) 'specialisation': specialisation,
      if (status != null) 'status': status,
    };
  }

  /// Create a copy with modified fields
  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? role,
    String? employeeId,
    String? zone,
    String? division,
    String? city,
    double? lat,
    double? lng,
    String? address,
    String? specialisation,
    String? status,
    bool? isActive,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      employeeId: employeeId ?? this.employeeId,
      zone: zone ?? this.zone,
      division: division ?? this.division,
      city: city ?? this.city,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      address: address ?? this.address,
      specialisation: specialisation ?? this.specialisation,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
