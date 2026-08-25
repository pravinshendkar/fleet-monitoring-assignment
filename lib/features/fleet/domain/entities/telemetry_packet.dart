import 'package:equatable/equatable.dart';

class TelemetryPacket extends Equatable {
  final String packetId;
  final String vehicleId;
  final DateTime eventTimestamp;
  final DateTime ingestTimestamp;
  final double latitude;
  final double longitude;
  final double speed;
  final double batteryLevel; // State of Charge (SOC 0-100%)
  final double batteryTemp; // Temperature in Celsius
  final double odometerKm;
  final bool ignition;
  final double gpsAccuracy; // GPS Accuracy in meters (e.g. 5.0m)

  const TelemetryPacket({
    required this.packetId,
    required this.vehicleId,
    required this.eventTimestamp,
    required this.ingestTimestamp,
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.batteryLevel,
    required this.batteryTemp,
    required this.odometerKm,
    required this.ignition,
    this.gpsAccuracy = 5.0,
  });

  @override
  List<Object?> get props => [
    packetId,
    vehicleId,
    eventTimestamp,
    ingestTimestamp,
    latitude,
    longitude,
    speed,
    batteryLevel,
    batteryTemp,
    odometerKm,
    ignition,
    gpsAccuracy,
  ];
}
