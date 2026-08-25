import 'package:equatable/equatable.dart';

enum TripStatus { ongoing, completed }

class Trip extends Equatable {
  final String id;
  final String vehicleId;
  final String startGeofenceId;
  final String? endGeofenceId;
  final DateTime startTime;
  final DateTime? endTime;
  final double distanceKm;
  final double maxSpeedKmh;
  final double averageSocUsed;
  final TripStatus status;

  const Trip({
    required this.id,
    required this.vehicleId,
    required this.startGeofenceId,
    this.endGeofenceId,
    required this.startTime,
    this.endTime,
    required this.distanceKm,
    required this.maxSpeedKmh,
    required this.averageSocUsed,
    required this.status,
  });

  @override
  List<Object?> get props => [
    id,
    vehicleId,
    startGeofenceId,
    endGeofenceId,
    startTime,
    endTime,
    distanceKm,
    maxSpeedKmh,
    averageSocUsed,
    status,
  ];
}
