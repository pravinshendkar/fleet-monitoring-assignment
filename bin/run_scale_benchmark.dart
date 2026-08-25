import 'dart:io';
import 'package:fleet_console/core/database/duckdb_client.dart';
import 'package:fleet_console/features/fleet/data/datasources/vehicle_local_datasource.dart';
import 'package:fleet_console/features/fleet/domain/entities/vehicle.dart';
import 'package:flutter/foundation.dart';

void main() async {
  debugPrint('====================================================');
  debugPrint(' Bytebeam Fleet Console - 2,000,000 Row Scale Benchmark');
  debugPrint('====================================================');

  final tempDbPath =
      'scale_benchmark_2m_${DateTime.now().millisecondsSinceEpoch}.duckdb';
  final dbFile = File(tempDbPath);

  // 1. Cold Start Measurement (App Process / DB Init / Fleet Load)
  debugPrint('\n[1/4] Measuring Cold-Start Duration...');
  final coldStartStopwatch = Stopwatch()..start();

  final client = DuckDbClient();
  await client.init(tempDbPath);

  final vehicleDS = VehicleLocalDataSourceImpl(dbClient: client);

  // Initial fleet query on empty DB
  await vehicleDS.getFleetSummary();
  await vehicleDS.getVehicles(limit: 50, offset: 0);

  coldStartStopwatch.stop();
  final coldStartMs = coldStartStopwatch.elapsedMilliseconds;
  debugPrint('  -> Cold Start Duration: $coldStartMs ms');

  // 2. High-Performance Bulk Dataset Generation (500 Vehicles, 2,000,000 Telemetry Rows)
  debugPrint(
    '\n[2/4] Populating 500 Vehicles & 2,000,000 Signal Rows in DuckDB...',
  );
  final ingestStopwatch = Stopwatch()..start();

  // Populate 500 vehicles
  const populateVehiclesSql = '''
    INSERT INTO vehicles (
      vehicle_id, name, status, last_latitude, last_longitude, last_soc, last_seen_at, ignition
    )
    SELECT
      'EV-' || LPAD(v::VARCHAR, 3, '0') as vehicle_id,
      'EV-' || LPAD(v::VARCHAR, 3, '0') as name,
      CASE 
        WHEN (v <= 250) THEN 'MOVING'
        WHEN (v <= 400) THEN 'IDLE'
        ELSE 'STOPPED'
      END as status,
      12.9716 + (v * 0.0001) as last_latitude,
      77.5946 + (v * 0.0001) as last_longitude,
      GREATEST(10.0, 95.0 - (v * 0.1)) as last_soc,
      now() - (v * INTERVAL '10 SECOND') as last_seen_at,
      CASE WHEN (v <= 400) THEN true ELSE false END as ignition
    FROM range(1, 501) t(v);
  ''';
  await client.execute(populateVehiclesSql);

  // Populate 2,000,000 telemetry packets in DuckDB
  const populateTelemetrySql = '''
    INSERT INTO telemetry_packets (
      packet_id, vehicle_id, event_timestamp, ingest_timestamp, latitude, longitude,
      speed, battery_level, battery_temp, odometer_km, ignition, gps_accuracy
    )
    SELECT
      'pkt_bench_' || i as packet_id,
      'EV-' || LPAD((i % 500 + 1)::VARCHAR, 3, '0') as vehicle_id,
      now() - (i * INTERVAL '10 SECOND') as event_timestamp,
      now() as ingest_timestamp,
      12.9716 + ((i % 500) * 0.0001) as latitude,
      77.5946 + ((i % 500) * 0.0001) as longitude,
      CASE WHEN (i % 2 = 0) THEN 45.0 ELSE 0.0 END as speed,
      GREATEST(5.0, 100.0 - ((i % 4000) * 0.02)) as battery_level,
      28.0 + (i % 10) as battery_temp,
      1000.0 + (i * 0.01) as odometer_km,
      true as ignition,
      3.5 as gps_accuracy
    FROM range(1, 2000001) t(i);
  ''';
  await client.execute(populateTelemetrySql);

  ingestStopwatch.stop();

  // Verify counts
  final vehicleCountMaps = await client.query(
    'SELECT COUNT(*) as count FROM vehicles;',
  );
  final telemetryCountMaps = await client.query(
    'SELECT COUNT(*) as count FROM telemetry_packets;',
  );
  final totalVehicles = vehicleCountMaps.first['count'];
  final totalTelemetry = telemetryCountMaps.first['count'];

  debugPrint(
    '  -> Ingested $totalVehicles vehicles & $totalTelemetry signal rows in ${ingestStopwatch.elapsedMilliseconds} ms.',
  );

  // 3. Fleet Query Latency Benchmark (p50 & p95 over 50 iterations)
  debugPrint('\n[3/4] Benchmarking Warm Fleet-List Queries (50 Iterations)...');

  // Warm-up query
  await vehicleDS.getFleetSummary();
  await vehicleDS.getVehicles(limit: 50, offset: 0);

  final latencies = <int>[];
  const iterations = 50;

  for (var i = 0; i < iterations; i++) {
    final sw = Stopwatch()..start();
    // Execute actual application fleet pipeline: SQL status counts + paginated list query
    await vehicleDS.getFleetSummary();
    await vehicleDS.getVehicles(
      statusFilter: i % 2 == 0 ? VehicleStatus.moving : null,
      searchQuery: i % 3 == 0 ? 'EV-0' : null,
      limit: 50,
      offset: 0,
    );
    sw.stop();
    latencies.add(sw.elapsedMilliseconds);
  }

  latencies.sort();
  final p50 = latencies[(iterations * 0.50).floor()];
  final p95 = latencies[(iterations * 0.95).floor()];

  debugPrint('  -> Iterations: $iterations');
  debugPrint('  -> Fleet Query Latency p50: $p50 ms');
  debugPrint('  -> Fleet Query Latency p95: $p95 ms');

  // 4. Memory Measurement
  debugPrint('\n[4/4] Process Memory Measurement...');
  final rssMb = (ProcessInfo.currentRss / (1024 * 1024)).toStringAsFixed(1);
  debugPrint('  -> Memory RSS at rest: $rssMb MB');

  // Cleanup
  await client.close();
  if (await dbFile.exists()) {
    await dbFile.delete();
  }

  debugPrint('\n====================================================');
  debugPrint(' SUMMARY OF EMPIRICAL MEASUREMENTS');
  debugPrint('====================================================');
  debugPrint(
    ' Dataset Size:      $totalVehicles Vehicles, $totalTelemetry Telemetry Packets',
  );
  debugPrint(' Cold-Start:        $coldStartMs ms');
  debugPrint(' Fleet Query p50:   $p50 ms');
  debugPrint(' Fleet Query p95:   $p95 ms');
  debugPrint(' Memory (RSS):      $rssMb MB');
  debugPrint('====================================================');
}
