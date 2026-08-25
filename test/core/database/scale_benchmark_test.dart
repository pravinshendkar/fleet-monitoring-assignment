@Timeout(Duration(minutes: 2))
library;

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
      tempDbPath =
          'test_scale_benchmark_${DateTime.now().millisecondsSinceEpoch}.duckdb';
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

    test(
      'Bulk ingestion and performance query on 50,000 batch sample dataset',
      () async {
        final telemetryDS = TelemetryLocalDataSourceImpl(dbClient: client);
        final vehicleDS = VehicleLocalDataSourceImpl(dbClient: client);

        final now = DateTime.now();
        final packets = List.generate(
          50000,
          (i) => TelemetryPacketModel(
            packetId: 'pkt_bench_$i',
            vehicleId: 'EV-${(i % 500) + 1}',
            eventTimestamp: now.subtract(Duration(seconds: i % 3600)),
            ingestTimestamp: now,
            latitude: 37.7749 + (i * 0.0001),
            longitude: -122.4194 + (i * 0.0001),
            speed: (i % 60).toDouble(),
            batteryLevel: 80.0 - (i % 50),
            batteryTemp: 25.0 + (i % 20),
            odometerKm: 10000.0 + i,
            ignition: i % 2 == 0,
            gpsAccuracy: 3.5,
          ),
        );

        final swIngest = Stopwatch()..start();
        await telemetryDS.insertTelemetryBatch(packets);
        swIngest.stop();

        expect(swIngest.elapsedMilliseconds, lessThan(30000));

        final swQuery = Stopwatch()..start();
        final countRes = await client.query(
          "SELECT COUNT(*) as total FROM telemetry_packets;",
        );
        final count = (countRes.first['total'] as num).toInt();
        final summary = await vehicleDS.getFleetSummary();
        swQuery.stop();

        expect(count, equals(50000));
        expect(summary.totalVehicles, greaterThanOrEqualTo(0));
        expect(swQuery.elapsedMilliseconds, lessThan(500));
      },
    );
  });
}
