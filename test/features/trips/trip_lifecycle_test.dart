import 'dart:io';
import 'package:fleet_console/core/database/database_event_bus.dart';
import 'package:fleet_console/core/database/duckdb_client.dart';
import 'package:fleet_console/features/fleet/data/datasources/telemetry_local_datasource.dart';
import 'package:fleet_console/features/fleet/data/models/telemetry_packet_model.dart';
import 'package:fleet_console/features/fleet/domain/entities/telemetry_packet.dart';
import 'package:fleet_console/features/geofences/domain/entities/geofence_event.dart';
import 'package:fleet_console/features/trips/data/datasources/trip_local_datasource.dart';
import 'package:fleet_console/features/trips/data/repositories/trip_repository_impl.dart';
import 'package:fleet_console/features/trips/domain/entities/trip.dart';
import 'package:fleet_console/features/trips/domain/usecases/process_trips.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Trip Lifecycle Integration Tests', () {
    late DuckDbClient dbClient;
    late DatabaseEventBus eventBus;
    late TripLocalDataSourceImpl tripDS;
    late TelemetryLocalDataSourceImpl telemetryDS;
    late TripRepositoryImpl tripRepo;
    late ProcessTripsUseCase processTrips;

    late String tempDbPath;
    final now = DateTime.now();

    setUp(() async {
      tempDbPath = 'test_trips_${DateTime.now().millisecondsSinceEpoch}.duckdb';
      dbClient = DuckDbClient();
      await dbClient.init(tempDbPath);

      eventBus = DatabaseEventBus();
      tripDS = TripLocalDataSourceImpl(dbClient: dbClient);
      telemetryDS = TelemetryLocalDataSourceImpl(dbClient: dbClient);
      tripRepo = TripRepositoryImpl(localDataSource: tripDS, eventBus: eventBus);
      processTrips = ProcessTripsUseCase(tripRepo);
    });

    tearDown(() async {
      eventBus.dispose();
      await dbClient.close();
      final file = File(tempDbPath);
      if (await file.exists()) {
        await file.delete();
      }
    });

    test('1. Confirmed EXIT starts IN_PROGRESS trip, Confirmed ENTRY completes trip', () async {
      final exitTime = now.subtract(const Duration(minutes: 30));
      final entryTime = now.subtract(const Duration(minutes: 5));

      final exitEvt = GeofenceEvent(
        id: 'evt_exit_EV-101_Warehouse_p1',
        vehicleId: 'EV-101',
        geofenceId: 'Warehouse',
        type: GeofenceEventType.exit,
        eventTimestamp: exitTime,
        packetId: 'p1',
      );

      await processTrips(ProcessTripsParams([exitEvt]));

      final tripsInProgress = await tripRepo.getVehicleTrips('EV-101');
      expect(tripsInProgress.length, 1);
      expect(tripsInProgress.first.status, TripStatus.ongoing);
      expect(tripsInProgress.first.startGeofenceId, 'Warehouse');
      expect(tripsInProgress.first.endGeofenceId, isNull);

      final entryEvt = GeofenceEvent(
        id: 'evt_entry_EV-101_CustomerA_p2',
        vehicleId: 'EV-101',
        geofenceId: 'CustomerA',
        type: GeofenceEventType.entry,
        eventTimestamp: entryTime,
        packetId: 'p2',
      );

      await processTrips(ProcessTripsParams([entryEvt]));

      final tripsCompleted = await tripRepo.getVehicleTrips('EV-101');
      expect(tripsCompleted.length, 1);
      expect(tripsCompleted.first.status, TripStatus.completed);
      expect(tripsCompleted.first.endGeofenceId, 'CustomerA');
    });

    test('2. Duplicate EXIT and Duplicate ENTRY do not create duplicate trips or completions', () async {
      final exitEvt = GeofenceEvent(
        id: 'evt_exit_EV-101_Warehouse_p1',
        vehicleId: 'EV-101',
        geofenceId: 'Warehouse',
        type: GeofenceEventType.exit,
        eventTimestamp: now.subtract(const Duration(minutes: 20)),
        packetId: 'p1',
      );

      final entryEvt = GeofenceEvent(
        id: 'evt_entry_EV-101_CustomerA_p2',
        vehicleId: 'EV-101',
        geofenceId: 'CustomerA',
        type: GeofenceEventType.entry,
        eventTimestamp: now.subtract(const Duration(minutes: 10)),
        packetId: 'p2',
      );

      // Process batch multiple times
      await processTrips(ProcessTripsParams([exitEvt, entryEvt]));
      await processTrips(ProcessTripsParams([exitEvt, entryEvt]));
      await processTrips(ProcessTripsParams([exitEvt, entryEvt]));

      final trips = await tripRepo.getVehicleTrips('EV-101');
      expect(trips.length, 1);
      expect(trips.first.status, TripStatus.completed);
    });

    test('3. Late EXIT revises start boundary without duplicate trip creation', () async {
      final initialExitTime = now.subtract(const Duration(minutes: 30));
      final lateExitTime = now.subtract(const Duration(minutes: 45));

      final exitInitial = GeofenceEvent(
        id: 'evt_exit_EV-101_CentralHub_p1',
        vehicleId: 'EV-101',
        geofenceId: 'CentralHub',
        type: GeofenceEventType.exit,
        eventTimestamp: initialExitTime,
        packetId: 'p1',
      );

      await processTrips(ProcessTripsParams([exitInitial]));

      final exitLate = GeofenceEvent(
        id: 'evt_exit_EV-101_OriginHub_p_late',
        vehicleId: 'EV-101',
        geofenceId: 'OriginHub',
        type: GeofenceEventType.exit,
        eventTimestamp: lateExitTime,
        packetId: 'p_late',
      );

      await processTrips(ProcessTripsParams([exitLate]));

      final trips = await tripRepo.getVehicleTrips('EV-101');
      expect(trips.length, 1);
      expect(trips.first.startGeofenceId, 'OriginHub');
      expect(trips.first.startTime.toUtc().toIso8601String(), lateExitTime.toUtc().toIso8601String());
    });

    test('3b. Late ENTRY revises completion boundary without creating duplicate trip', () async {
      final exitTime = now.subtract(const Duration(hours: 2));
      final initialEntryTime = now.subtract(const Duration(hours: 1));
      final lateEntryTime = now.subtract(const Duration(minutes: 30));

      final exitEvt = GeofenceEvent(
        id: 'evt_exit_EV-101_HubA_p1',
        vehicleId: 'EV-101',
        geofenceId: 'HubA',
        type: GeofenceEventType.exit,
        eventTimestamp: exitTime,
        packetId: 'p1',
      );

      final initialEntryEvt = GeofenceEvent(
        id: 'evt_entry_EV-101_HubB_p2',
        vehicleId: 'EV-101',
        geofenceId: 'HubB',
        type: GeofenceEventType.entry,
        eventTimestamp: initialEntryTime,
        packetId: 'p2',
      );

      await processTrips(ProcessTripsParams([exitEvt, initialEntryEvt]));

      final lateEntryEvt = GeofenceEvent(
        id: 'evt_entry_EV-101_HubC_p2_late',
        vehicleId: 'EV-101',
        geofenceId: 'HubC',
        type: GeofenceEventType.entry,
        eventTimestamp: lateEntryTime,
        packetId: 'p2_late',
      );

      await processTrips(ProcessTripsParams([lateEntryEvt]));

      final trips = await tripRepo.getVehicleTrips('EV-101');
      expect(trips.length, 1);
      expect(trips.first.endGeofenceId, 'HubC');
      expect(trips.first.endTime?.toUtc().toIso8601String(), lateEntryTime.toUtc().toIso8601String());
    });

    test('4. Trip metrics calculation (Distance, Max Speed, SOC used)', () async {
      final startTime = now.subtract(const Duration(minutes: 20));
      final endTime = now.subtract(const Duration(minutes: 5));

      final p1 = TelemetryPacket(
        packetId: 'tp1',
        vehicleId: 'EV-101',
        eventTimestamp: startTime,
        ingestTimestamp: now,
        latitude: 12.9716,
        longitude: 77.5946,
        speed: 20.0,
        batteryLevel: 90.0,
        batteryTemp: 30.0,
        odometerKm: 100.0,
        ignition: true,
      );

      final p2 = TelemetryPacket(
        packetId: 'tp2',
        vehicleId: 'EV-101',
        eventTimestamp: endTime,
        ingestTimestamp: now,
        latitude: 13.0000,
        longitude: 77.6000,
        speed: 60.0,
        batteryLevel: 80.0,
        batteryTemp: 32.0,
        odometerKm: 105.0,
        ignition: true,
      );

      await telemetryDS.insertTelemetryBatch([
        TelemetryPacketModel.fromEntity(p1),
        TelemetryPacketModel.fromEntity(p2),
      ]);

      final exitEvt = GeofenceEvent(
        id: 'evt_exit_EV-101_Depot_tp1',
        vehicleId: 'EV-101',
        geofenceId: 'Depot',
        type: GeofenceEventType.exit,
        eventTimestamp: startTime,
        packetId: 'tp1',
      );

      final entryEvt = GeofenceEvent(
        id: 'evt_entry_EV-101_Station_tp2',
        vehicleId: 'EV-101',
        geofenceId: 'Station',
        type: GeofenceEventType.entry,
        eventTimestamp: endTime,
        packetId: 'tp2',
      );

      await processTrips(ProcessTripsParams([exitEvt, entryEvt]));

      final trips = await tripRepo.getVehicleTrips('EV-101');
      expect(trips.length, 1);
      expect(trips.first.maxSpeedKmh, 60.0);
      expect(trips.first.averageSocUsed, 10.0); // 90% - 80% = 10%
      expect(trips.first.distanceKm, greaterThan(0.0));
    });

    test('5. Trip state survives application restart / fresh instance query', () async {
      final exitEvt = GeofenceEvent(
        id: 'evt_exit_EV-101_Depot_p1',
        vehicleId: 'EV-101',
        geofenceId: 'Depot',
        type: GeofenceEventType.exit,
        eventTimestamp: now.subtract(const Duration(minutes: 10)),
        packetId: 'p1',
      );

      await processTrips(ProcessTripsParams([exitEvt]));

      // Simulate fresh application restart by constructing fresh Data Source & Repository instances
      final freshTripDS = TripLocalDataSourceImpl(dbClient: dbClient);
      final freshTripRepo = TripRepositoryImpl(localDataSource: freshTripDS, eventBus: eventBus);

      final trips = await freshTripRepo.getVehicleTrips('EV-101');
      expect(trips.length, 1);
      expect(trips.first.status, TripStatus.ongoing);
      expect(trips.first.startGeofenceId, 'Depot');
    });
  });
}
