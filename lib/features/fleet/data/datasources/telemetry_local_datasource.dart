import '../../../../core/database/duckdb_client.dart';
import '../../domain/entities/vehicle.dart';
import '../models/telemetry_packet_model.dart';

abstract class TelemetryLocalDataSource {
  Future<void> insertTelemetryBatch(List<TelemetryPacketModel> packets);
  Future<List<TelemetryPacketModel>> getVehicleTelemetryHistory(
    String vehicleId, {
    DateTime? startTime,
    DateTime? endTime,
    int limit = 100,
  });
  Future<List<TelemetryPacketModel>> getSocHistory(
    String vehicleId, {
    DateTime? startTime,
    int limit = 100,
  });
}

class TelemetryLocalDataSourceImpl implements TelemetryLocalDataSource {
  final DuckDbClient dbClient;

  TelemetryLocalDataSourceImpl({required this.dbClient});

  @override
  Future<void> insertTelemetryBatch(List<TelemetryPacketModel> packets) async {
    if (packets.isEmpty) return;

    await dbClient.execute('BEGIN TRANSACTION;');

    try {
      const chunkSize = 500;
      for (var i = 0; i < packets.length; i += chunkSize) {
        final end = (i + chunkSize < packets.length)
            ? i + chunkSize
            : packets.length;
        final chunk = packets.sublist(i, end);

        final values = chunk
            .map((p) {
              final eventTs = p.eventTimestamp.toUtc().toIso8601String();
              final ingestTs = p.ingestTimestamp.toUtc().toIso8601String();
              final pid = p.packetId.replaceAll("'", "''");
              final vid = p.vehicleId.replaceAll("'", "''");
              return "('$pid', '$vid', '$eventTs', '$ingestTs', ${p.latitude}, ${p.longitude}, ${p.speed}, ${p.batteryLevel}, ${p.batteryTemp}, ${p.odometerKm}, ${p.ignition}, ${p.gpsAccuracy})";
            })
            .join(', ');

        final sql =
            '''
          INSERT INTO telemetry_packets (
            packet_id, vehicle_id, event_timestamp, ingest_timestamp,
            latitude, longitude, speed, battery_level, battery_temp, odometer_km, ignition, gps_accuracy
          ) VALUES $values
          ON CONFLICT (packet_id) DO NOTHING;
        ''';

        await dbClient.execute(sql);
      }

      // Update vehicles table with latest state based on event_timestamp
      final vehicleMap = <String, TelemetryPacketModel>{};
      for (final packet in packets) {
        final existing = vehicleMap[packet.vehicleId];
        if (existing == null ||
            packet.eventTimestamp.isAfter(existing.eventTimestamp)) {
          vehicleMap[packet.vehicleId] = packet;
        }
      }

      for (final entry in vehicleMap.entries) {
        final vid = entry.key.replaceAll("'", "''");
        final p = entry.value;
        final ts = p.eventTimestamp.toUtc().toIso8601String();
        final name = 'EV-${vid.length > 6 ? vid.substring(0, 6) : vid}';

        final status = Vehicle.calculateStatus(
          lastSeenAt: p.eventTimestamp,
          speed: p.speed,
          ignition: p.ignition,
        ).name;

        final upsertSql =
            '''
          INSERT INTO vehicles (
            vehicle_id, name, status, last_latitude, last_longitude, last_soc, last_seen_at, ignition
          ) VALUES (
            '$vid', '$name', '$status', ${p.latitude}, ${p.longitude}, ${p.batteryLevel}, '$ts', ${p.ignition}
          )
          ON CONFLICT (vehicle_id) DO UPDATE SET
            status = CASE WHEN EXCLUDED.last_seen_at >= vehicles.last_seen_at THEN EXCLUDED.status ELSE vehicles.status END,
            last_latitude = CASE WHEN EXCLUDED.last_seen_at >= vehicles.last_seen_at THEN EXCLUDED.last_latitude ELSE vehicles.last_latitude END,
            last_longitude = CASE WHEN EXCLUDED.last_seen_at >= vehicles.last_seen_at THEN EXCLUDED.last_longitude ELSE vehicles.last_longitude END,
            last_soc = CASE WHEN EXCLUDED.last_seen_at >= vehicles.last_seen_at THEN EXCLUDED.last_soc ELSE vehicles.last_soc END,
            last_seen_at = CASE WHEN EXCLUDED.last_seen_at >= vehicles.last_seen_at THEN EXCLUDED.last_seen_at ELSE vehicles.last_seen_at END,
            ignition = CASE WHEN EXCLUDED.last_seen_at >= vehicles.last_seen_at THEN EXCLUDED.ignition ELSE vehicles.ignition END;
        ''';
        await dbClient.execute(upsertSql);
      }

      await dbClient.execute('COMMIT;');
    } catch (e) {
      await dbClient.execute('ROLLBACK;');
      rethrow;
    }
  }

  @override
  Future<List<TelemetryPacketModel>> getVehicleTelemetryHistory(
    String vehicleId, {
    DateTime? startTime,
    DateTime? endTime,
    int limit = 100,
  }) async {
    final cleanVid = vehicleId.replaceAll("'", "''");
    var whereClause = "WHERE vehicle_id = '$cleanVid'";

    if (startTime != null) {
      whereClause += " AND event_timestamp >= '${startTime.toIso8601String()}'";
    }
    if (endTime != null) {
      whereClause += " AND event_timestamp <= '${endTime.toIso8601String()}'";
    }

    final sql =
        '''
      SELECT * FROM telemetry_packets
      $whereClause
      ORDER BY event_timestamp DESC
      LIMIT $limit;
    ''';

    final maps = await dbClient.query(sql);
    return maps.map((m) => TelemetryPacketModel.fromMap(m)).toList();
  }

  @override
  Future<List<TelemetryPacketModel>> getSocHistory(
    String vehicleId, {
    DateTime? startTime,
    int limit = 100,
  }) async {
    return await getVehicleTelemetryHistory(
      vehicleId,
      startTime: startTime,
      limit: limit,
    );
  }
}
