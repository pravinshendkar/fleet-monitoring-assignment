import '../../domain/entities/trip.dart';

class TripModel extends Trip {
  const TripModel({
    required super.id,
    required super.vehicleId,
    required super.startGeofenceId,
    super.endGeofenceId,
    required super.startTime,
    super.endTime,
    required super.distanceKm,
    required super.maxSpeedKmh,
    required super.averageSocUsed,
    required super.status,
  });

  factory TripModel.fromMap(Map<String, dynamic> map) {
    return TripModel(
      id: map['trip_id'] as String,
      vehicleId: map['vehicle_id'] as String,
      startGeofenceId: map['start_geofence_id'] as String,
      endGeofenceId: map['end_geofence_id'] as String?,
      startTime: map['start_time'] is DateTime
          ? map['start_time'] as DateTime
          : DateTime.parse(map['start_time'].toString()),
      endTime: map['end_time'] != null
          ? (map['end_time'] is DateTime
              ? map['end_time'] as DateTime
              : DateTime.parse(map['end_time'].toString()))
          : null,
      distanceKm: (map['distance_km'] as num).toDouble(),
      maxSpeedKmh: (map['max_speed'] as num).toDouble(),
      averageSocUsed: (map['average_soc_used'] as num).toDouble(),
      status: TripStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => TripStatus.ongoing,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'trip_id': id,
      'vehicle_id': vehicleId,
      'start_geofence_id': startGeofenceId,
      'end_geofence_id': endGeofenceId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'distance_km': distanceKm,
      'max_speed': maxSpeedKmh,
      'average_soc_used': averageSocUsed,
      'status': status.name,
    };
  }

  factory TripModel.fromEntity(Trip trip) {
    return TripModel(
      id: trip.id,
      vehicleId: trip.vehicleId,
      startGeofenceId: trip.startGeofenceId,
      endGeofenceId: trip.endGeofenceId,
      startTime: trip.startTime,
      endTime: trip.endTime,
      distanceKm: trip.distanceKm,
      maxSpeedKmh: trip.maxSpeedKmh,
      averageSocUsed: trip.averageSocUsed,
      status: trip.status,
    );
  }
}
