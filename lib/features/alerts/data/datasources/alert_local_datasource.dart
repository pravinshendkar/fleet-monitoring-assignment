import '../../../../core/database/duckdb_client.dart';
import '../../../fleet/data/models/telemetry_packet_model.dart';
import '../../domain/entities/alert.dart';
import '../models/alert_model.dart';

abstract class AlertLocalDataSource {
  Future<List<AlertModel>> getActiveAlerts();
  Future<List<AlertModel>> getVehicleAlerts(String vehicleId);
  Future<List<AlertModel>> getAllAlerts();
  Future<void> updateAlertStatus(
    String alertId,
    AlertStatus status, {
    String? dismissalReason,
  });
  Future<void> evaluateTelemetryAlerts(List<TelemetryPacketModel> packets);
}

class AlertLocalDataSourceImpl implements AlertLocalDataSource {
  final DuckDbClient dbClient;

  AlertLocalDataSourceImpl({required this.dbClient});

  @override
  Future<List<AlertModel>> getActiveAlerts() async {
    const sql = '''
      SELECT * FROM alerts
      WHERE status IN ('active', 'escalated')
      ORDER BY created_at DESC;
    ''';
    final maps = await dbClient.query(sql);
    return maps.map((m) => AlertModel.fromMap(m)).toList();
  }

  @override
  Future<List<AlertModel>> getVehicleAlerts(String vehicleId) async {
    final cleanVid = vehicleId.replaceAll("'", "''");
    final sql =
        '''
      SELECT * FROM alerts
      WHERE vehicle_id = '$cleanVid'
      ORDER BY created_at DESC;
    ''';
    final maps = await dbClient.query(sql);
    return maps.map((m) => AlertModel.fromMap(m)).toList();
  }

  @override
  Future<List<AlertModel>> getAllAlerts() async {
    const sql = '''
      SELECT * FROM alerts
      ORDER BY updated_at DESC;
    ''';
    final maps = await dbClient.query(sql);
    return maps.map((m) => AlertModel.fromMap(m)).toList();
  }

  @override
  Future<void> updateAlertStatus(
    String alertId,
    AlertStatus status, {
    String? dismissalReason,
  }) async {
    final cleanId = alertId.replaceAll("'", "''");
    final now = DateTime.now().toUtc().toIso8601String();

    if (status == AlertStatus.dismissed) {
      final cleanReason = dismissalReason != null
          ? "'${dismissalReason.replaceAll("'", "''")}'"
          : "NULL";
      final sql =
          '''
        UPDATE alerts
        SET status = '${status.name}',
            updated_at = '$now',
            dismissed_at = '$now',
            dismissal_reason = $cleanReason
        WHERE alert_id = '$cleanId';
      ''';
      await dbClient.execute(sql);
    } else {
      final sql =
          '''
        UPDATE alerts
        SET status = '${status.name}',
            updated_at = '$now',
            dismissed_at = NULL,
            dismissal_reason = NULL
        WHERE alert_id = '$cleanId';
      ''';
      await dbClient.execute(sql);
    }
  }

  @override
  Future<void> evaluateTelemetryAlerts(
    List<TelemetryPacketModel> packets,
  ) async {
    if (packets.isEmpty) return;

    final now = DateTime.now().toUtc().toIso8601String();

    for (final packet in packets) {
      final vid = packet.vehicleId.replaceAll("'", "''");

      // 1. Low Battery Threshold Evaluation (< 20%)
      if (packet.batteryLevel != null && packet.batteryLevel! <= 20.0) {
        final isCritical = packet.batteryLevel! <= 10.0;
        final alertType = isCritical
            ? AlertType.criticalBattery
            : AlertType.lowBattery;
        final alertStatus = isCritical
            ? AlertStatus.escalated
            : AlertStatus.active;
        final alertId = 'alert_soc_$vid';

        final sql =
            '''
          INSERT INTO alerts (
            alert_id, vehicle_id, type, status, trigger_value, threshold, created_at, updated_at
          ) VALUES (
            '$alertId', '$vid', '${alertType.name}', '${alertStatus.name}', ${packet.batteryLevel!}, 20.0, '$now', '$now'
          )
          ON CONFLICT (alert_id) DO UPDATE SET
            type = EXCLUDED.type,
            status = CASE
              WHEN alerts.status = 'dismissed' THEN 'dismissed'
              ELSE EXCLUDED.status
            END,
            trigger_value = EXCLUDED.trigger_value,
            updated_at = EXCLUDED.updated_at;
        ''';
        await dbClient.execute(sql);
      } else if (packet.batteryLevel != null) {
        // Condition cleared (battery > 20%): resolve alert whether active, escalated, or dismissed!
        final alertId = 'alert_soc_$vid';
        final resolveSql =
            '''
          UPDATE alerts
          SET status = 'resolved', updated_at = '$now'
          WHERE alert_id = '$alertId' AND status != 'resolved';
        ''';
        await dbClient.execute(resolveSql);
      }

      // 2. Overheating Threshold Evaluation (> 45°C)
      if (packet.batteryTemp != null && packet.batteryTemp! > 45.0) {
        final alertId = 'alert_temp_$vid';
        final sql =
            '''
          INSERT INTO alerts (
            alert_id, vehicle_id, type, status, trigger_value, threshold, created_at, updated_at
          ) VALUES (
            '$alertId', '$vid', 'overheating', 'active', ${packet.batteryTemp!}, 45.0, '$now', '$now'
          )
          ON CONFLICT (alert_id) DO UPDATE SET
            status = CASE
              WHEN alerts.status = 'dismissed' THEN 'dismissed'
              ELSE EXCLUDED.status
            END,
            trigger_value = EXCLUDED.trigger_value,
            updated_at = EXCLUDED.updated_at;
        ''';
        await dbClient.execute(sql);
      } else if (packet.batteryTemp != null) {
        // Condition cleared (battery temp <= 45°C): resolve alert whether active or dismissed!
        final alertId = 'alert_temp_$vid';
        final resolveSql =
            '''
          UPDATE alerts
          SET status = 'resolved', updated_at = '$now'
          WHERE alert_id = '$alertId' AND status != 'resolved';
        ''';
        await dbClient.execute(resolveSql);
      }
    }
  }
}
