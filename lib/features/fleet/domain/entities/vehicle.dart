import 'package:equatable/equatable.dart';

enum VehicleStatus { moving, idle, stopped, offline }

class Vehicle extends Equatable {
  final String id;
  final String name;
  final VehicleStatus status;
  final double? lastLatitude;
  final double? lastLongitude;
  final DateTime? lastLocationAt;
  final double? lastSoc;
  final DateTime? lastSocAt;
  final double? lastSpeed;
  final DateTime? lastSpeedAt;
  final bool? ignition;
  final DateTime? lastIgnitionAt;
  final double? lastTemp;
  final DateTime? lastTempAt;
  final double? lastOdometer;
  final DateTime? lastOdometerAt;
  final DateTime lastSeenAt;

  const Vehicle({
    required this.id,
    required this.name,
    required this.status,
    this.lastLatitude,
    this.lastLongitude,
    this.lastLocationAt,
    this.lastSoc,
    this.lastSocAt,
    this.lastSpeed,
    this.lastSpeedAt,
    this.ignition,
    this.lastIgnitionAt,
    this.lastTemp,
    this.lastTempAt,
    this.lastOdometer,
    this.lastOdometerAt,
    required this.lastSeenAt,
  });

  bool get isStale =>
      DateTime.now().difference(lastSeenAt) > const Duration(minutes: 10);

  /// Computes vehicle status according to explicit first-match precedence:
  /// 1. OFFLINE: last seen > 10 minutes ago
  /// 2. MOVING: speed > 0
  /// 3. IDLE: speed == 0 AND ignition is ON
  /// 4. STOPPED: ignition is OFF
  static VehicleStatus calculateStatus({
    required DateTime lastSeenAt,
    required double speed,
    required bool ignition,
    DateTime? relativeTo,
  }) {
    final now = relativeTo ?? DateTime.now();
    if (now.difference(lastSeenAt) > const Duration(minutes: 10)) {
      return VehicleStatus.offline;
    }
    if (speed > 0) {
      return VehicleStatus.moving;
    }
    if (ignition) {
      return VehicleStatus.idle;
    }
    return VehicleStatus.stopped;
  }

  @override
  List<Object?> get props => [
    id,
    name,
    status,
    lastLatitude,
    lastLongitude,
    lastLocationAt,
    lastSoc,
    lastSocAt,
    lastSpeed,
    lastSpeedAt,
    ignition,
    lastIgnitionAt,
    lastTemp,
    lastTempAt,
    lastOdometer,
    lastOdometerAt,
    lastSeenAt,
  ];
}
