import 'package:equatable/equatable.dart';

class FleetSummary extends Equatable {
  final int totalVehicles;
  final int movingCount;
  final int idleCount;
  final int stoppedCount;
  final int offlineCount;
  final int lowBatteryAlertCount;

  const FleetSummary({
    required this.totalVehicles,
    required this.movingCount,
    required this.idleCount,
    required this.stoppedCount,
    required this.offlineCount,
    required this.lowBatteryAlertCount,
  });

  @override
  List<Object?> get props => [
        totalVehicles,
        movingCount,
        idleCount,
        stoppedCount,
        offlineCount,
        lowBatteryAlertCount,
      ];
}
