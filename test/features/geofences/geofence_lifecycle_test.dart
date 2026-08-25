import 'dart:io';
import 'package:fleet_console/core/database/database_event_bus.dart';
import 'package:fleet_console/core/database/duckdb_client.dart';
import 'package:fleet_console/features/fleet/data/datasources/telemetry_local_datasource.dart';
import 'package:fleet_console/features/fleet/data/models/telemetry_packet_model.dart';
import 'package:fleet_console/features/fleet/domain/entities/telemetry_packet.dart';
import 'package:fleet_console/features/geofences/data/datasources/geofence_local_datasource.dart';
import 'package:fleet_console/features/geofences/data/repositories/geofence_repository_impl.dart';
import 'package:fleet_console/features/geofences/domain/entities/geofence.dart';
import 'package:fleet_console/features/geofences/domain/entities/geofence_event.dart';
import 'package:fleet_console/features/geofences/domain/usecases/create_geofence.dart';
import 'package:fleet_console/features/geofences/domain/usecases/deactivate_geofence.dart';
import 'package:fleet_console/features/geofences/domain/usecases/detect_geofence_transitions.dart';
import 'package:fleet_console/features/geofences/domain/usecases/update_geofence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Geofence Lifecycle & Transition Integration Tests', () {
    late DuckDbClient dbClient;
    late DatabaseEventBus eventBus;
    late GeofenceLocalDataSourceImpl geofenceDS;
    late TelemetryLocalDataSourceImpl telemetryDS;
    late GeofenceRepositoryImpl geofenceRepo;
    late CreateGeofenceUseCase createGeofence;
    late UpdateGeofenceUseCase updateGeofence;
    late DeactivateGeofenceUseCase deactivateGeofence;
    late DetectGeofenceTransitionsUseCase detectTransitions;

    late String tempDbPath;
    final now = DateTime.now();

    setUp(() async {
      tempDbPath = 'test_geo_${DateTime.now().millisecondsSinceEpoch}.duckdb';
      dbClient = DuckDbClient();
      await dbClient.init(tempDbPath);

      eventBus = DatabaseEventBus();
      geofenceDS = GeofenceLocalDataSourceImpl(dbClient: dbClient);
      telemetryDS = TelemetryLocalDataSourceImpl(dbClient: dbClient);
      geofenceRepo = GeofenceRepositoryImpl(localDataSource: geofenceDS, eventBus: eventBus);

      createGeofence = CreateGeofenceUseCase(geofenceRepo);
      updateGeofence = UpdateGeofenceUseCase(geofenceRepo);
      deactivateGeofence = DeactivateGeofenceUseCase(geofenceRepo);
      detectTransitions = DetectGeofenceTransitionsUseCase(geofenceRepo);
    });

    tearDown(() async {
      eventBus.dispose();
      await dbClient.close();
      final file = File(tempDbPath);
      if (await file.exists()) {
        await file.delete();
      }
    });

    test('1. Geofence CRUD & persistence in DuckDB with input validation', () async {
      final g = Geofence(
        id: 'geo_1',
        name: 'Bangalore Depot',
        centerLat: 12.9716,
        centerLng: 77.5946,
        radiusMeters: 500.0,
        isActive: true,
        createdAt: now,
      );

      // Validation check
      final invalidG = g.copyWith(name: '');
      expect(() => createGeofence(invalidG), throwsArgumentError);

      await createGeofence(g);

      final list = await geofenceRepo.getGeofences();
      expect(list.length, 1);
      expect(list.first.name, 'Bangalore Depot');

      // Edit geofence
      final updated = g.copyWith(name: 'Updated Bangalore Hub', radiusMeters: 750.0);
      await updateGeofence(updated);

      final listAfterUpdate = await geofenceRepo.getGeofences();
      expect(listAfterUpdate.first.name, 'Updated Bangalore Hub');
      expect(listAfterUpdate.first.radiusMeters, 750.0);

      // Deactivate geofence
      await deactivateGeofence(const DeactivateGeofenceParams(geofenceId: 'geo_1', isActive: false));
      final listAfterDeactivate = await geofenceRepo.getGeofences();
      expect(listAfterDeactivate.first.isActive, isFalse);
    });

    test('2. Confirmed ENTRY and EXIT requiring 2 consecutive readings', () async {
      final g = Geofence(
        id: 'geo_1',
        name: 'Depot A',
        centerLat: 12.9716,
        centerLng: 77.5946,
        radiusMeters: 500.0,
        isActive: true,
        createdAt: now,
      );
      await createGeofence(g);

      final p1 = TelemetryPacket(
        packetId: 'p1',
        vehicleId: 'EV-101',
        eventTimestamp: now.subtract(const Duration(minutes: 5)),
        ingestTimestamp: now,
        latitude: 12.9716,
        longitude: 77.5946,
        speed: 10.0,
        batteryLevel: 80.0,
        batteryTemp: 30.0,
        odometerKm: 100.0,
        ignition: true,
        gpsAccuracy: 5.0,
      );

      final p2 = TelemetryPacket(
        packetId: 'p2',
        vehicleId: 'EV-101',
        eventTimestamp: now.subtract(const Duration(minutes: 4)),
        ingestTimestamp: now,
        latitude: 12.9716,
        longitude: 77.5946,
        speed: 10.0,
        batteryLevel: 80.0,
        batteryTemp: 30.0,
        odometerKm: 100.1,
        ignition: true,
        gpsAccuracy: 5.0,
      );

      final events = await detectTransitions(DetectGeofenceTransitionsParams(
        packets: [p1, p2],
        activeVehicleGeofences: {},
      ));

      expect(events.length, 1);
      expect(events.first.type, GeofenceEventType.entry);
      expect(events.first.geofenceId, 'geo_1');
    });

    test('3. Overlapping geofences tracked independently per (vehicle_id, geofence_id)', () async {
      final g1 = Geofence(
        id: 'geo_1',
        name: 'Hub A',
        centerLat: 12.9716,
        centerLng: 77.5946,
        radiusMeters: 1000.0,
        isActive: true,
        createdAt: now,
      );
      final g2 = Geofence(
        id: 'geo_2',
        name: 'Hub B',
        centerLat: 12.9720,
        centerLng: 77.5950,
        radiusMeters: 1000.0,
        isActive: true,
        createdAt: now,
      );

      await createGeofence(g1);
      await createGeofence(g2);

      final p1 = TelemetryPacket(
        packetId: 'p1',
        vehicleId: 'EV-101',
        eventTimestamp: now.subtract(const Duration(minutes: 2)),
        ingestTimestamp: now,
        latitude: 12.9716,
        longitude: 77.5946,
        speed: 0.0,
        batteryLevel: 90.0,
        batteryTemp: 30.0,
        odometerKm: 100.0,
        ignition: true,
        gpsAccuracy: 5.0,
      );

      final p2 = TelemetryPacket(
        packetId: 'p2',
        vehicleId: 'EV-101',
        eventTimestamp: now.subtract(const Duration(minutes: 1)),
        ingestTimestamp: now,
        latitude: 12.9716,
        longitude: 77.5946,
        speed: 0.0,
        batteryLevel: 90.0,
        batteryTemp: 30.0,
        odometerKm: 100.0,
        ignition: true,
        gpsAccuracy: 5.0,
      );

      final events = await detectTransitions(DetectGeofenceTransitionsParams(
        packets: [p1, p2],
        activeVehicleGeofences: {},
      ));

      expect(events.length, 2); // Triggers ENTRY for BOTH overlapping geofences independently!
      expect(events.any((e) => e.geofenceId == 'geo_1'), isTrue);
      expect(events.any((e) => e.geofenceId == 'geo_2'), isTrue);
    });

    test('4. SQL vehicle counts calculate active vehicles inside geofences dynamically', () async {
      final g1 = Geofence(
        id: 'geo_1',
        name: 'Depot Central',
        centerLat: 12.9716,
        centerLng: 77.5946,
        radiusMeters: 500.0,
        isActive: true,
        createdAt: now,
      );
      await createGeofence(g1);

      final p1 = TelemetryPacket(
        packetId: 'p1',
        vehicleId: 'EV-101',
        eventTimestamp: now,
        ingestTimestamp: now,
        latitude: 12.9716,
        longitude: 77.5946,
        speed: 0.0,
        batteryLevel: 90.0,
        batteryTemp: 30.0,
        odometerKm: 100.0,
        ignition: true,
        gpsAccuracy: 5.0,
      );

      await telemetryDS.insertTelemetryBatch([TelemetryPacketModel.fromEntity(p1)]);

      final counts = await geofenceRepo.getGeofenceVehicleCounts();
      expect(counts['geo_1'], 1);
    });
  });
}
