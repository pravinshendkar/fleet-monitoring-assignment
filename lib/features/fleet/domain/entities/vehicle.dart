import 'package:equatable/equatable.dart';

enum VehicleStatus { moving, idle, stopped, offline }

class Vehicle extends Equatable {
  final String id;
  final String name;
  final VehicleStatus status;
  final double lastLatitude;
  final double lastLongitude;
  final double lastSoc;
  final DateTime lastSeenAt;
  final bool ignition;

  const Vehicle({
    required this.id,
    required this.name,
    required this.status,
    required this.lastLatitude,
    required this.lastLongitude,
    required this.lastSoc,
    required this.lastSeenAt,
    required this.ignition,
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
        lastSoc,
        lastSeenAt,
        ignition,
      ];
}
