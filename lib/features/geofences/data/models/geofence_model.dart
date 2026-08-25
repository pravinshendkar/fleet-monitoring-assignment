import '../../domain/entities/geofence.dart';

class GeofenceModel extends Geofence {
  const GeofenceModel({
    required super.id,
    required super.name,
    required super.centerLat,
    required super.centerLng,
    required super.radiusMeters,
    required super.isActive,
    required super.createdAt,
    super.activeVehicleCount,
  });

  factory GeofenceModel.fromMap(Map<String, dynamic> map) {
    return GeofenceModel(
      id: map['geofence_id'] as String,
      name: map['name'] as String,
      centerLat: (map['center_lat'] as num).toDouble(),
      centerLng: (map['center_lng'] as num).toDouble(),
      radiusMeters: (map['radius_meters'] as num).toDouble(),
      isActive: (map['is_active'] is bool)
          ? map['is_active'] as bool
          : (map['is_active'].toString() == '1' ||
                map['is_active'].toString() == 'true'),
      createdAt: map['created_at'] is DateTime
          ? map['created_at'] as DateTime
          : DateTime.parse(map['created_at'].toString()),
      activeVehicleCount: _parseInt(map['active_vehicle_count']),
    );
  }

  static int _parseInt(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val.toInt();
    if (val is BigInt) return val.toInt();
    return int.tryParse(val.toString()) ?? 0;
  }

  Map<String, dynamic> toMap() {
    return {
      'geofence_id': id,
      'name': name,
      'center_lat': centerLat,
      'center_lng': centerLng,
      'radius_meters': radiusMeters,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory GeofenceModel.fromEntity(Geofence geofence) {
    return GeofenceModel(
      id: geofence.id,
      name: geofence.name,
      centerLat: geofence.centerLat,
      centerLng: geofence.centerLng,
      radiusMeters: geofence.radiusMeters,
      isActive: geofence.isActive,
      createdAt: geofence.createdAt,
      activeVehicleCount: geofence.activeVehicleCount,
    );
  }

  @override
  GeofenceModel copyWith({
    String? id,
    String? name,
    double? centerLat,
    double? centerLng,
    double? radiusMeters,
    bool? isActive,
    DateTime? createdAt,
    int? activeVehicleCount,
  }) {
    return GeofenceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      centerLat: centerLat ?? this.centerLat,
      centerLng: centerLng ?? this.centerLng,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      activeVehicleCount: activeVehicleCount ?? this.activeVehicleCount,
    );
  }
}
