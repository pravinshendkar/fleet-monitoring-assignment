import 'package:fleet_console/features/fleet/domain/entities/telemetry_packet.dart';
import '../entities/alert.dart';

abstract class AlertRepository {
  Future<List<Alert>> getActiveAlerts();
  Future<List<Alert>> getVehicleAlerts(String vehicleId);
  Future<List<Alert>> getAllAlerts();
  Future<void> updateAlertStatus(String alertId, AlertStatus status, {String? dismissalReason});
  Future<void> evaluateTelemetryAlerts(List<TelemetryPacket> packets);
}
