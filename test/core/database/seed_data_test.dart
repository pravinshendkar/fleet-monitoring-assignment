import 'dart:io';
import 'package:fleet_console/core/database/database_event_bus.dart';
import 'package:fleet_console/core/database/duckdb_client.dart';
import 'package:fleet_console/core/database/seed_data_generator.dart';
import 'package:fleet_console/core/database/seed_data_service.dart';
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
import 'package:fleet_console/features/trips/domain/entities/trip.dart';
import 'package:fleet_console/features/trips/domain/usecases/process_trips.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SeedData Generator & Service Tests', () {
    late DuckDbClient client;
    late String tempDbPath;
    late DatabaseEventBus eventBus;

    setUp(() async {
      tempDbPath = 'test_seed_${DateTime.now().millisecondsSinceEpoch}.duckdb';
      client = DuckDbClient();
      await client.init(tempDbPath);
      eventBus = DatabaseEventBus();
    });

    tearDown(() async {
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
      '1. SeedDataGenerator produces 500 unique vehicles with demo vehicle transition history',
      () {
        final packets = SeedDataGenerator.generateSeedTelemetry(
          vehicleCount: 500,
        );

        final uniqueVehicles = packets.map((p) => p.vehicleId).toSet();
        expect(uniqueVehicles.length, 500);

        // Demo vehicles EV-004, EV-008, EV-012, EV-016 must produce multiple chronological packets
        final ev004Packets = packets
            .where((p) => p.vehicleId == 'EV-004')
            .toList();
        expect(ev004Packets.length, equals(6));

        for (var i = 0; i < ev004Packets.length - 1; i++) {
          expect(
            ev004Packets[i].eventTimestamp.isBefore(
              ev004Packets[i + 1].eventTimestamp,
            ),
            isTrue,
            reason:
                'Demo vehicle telemetry timestamps must be strictly chronological',
          );
        }

        final lowBatteryCount = packets
              .where((p) => p.batteryLevel != null && p.batteryLevel! <= 20.0)
            .length;
        expect(lowBatteryCount, greaterThan(0));

        final overheatingCount = packets
              .where((p) => p.batteryTemp != null && p.batteryTemp! > 45.0)
            .length;
        expect(overheatingCount, greaterThan(0));
      },
    );

    test(
      '2. SeedDataService seeds DuckDB deterministically and naturally generates completed trips',
      () async {
        final telemetryDS = TelemetryLocalDataSourceImpl(dbClient: client);
        final vehicleDS = VehicleLocalDataSourceImpl(dbClient: client);
        final alertDS = AlertLocalDataSourceImpl(dbClient: client);
        final geofenceDS = GeofenceLocalDataSourceImpl(dbClient: client);
        final tripDS = TripLocalDataSourceImpl(dbClient: client);

        // Repositories
        final telemetryRepo = TelemetryRepositoryImpl(
          localDataSource: telemetryDS,
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
        final vehicleRepo = VehicleRepositoryImpl(
          localDataSource: vehicleDS,
          eventBus: eventBus,
        );

        // Use cases
        final evalAlerts = EvaluateAlertsUseCase(alertRepo, vehicleRepo);
        final detectTransitions = DetectGeofenceTransitionsUseCase(
          geofenceRepo,
          vehicleRepo,
        );
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

        final summary = await vehicleDS.getFleetSummary();
        expect(summary.totalVehicles, 500);
        expect(
          summary.movingCount +
              summary.idleCount +
              summary.stoppedCount +
              summary.offlineCount,
          equals(500),
        );
        expect(summary.movingCount, greaterThan(0));
        expect(summary.idleCount, greaterThan(0));
        expect(summary.stoppedCount, greaterThan(0));
        expect(summary.offlineCount, greaterThan(0));

        // Verify status filter counts match queried vehicle list count exactly
        final movingList = await vehicleDS.getVehicles(
          statusFilter: VehicleStatus.moving,
          limit: 500,
        );
        expect(movingList.length, equals(summary.movingCount));
        expect(
          movingList.every((v) => v.status == VehicleStatus.moving),
          isTrue,
        );

        final geofences = await geofenceDS.getGeofences();
        expect(geofences.length, 3);

        // Verify seeded demo trips were naturally created and completed via production pipeline
        final seededTrips = await tripDS.getAllTrips();
        expect(seededTrips.length, greaterThanOrEqualTo(4));
        for (final trip in seededTrips) {
          expect(trip.vehicleId, isNotEmpty);
          expect(trip.startGeofenceId, equals('gf_central_depot'));
          expect(trip.endGeofenceId, equals('gf_central_depot'));
          expect(trip.status, equals(TripStatus.completed));
          expect(trip.distanceKm, greaterThan(0.0));
          expect(trip.maxSpeedKmh, greaterThan(0.0));
          expect(trip.averageSocUsed, greaterThanOrEqualTo(0.0));
        }

        // Re-seeding when non-empty must be idempotent and preserve exact trip count
        await seedService.seedIfEmpty(vehicleCount: 500);
        final postReseedTrips = await tripDS.getAllTrips();
        expect(postReseedTrips.length, equals(seededTrips.length));
      },
    );
  });
}
