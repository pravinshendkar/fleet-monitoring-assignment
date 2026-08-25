import '../../domain/entities/vehicle.dart';

class VehicleModel extends Vehicle {
  const VehicleModel({
    required super.id,
    required super.name,
    required super.status,
    required super.lastLatitude,
    required super.lastLongitude,
    required super.lastSoc,
    required super.lastSeenAt,
    required super.ignition,
  });

  factory VehicleModel.fromMap(Map<String, dynamic> map) {
    return VehicleModel(
      id: map['vehicle_id'] as String,
      name: map['name'] as String,
      status: VehicleStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => VehicleStatus.offline,
      ),
      lastLatitude: (map['last_latitude'] as num).toDouble(),
      lastLongitude: (map['last_longitude'] as num).toDouble(),
      lastSoc: (map['last_soc'] as num).toDouble(),
      lastSeenAt: map['last_seen_at'] is DateTime
          ? map['last_seen_at'] as DateTime
          : DateTime.parse(map['last_seen_at'].toString()),
      ignition: (map['ignition'] is bool)
          ? map['ignition'] as bool
          : (map['ignition'].toString() == '1' || map['ignition'].toString() == 'true'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vehicle_id': id,
      'name': name,
      'status': status.name,
      'last_latitude': lastLatitude,
      'last_longitude': lastLongitude,
      'last_soc': lastSoc,
      'last_seen_at': lastSeenAt.toIso8601String(),
      'ignition': ignition,
    };
  }

  factory VehicleModel.fromEntity(Vehicle vehicle) {
    return VehicleModel(
      id: vehicle.id,
      name: vehicle.name,
      status: vehicle.status,
      lastLatitude: vehicle.lastLatitude,
      lastLongitude: vehicle.lastLongitude,
      lastSoc: vehicle.lastSoc,
      lastSeenAt: vehicle.lastSeenAt,
      ignition: vehicle.ignition,
    );
  }
}
