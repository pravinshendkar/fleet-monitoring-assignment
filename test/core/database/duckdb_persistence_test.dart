import 'dart:io';
import 'package:fleet_console/core/database/duckdb_client.dart';
import 'package:fleet_console/features/fleet/data/datasources/telemetry_local_datasource.dart';
import 'package:fleet_console/features/fleet/data/datasources/vehicle_local_datasource.dart';
import 'package:fleet_console/features/fleet/data/models/telemetry_packet_model.dart';
import 'package:fleet_console/features/fleet/domain/entities/vehicle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DuckDB Schema & Persistence Tests', () {
    late DuckDbClient client;
    late String tempDbPath;

    setUp(() async {
      tempDbPath = 'test_fleet_${DateTime.now().millisecondsSinceEpoch}.duckdb';
      client = DuckDbClient();
      await client.init(tempDbPath);
    });

    tearDown(() async {
      await client.close();
      final file = File(tempDbPath);
      if (await file.exists()) {
        await file.delete();
      }
    });

    test('1. Database initialization and table creation', () async {
      final tablesResult = await client.query(
        "SELECT table_name FROM information_schema.tables WHERE table_schema = 'main';",
      );
      final tableNames = tablesResult.map((r) => r['table_name'] as String).toList();

      expect(tableNames, contains('telemetry_packets'));
      expect(tableNames, contains('vehicles'));
      expect(tableNames, contains('alerts'));
      expect(tableNames, contains('geofences'));
      expect(tableNames, contains('geofence_events'));
      expect(tableNames, contains('trips'));
    });

    test('2. Telemetry Insert, Read, and Duplicate Idempotency', () async {
      final telemetryDS = TelemetryLocalDataSourceImpl(dbClient: client);

      final now = DateTime.now();
      final packet1 = TelemetryPacketModel(
        packetId: 'p1',
        vehicleId: 'v1',
        eventTimestamp: now.subtract(const Duration(minutes: 5)),
        ingestTimestamp: now,
        latitude: 12.9716,
        longitude: 77.5946,
        speed: 35.0,
        batteryLevel: 80.0,
        batteryTemp: 30.0,
        odometerKm: 100.0,
        ignition: true,
      );

      // Ingest packet twice to test idempotency
      await telemetryDS.insertTelemetryBatch([packet1]);
      await telemetryDS.insertTelemetryBatch([packet1]); // Duplicate submission

      final history = await telemetryDS.getVehicleTelemetryHistory('v1');
      expect(history.length, 1);
      expect(history.first.packetId, 'p1');
      expect(history.first.speed, 35.0);
    });

    test('3. Event Timestamp preservation during late packet ingest', () async {
      final telemetryDS = TelemetryLocalDataSourceImpl(dbClient: client);

      final now = DateTime.now();
      final lateTimestamp = now.subtract(const Duration(hours: 2));

      final latePacket = TelemetryPacketModel(
        packetId: 'p_late',
        vehicleId: 'v1',
        eventTimestamp: lateTimestamp,
        ingestTimestamp: now,
        latitude: 12.9716,
        longitude: 77.5946,
        speed: 0.0,
        batteryLevel: 75.0,
        batteryTemp: 28.0,
        odometerKm: 50.0,
        ignition: false,
      );

      await telemetryDS.insertTelemetryBatch([latePacket]);

      final history = await telemetryDS.getVehicleTelemetryHistory('v1');
      expect(history.length, 1);
      expect(
        history.first.eventTimestamp.millisecondsSinceEpoch,
        lateTimestamp.millisecondsSinceEpoch,
      );
    });

    test('4. Fleet SQL Status Calculation & SQL Filter Counts', () async {
      final telemetryDS = TelemetryLocalDataSourceImpl(dbClient: client);
      final vehicleDS = VehicleLocalDataSourceImpl(dbClient: client);

      final now = DateTime.now();

      // Vehicle 1: Moving (speed > 0, recent)
      final pMoving = TelemetryPacketModel(
        packetId: 'p_mov',
        vehicleId: 'v_moving',
        eventTimestamp: now.subtract(const Duration(minutes: 1)),
        ingestTimestamp: now,
        latitude: 12.9,
        longitude: 77.5,
        speed: 40.0,
        batteryLevel: 90.0,
        batteryTemp: 30.0,
        odometerKm: 100.0,
        ignition: true,
      );

      // Vehicle 2: Idle (speed == 0, ignition ON, recent)
      final pIdle = TelemetryPacketModel(
        packetId: 'p_idl',
        vehicleId: 'v_idle',
        eventTimestamp: now.subtract(const Duration(minutes: 2)),
        ingestTimestamp: now,
        latitude: 12.9,
        longitude: 77.5,
        speed: 0.0,
        batteryLevel: 15.0, // Low battery < 20%
        batteryTemp: 30.0,
        odometerKm: 100.0,
        ignition: true,
      );

      // Vehicle 3: Stopped (speed == 0, ignition OFF, recent)
      final pStopped = TelemetryPacketModel(
        packetId: 'p_stp',
        vehicleId: 'v_stopped',
        eventTimestamp: now.subtract(const Duration(minutes: 3)),
        ingestTimestamp: now,
        latitude: 12.9,
        longitude: 77.5,
        speed: 0.0,
        batteryLevel: 50.0,
        batteryTemp: 30.0,
        odometerKm: 100.0,
        ignition: false,
      );

      // Vehicle 4: Offline (ping > 10 mins ago)
      final pOffline = TelemetryPacketModel(
        packetId: 'p_off',
        vehicleId: 'v_offline',
        eventTimestamp: now.subtract(const Duration(minutes: 15)),
        ingestTimestamp: now,
        latitude: 12.9,
        longitude: 77.5,
        speed: 50.0,
        batteryLevel: 40.0,
        batteryTemp: 30.0,
        odometerKm: 100.0,
        ignition: true,
      );

      await telemetryDS.insertTelemetryBatch([pMoving, pIdle, pStopped, pOffline]);

      final summary = await vehicleDS.getFleetSummary();
      expect(summary.totalVehicles, 4);
      expect(summary.movingCount, 1);
      expect(summary.idleCount, 1);
      expect(summary.stoppedCount, 1);
      expect(summary.offlineCount, 1);
      expect(summary.lowBatteryAlertCount, 1);

      // Test filtered vehicle listing
      final movingVehicles = await vehicleDS.getVehicles(statusFilter: VehicleStatus.moving);
      expect(movingVehicles.length, 1);
      expect(movingVehicles.first.id, 'v_moving');

      final offlineVehicles = await vehicleDS.getVehicles(statusFilter: VehicleStatus.offline);
      expect(offlineVehicles.length, 1);
      expect(offlineVehicles.first.id, 'v_offline');
    });

    test('5. SOC History query returning time-ordered readings', () async {
      final telemetryDS = TelemetryLocalDataSourceImpl(dbClient: client);

      final now = DateTime.now();
      final p1 = TelemetryPacketModel(
        packetId: 'soc_1',
        vehicleId: 'v_soc',
        eventTimestamp: now.subtract(const Duration(minutes: 30)),
        ingestTimestamp: now,
        latitude: 12.9,
        longitude: 77.5,
        speed: 20.0,
        batteryLevel: 80.0,
        batteryTemp: 25.0,
        odometerKm: 10.0,
        ignition: true,
      );

      final p2 = TelemetryPacketModel(
        packetId: 'soc_2',
        vehicleId: 'v_soc',
        eventTimestamp: now.subtract(const Duration(minutes: 10)),
        ingestTimestamp: now,
        latitude: 12.9,
        longitude: 77.5,
        speed: 25.0,
        batteryLevel: 75.0,
        batteryTemp: 26.0,
        odometerKm: 15.0,
        ignition: true,
      );

      await telemetryDS.insertTelemetryBatch([p1, p2]);

      final socHistory = await telemetryDS.getSocHistory('v_soc', limit: 10);
      expect(socHistory.length, 2);
      expect(socHistory[0].batteryLevel, 75.0); // Most recent first
      expect(socHistory[1].batteryLevel, 80.0);
    });

    test('6. Persistence across app termination and restart', () async {
      final telemetryDS = TelemetryLocalDataSourceImpl(dbClient: client);
      final now = DateTime.now();
      final packet = TelemetryPacketModel(
        packetId: 'persist_p1',
        vehicleId: 'v_persist',
        eventTimestamp: now,
        ingestTimestamp: now,
        latitude: 12.9716,
        longitude: 77.5946,
        speed: 15.0,
        batteryLevel: 95.0,
        batteryTemp: 27.0,
        odometerKm: 200.0,
        ignition: true,
      );

      await telemetryDS.insertTelemetryBatch([packet]);

      // Close database (simulating app termination)
      await client.close();

      // Re-open database (simulating app relaunch)
      final reopenedClient = DuckDbClient();
      await reopenedClient.init(tempDbPath);

      final vehicleDS = VehicleLocalDataSourceImpl(dbClient: reopenedClient);
      final vehicle = await vehicleDS.getVehicleById('v_persist');

      expect(vehicle, isNotNull);
      expect(vehicle!.id, 'v_persist');
      expect(vehicle.lastSoc, 95.0);

      await reopenedClient.close();
    });
  });
}
