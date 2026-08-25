import 'package:fleet_console/features/geofences/domain/entities/geofence_event.dart';
import 'package:fleet_console/features/trips/domain/entities/trip.dart';
import 'package:fleet_console/features/trips/domain/repositories/trip_repository.dart';
import 'package:fleet_console/features/trips/domain/usecases/process_trips.dart';
import 'package:flutter_test/flutter_test.dart';

class MockTripRepository implements TripRepository {
  final Map<String, Trip> tripsMap = {};

  @override
  Future<List<Trip>> getAllTrips() async => tripsMap.values.toList();

  @override
  Future<List<Trip>> getVehicleTrips(String vehicleId) async {
    return tripsMap.values.where((t) => t.vehicleId == vehicleId).toList();
  }

  @override
  Future<void> processGeofenceTransitions(List<GeofenceEvent> events) async {
    final sortedEvents = List<GeofenceEvent>.from(events)
      ..sort((a, b) => a.eventTimestamp.compareTo(b.eventTimestamp));

    for (final event in sortedEvents) {
      if (event.type == GeofenceEventType.exit) {
        final activeTripKey = tripsMap.keys.firstWhere(
          (k) => tripsMap[k]!.vehicleId == event.vehicleId && tripsMap[k]!.status == TripStatus.ongoing,
          orElse: () => '',
        );

        if (activeTripKey.isNotEmpty) {
          final existingTrip = tripsMap[activeTripKey]!;
          if (event.eventTimestamp.isBefore(existingTrip.startTime)) {
            // Late EXIT revises start boundary of existing trip
            tripsMap[activeTripKey] = Trip(
              id: existingTrip.id,
              vehicleId: existingTrip.vehicleId,
              startGeofenceId: event.geofenceId,
              endGeofenceId: existingTrip.endGeofenceId,
              startTime: event.eventTimestamp,
              endTime: existingTrip.endTime,
              distanceKm: existingTrip.distanceKm,
              maxSpeedKmh: existingTrip.maxSpeedKmh,
              averageSocUsed: existingTrip.averageSocUsed,
              status: existingTrip.status,
            );
          }
          // Do not create second trip
        } else {
          final tripId = 'trip_${event.vehicleId}_${event.eventTimestamp.millisecondsSinceEpoch}';
          if (!tripsMap.containsKey(tripId)) {
            tripsMap[tripId] = Trip(
              id: tripId,
              vehicleId: event.vehicleId,
              startGeofenceId: event.geofenceId,
              startTime: event.eventTimestamp,
              distanceKm: 0.0,
              maxSpeedKmh: 0.0,
              averageSocUsed: 0.0,
              status: TripStatus.ongoing,
            );
          }
        }
      } else if (event.type == GeofenceEventType.entry) {
        final activeTripKey = tripsMap.keys.firstWhere(
          (k) => tripsMap[k]!.vehicleId == event.vehicleId && tripsMap[k]!.status == TripStatus.ongoing,
          orElse: () => '',
        );

        if (activeTripKey.isNotEmpty) {
          final old = tripsMap[activeTripKey]!;
          tripsMap[activeTripKey] = Trip(
            id: old.id,
            vehicleId: old.vehicleId,
            startGeofenceId: old.startGeofenceId,
            endGeofenceId: event.geofenceId,
            startTime: old.startTime,
            endTime: event.eventTimestamp,
            distanceKm: old.distanceKm,
            maxSpeedKmh: old.maxSpeedKmh,
            averageSocUsed: old.averageSocUsed,
            status: TripStatus.completed,
          );
        } else {
          // Late ENTRY revises completion boundary of latest completed trip
          final completedTripKey = tripsMap.keys.firstWhere(
            (k) => tripsMap[k]!.vehicleId == event.vehicleId && tripsMap[k]!.status == TripStatus.completed,
            orElse: () => '',
          );

          if (completedTripKey.isNotEmpty) {
            final old = tripsMap[completedTripKey]!;
            tripsMap[completedTripKey] = Trip(
              id: old.id,
              vehicleId: old.vehicleId,
              startGeofenceId: old.startGeofenceId,
              endGeofenceId: event.geofenceId,
              startTime: old.startTime,
              endTime: event.eventTimestamp,
              distanceKm: old.distanceKm,
              maxSpeedKmh: old.maxSpeedKmh,
              averageSocUsed: old.averageSocUsed,
              status: old.status,
            );
          }
        }
      }
    }
  }
}

void main() {
  group('ProcessTripsUseCase Late-Event & Idempotency Tests', () {
    late MockTripRepository tripRepo;
    late ProcessTripsUseCase useCase;

    setUp(() {
      tripRepo = MockTripRepository();
      useCase = ProcessTripsUseCase(tripRepo);
    });

    test('1. Late EXIT revises existing trip start boundary without creating duplicate trip', () async {
      final now = DateTime.now();
      final initialExitTime = now.subtract(const Duration(minutes: 30));

      final initialExit = GeofenceEvent(
        id: 'e1',
        vehicleId: 'v1',
        geofenceId: 'g1',
        type: GeofenceEventType.exit,
        eventTimestamp: initialExitTime,
        packetId: 'p1',
      );

      await useCase(ProcessTripsParams([initialExit]));

      // Late exit arrives with an earlier timestamp (e.g. 45 mins ago)
      final lateExitTime = now.subtract(const Duration(minutes: 45));
      final lateExit = GeofenceEvent(
        id: 'e1_late',
        vehicleId: 'v1',
        geofenceId: 'g_origin',
        type: GeofenceEventType.exit,
        eventTimestamp: lateExitTime,
        packetId: 'p1_late',
      );

      await useCase(ProcessTripsParams([lateExit]));

      final trips = await tripRepo.getVehicleTrips('v1');
      expect(trips.length, 1); // Zero duplicate trips created
      expect(trips.first.startGeofenceId, 'g_origin');
      expect(trips.first.startTime, lateExitTime);
    });

    test('2. Late ENTRY revises existing trip completion boundary without creating duplicate trip', () async {
      final now = DateTime.now();
      final exitTime = now.subtract(const Duration(hours: 2));
      final initialEntryTime = now.subtract(const Duration(hours: 1));

      final exitEvent = GeofenceEvent(
        id: 'e1',
        vehicleId: 'v1',
        geofenceId: 'g1',
        type: GeofenceEventType.exit,
        eventTimestamp: exitTime,
        packetId: 'p1',
      );

      final entryEvent = GeofenceEvent(
        id: 'e2',
        vehicleId: 'v1',
        geofenceId: 'g2',
        type: GeofenceEventType.entry,
        eventTimestamp: initialEntryTime,
        packetId: 'p2',
      );

      await useCase(ProcessTripsParams([exitEvent, entryEvent]));

      // Late entry arrives updating completion boundary
      final lateEntryTime = now.subtract(const Duration(minutes: 30));
      final lateEntry = GeofenceEvent(
        id: 'e2_late',
        vehicleId: 'v1',
        geofenceId: 'g_final',
        type: GeofenceEventType.entry,
        eventTimestamp: lateEntryTime,
        packetId: 'p2_late',
      );

      await useCase(ProcessTripsParams([lateEntry]));

      final trips = await tripRepo.getVehicleTrips('v1');
      expect(trips.length, 1); // Single trip maintained
      expect(trips.first.endGeofenceId, 'g_final');
      expect(trips.first.endTime, lateEntryTime);
    });

    test('3. Duplicate late events remain strictly idempotent', () async {
      final now = DateTime.now();
      final exitEvent = GeofenceEvent(
        id: 'e1',
        vehicleId: 'v1',
        geofenceId: 'g1',
        type: GeofenceEventType.exit,
        eventTimestamp: now,
        packetId: 'p1',
      );

      // Submit identical exit event multiple times
      await useCase(ProcessTripsParams([exitEvent]));
      await useCase(ProcessTripsParams([exitEvent]));
      await useCase(ProcessTripsParams([exitEvent]));

      final trips = await tripRepo.getVehicleTrips('v1');
      expect(trips.length, 1);
    });
  });
}
