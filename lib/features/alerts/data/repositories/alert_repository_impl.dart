import '../../../../core/database/database_event_bus.dart';
import '../../../fleet/data/models/telemetry_packet_model.dart';
import '../../../fleet/domain/entities/telemetry_packet.dart';
import '../../domain/entities/alert.dart';
import '../../domain/repositories/alert_repository.dart';
import '../datasources/alert_local_datasource.dart';

class AlertRepositoryImpl implements AlertRepository {
  final AlertLocalDataSource localDataSource;
  final DatabaseEventBus eventBus;

  AlertRepositoryImpl({required this.localDataSource, required this.eventBus});

  @override
  Future<List<Alert>> getActiveAlerts() async {
    return await localDataSource.getActiveAlerts();
  }

  @override
  Future<List<Alert>> getVehicleAlerts(String vehicleId) async {
    return await localDataSource.getVehicleAlerts(vehicleId);
  }

  @override
  Future<List<Alert>> getAllAlerts() async {
    return await localDataSource.getAllAlerts();
  }

  @override
  Future<void> updateAlertStatus(
    String alertId,
    AlertStatus status, {
    String? dismissalReason,
  }) async {
    await localDataSource.updateAlertStatus(
      alertId,
      status,
      dismissalReason: dismissalReason,
    );
    eventBus.notify(
      DatabaseChangeEvent(table: DatabaseTable.alerts, entityId: alertId),
    );
  }

  @override
  Future<void> evaluateTelemetryAlerts(List<TelemetryPacket> packets) async {
    final models = packets
        .map((p) => TelemetryPacketModel.fromEntity(p))
        .toList();
    await localDataSource.evaluateTelemetryAlerts(models);
    eventBus.notify(DatabaseChangeEvent(table: DatabaseTable.alerts));
  }
}
