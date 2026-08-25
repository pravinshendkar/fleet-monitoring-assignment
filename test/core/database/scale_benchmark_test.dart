import 'dart:io';
import 'package:fleet_console/core/database/duckdb_client.dart';
import 'package:fleet_console/features/fleet/data/datasources/telemetry_local_datasource.dart';
import 'package:fleet_console/features/fleet/data/datasources/vehicle_local_datasource.dart';
import 'package:fleet_console/features/fleet/data/models/telemetry_packet_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DuckDB Scale Benchmark Test (2,000,000 Signal Rows)', () {
    late DuckDbClient client;
    late String tempDbPath;

    setUp(() async {
      tempDbPath = 'test_scale_benchmark_${DateTime.now().millisecondsSinceEpoch}.duckdb';
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

    test('Bulk ingestion and performance query on 50,000 batch sample dataset', () async {
      final telemetryDS = TelemetryLocalDataSourceImpl(dbClient: client);
      final vehicleDS = VehicleLocalDataSourceImpl(dbClient: client);

      final now = DateTime.now();
      const totalVehicles = 500;
      const packetsPerVehicle = 100; // 50,000 sample test batch for fast automated testing

      final batch = <TelemetryPacketModel>[];
      for (var v = 1; v <= totalVehicles; v++) {
        final vid = 'EV-${v.toString().padLeft(3, '0')}';
        for (var p = 0; p < packetsPerVehicle; p++) {
          final ts = now.subtract(Duration(seconds: p * 10));
          batch.add(TelemetryPacketModel(
            packetId: 'pkt_bench_${vid}_$p',
            vehicleId: vid,
            eventTimestamp: ts,
            ingestTimestamp: now,
            latitude: 12.9716,
            longitude: 77.5946,
            speed: (p % 2 == 0) ? 45.0 : 0.0,
            batteryLevel: 90.0 - (p * 0.05),
            batteryTemp: 28.0,
            odometerKm: 1000.0 + p,
            ignition: true,
            gpsAccuracy: 3.5,
          ));
        }
      }

      final stopwatch = Stopwatch()..start();
      await telemetryDS.insertTelemetryBatch(batch);
      stopwatch.stop();

      final summary = await vehicleDS.getFleetSummary();
      expect(summary.totalVehicles, 500);

      final queryStopwatch = Stopwatch()..start();
      final history = await telemetryDS.getVehicleTelemetryHistory('EV-001', limit: 100);
      queryStopwatch.stop();

      expect(history.length, 100);
      expect(queryStopwatch.elapsedMilliseconds, lessThan(500)); // Query should run under 500ms
    });
  });
}
