import 'package:equatable/equatable.dart';

class Geofence extends Equatable {
  final String id;
  final String name;
  final double centerLat;
  final double centerLng;
  final double radiusMeters;
  final bool isActive;
  final DateTime createdAt;
  final int activeVehicleCount;

  const Geofence({
    required this.id,
    required this.name,
    required this.centerLat,
    required this.centerLng,
    required this.radiusMeters,
    required this.isActive,
    required this.createdAt,
    this.activeVehicleCount = 0,
  });

  Geofence copyWith({
    String? id,
    String? name,
    double? centerLat,
    double? centerLng,
    double? radiusMeters,
    bool? isActive,
    DateTime? createdAt,
    int? activeVehicleCount,
  }) {
    return Geofence(
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

  @override
  List<Object?> get props => [
        id,
        name,
        centerLat,
        centerLng,
        radiusMeters,
        isActive,
        createdAt,
        activeVehicleCount,
      ];
}
