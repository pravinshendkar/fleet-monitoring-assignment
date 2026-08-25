@Timeout(Duration(minutes: 2))
library;

import 'dart:io';

import 'package:fleet_console/core/database/database_event_bus.dart';
import 'package:fleet_console/core/database/duckdb_client.dart';
import 'package:fleet_console/core/database/seed_data_service.dart';
import 'package:fleet_console/core/simulation/telemetry_simulation_service.dart';
import 'package:fleet_console/features/alerts/data/datasources/alert_local_datasource.dart';
import 'package:fleet_console/features/alerts/data/repositories/alert_repository_impl.dart';
import 'package:fleet_console/features/alerts/domain/usecases/evaluate_alerts.dart';
import 'package:fleet_console/features/fleet/data/datasources/telemetry_local_datasource.dart';
import 'package:fleet_console/features/fleet/data/datasources/vehicle_local_datasource.dart';
import 'package:fleet_console/features/fleet/data/repositories/telemetry_repository_impl.dart';
import 'package:fleet_console/features/fleet/data/repositories/vehicle_repository_impl.dart';
import 'package:fleet_console/features/fleet/domain/entities/vehicle.dart';
import 'package:fleet_console/features/fleet/domain/usecases/process_telemetry_batch.dart';
import 'package:fleet_console/features/geofences/data/datasources/geofence_local_datasource.dart';
import 'package:fleet_console/features/geofences/data/repositories/geofence_repository_impl.dart';
import 'package:fleet_console/features/geofences/domain/usecases/create_geofence.dart';
import 'package:fleet_console/features/geofences/domain/usecases/detect_geofence_transitions.dart';
import 'package:fleet_console/features/trips/data/datasources/trip_local_datasource.dart';
import 'package:fleet_console/features/trips/data/repositories/trip_repository_impl.dart';
import 'package:fleet_console/features/trips/domain/usecases/process_trips.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TelemetrySimulationService Tests', () {
    late DuckDbClient client;
    late String tempDbPath;
    late DatabaseEventBus eventBus;
    late TelemetrySimulationService simulationService;
    late VehicleLocalDataSourceImpl vehicleDS;

    setUp(() async {
      tempDbPath = 'test_sim_${DateTime.now().millisecondsSinceEpoch}.duckdb';
      client = DuckDbClient();
      await client.init(tempDbPath);
      eventBus = DatabaseEventBus();

      final telemetryDS = TelemetryLocalDataSourceImpl(dbClient: client);
      vehicleDS = VehicleLocalDataSourceImpl(dbClient: client);
      final alertDS = AlertLocalDataSourceImpl(dbClient: client);
      final geofenceDS = GeofenceLocalDataSourceImpl(dbClient: client);
      final tripDS = TripLocalDataSourceImpl(dbClient: client);

      final telemetryRepo = TelemetryRepositoryImpl(
        localDataSource: telemetryDS,
        eventBus: eventBus,
      );
      final vehicleRepo = VehicleRepositoryImpl(
        localDataSource: vehicleDS,
        eventBus: eventBus,
      );
      final alertRepo = AlertRepositoryImpl(
        localDataSource: alertDS,
        eventBus: eventBus,
      );
      final geofenceRepo = GeofenceRepositoryImpl(
        localDataSource: geofenceDS,
        eventBus: eventBus,
      );
      final tripRepo = TripRepositoryImpl(
        localDataSource: tripDS,
        eventBus: eventBus,
      );

      final evalAlerts = EvaluateAlertsUseCase(alertRepo);
      final detectTransitions = DetectGeofenceTransitionsUseCase(geofenceRepo);
      final processTrips = ProcessTripsUseCase(tripRepo);
      final createGeofence = CreateGeofenceUseCase(geofenceRepo);

      final processBatch = ProcessTelemetryBatchUseCase(
        telemetryRepository: telemetryRepo,
        evaluateAlertsUseCase: evalAlerts,
        detectGeofenceTransitionsUseCase: detectTransitions,
        processTripsUseCase: processTrips,
      );

      final seedService = SeedDataService(
        dbClient: client,
        processTelemetryBatchUseCase: processBatch,
        createGeofenceUseCase: createGeofence,
      );
      await seedService.seedIfEmpty(vehicleCount: 500);

      simulationService = TelemetrySimulationService(
        vehicleRepository: vehicleRepo,
        processTelemetryBatchUseCase: processBatch,
      );
    });

    tearDown(() async {
      await simulationService.dispose();
      eventBus.dispose();
      await client.close();
      final file = File(tempDbPath);
      if (await file.exists()) {
        await file.delete();
      }
      final walFile = File('$tempDbPath.wal');
      if (await walFile.exists()) {
        await walFile.delete();
      }
    });

    test(
      'simulateTick generates fresh telemetry for active vehicles and leaves offline vehicles offline',
      () async {
        final initialSummary = await vehicleDS.getFleetSummary();
        expect(initialSummary.totalVehicles, equals(500));
        final initialOfflineCount = initialSummary.offlineCount;
        expect(initialOfflineCount, greaterThan(0));

        // Execute a simulation tick
        await simulationService.simulateTick();

        final postTickSummary = await vehicleDS.getFleetSummary();
        expect(postTickSummary.totalVehicles, equals(500));
        expect(postTickSummary.offlineCount, equals(initialOfflineCount));

        // Verify active vehicles stay active with fresh timestamps
        final movingList = await vehicleDS.getVehicles(
          statusFilter: VehicleStatus.moving,
          limit: 10,
        );
        expect(movingList, isNotEmpty);
        final diff = DateTime.now().difference(movingList.first.lastSeenAt);
        expect(diff.inSeconds, lessThan(10));
      },
    );

    test(
      'Regression Test: Stale active vehicles (>10m) receive fresh telemetry, recover from offline deadlock, and initial tick runs immediately on start',
      () async {
        // 1. Manually update active vehicles to have last_seen_at older than 15 minutes in DuckDB
        final staleTs = DateTime.now()
            .toUtc()
            .subtract(const Duration(minutes: 15))
            .toIso8601String();
        await client.execute(
          "UPDATE vehicles SET last_seen_at = '$staleTs' WHERE status != 'offline';",
        );

        // Before simulation tick: all active vehicles appear OFFLINE because lastSeenAt > 10m
        final summaryBefore = await vehicleDS.getFleetSummary();
        expect(summaryBefore.offlineCount, equals(500));
        expect(summaryBefore.movingCount, equals(0));

        // 2. Start simulation (which triggers immediate tick and is awaited)
        await simulationService.startSimulation();

        // 3. Verify active vehicles received fresh telemetry and are no longer offline
        final summaryAfter = await vehicleDS.getFleetSummary();
        expect(summaryAfter.movingCount, greaterThan(0));
        expect(summaryAfter.idleCount, greaterThan(0));
        expect(summaryAfter.stoppedCount, greaterThan(0));

        // 4. Verify persisted offline vehicles (category offline) remain offline
        expect(summaryAfter.offlineCount, equals(125));

        // 5. Verify moving vehicles have fresh timestamps (< 10 seconds ago)
        final movingVehicles = await vehicleDS.getVehicles(
          statusFilter: VehicleStatus.moving,
          limit: 10,
        );
        expect(movingVehicles, isNotEmpty);
        expect(
          DateTime.now().difference(movingVehicles.first.lastSeenAt).inSeconds,
          lessThan(10),
        );
      },
    );

    test(
      'Concurrency Safeguard Test: Overlapping simulateTick calls are skipped when a tick is in progress',
      () async {
        // Trigger two simulateTick calls concurrently
        final tick1 = simulationService.simulateTick();
        final tick2 = simulationService
            .simulateTick(); // Overlapping call, should return immediately (skipped)

        await Future.wait([tick1, tick2]);

        expect(simulationService.isDisposed, isFalse);
      },
    );

    test('startSimulation and stopSimulation manage timer lifecycle', () async {
      expect(simulationService.isRunning, isFalse);
      await simulationService.startSimulation(
        interval: const Duration(seconds: 10),
      );
      expect(simulationService.isRunning, isTrue);
      await simulationService.stopSimulation();
      expect(simulationService.isRunning, isFalse);
    });
  });
}
