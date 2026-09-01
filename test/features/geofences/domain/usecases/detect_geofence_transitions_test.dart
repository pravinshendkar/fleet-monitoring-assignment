import 'package:fleet_console/features/fleet/domain/entities/telemetry_packet.dart';
import 'package:fleet_console/features/fleet/domain/entities/vehicle.dart';
import 'package:fleet_console/features/fleet/domain/repositories/vehicle_repository.dart';
import 'package:fleet_console/features/geofences/domain/entities/geofence.dart';
import 'package:fleet_console/features/geofences/domain/entities/geofence_event.dart';
import 'package:fleet_console/features/geofences/domain/repositories/geofence_repository.dart';
import 'package:fleet_console/features/geofences/domain/usecases/detect_geofence_transitions.dart';
import 'package:flutter_test/flutter_test.dart';

class MockGeofenceRepository implements GeofenceRepository {
  List<Geofence> geofencesList = [];

  @override
  Future<List<Geofence>> getGeofences() async => geofencesList;

  @override
  Future<Map<String, int>> getGeofenceVehicleCounts() async => {};

  @override
  Future<void> saveGeofence(Geofence geofence) async {}

  @override
  Future<void> setGeofenceActiveStatus(
    String geofenceId,
    bool isActive,
  ) async {}

  @override
  Future<void> updateGeofence(Geofence geofence) async {}
}

class MockVehicleRepository implements VehicleRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Vehicle?> getVehicleById(String id) async => null;
}

void main() {
  group('DetectGeofenceTransitionsUseCase Targeted Verification Tests', () {
    late MockGeofenceRepository geofenceRepo;
    late DetectGeofenceTransitionsUseCase useCase;

    final centerLat = 12.9716;
    final centerLng = 77.5946;
    final radiusMeters = 500.0;
    final now = DateTime.now();

    final activeGeofence = Geofence(
      id: 'g1',
      name: 'Depot A',
      centerLat: centerLat,
      centerLng: centerLng,
      radiusMeters: radiusMeters,
      isActive: true,
      createdAt: now,
    );

    setUp(() {
      geofenceRepo = MockGeofenceRepository();
      geofenceRepo.geofencesList = [activeGeofence];
      useCase = DetectGeofenceTransitionsUseCase(geofenceRepo, MockVehicleRepository());
    });

    test(
      '1. Out-of-order location events are sorted by eventTimestamp before transition evaluation',
      () async {
        final pEarly1 = TelemetryPacket(
          packetId: 'p1',
          vehicleId: 'v1',
          eventTimestamp: now.subtract(const Duration(minutes: 10)),
          ingestTimestamp: now,
          latitude: centerLat,
          longitude: centerLng,
          speed: 10.0,
          batteryLevel: 90.0,
          batteryTemp: 25.0,
          odometerKm: 100.0,
          ignition: true,
          gpsAccuracy: 5.0,
        );

        final pEarly2 = TelemetryPacket(
          packetId: 'p2',
          vehicleId: 'v1',
          eventTimestamp: now.subtract(const Duration(minutes: 9)),
          ingestTimestamp: now,
          latitude: centerLat,
          longitude: centerLng,
          speed: 10.0,
          batteryLevel: 90.0,
          batteryTemp: 25.0,
          odometerKm: 100.1,
          ignition: true,
          gpsAccuracy: 5.0,
        );

        // Ingestion order reversed (pEarly2 passed before pEarly1)
        final events = await useCase(
          DetectGeofenceTransitionsParams(
            packets: [pEarly2, pEarly1],
            activeVehicleGeofences: {},
          ),
        );

        expect(events.length, 1);
        expect(events.first.type, GeofenceEventType.entry);
        expect(
          events.first.eventTimestamp,
          pEarly2.eventTimestamp,
        ); // Entry confirmed at second reading
      },
    );

    test(
      '2. Late location event is inserted into sequence deterministically without duplicate transitions',
      () async {
        final p1 = TelemetryPacket(
          packetId: 'p1',
          vehicleId: 'v1',
          eventTimestamp: now.subtract(const Duration(minutes: 5)),
          ingestTimestamp: now,
          latitude: centerLat,
          longitude: centerLng,
          speed: 10.0,
          batteryLevel: 90.0,
          batteryTemp: 25.0,
          odometerKm: 100.0,
          ignition: true,
          gpsAccuracy: 5.0,
        );

        final p2 = TelemetryPacket(
          packetId: 'p2',
          vehicleId: 'v1',
          eventTimestamp: now.subtract(const Duration(minutes: 4)),
          ingestTimestamp: now,
          latitude: centerLat,
          longitude: centerLng,
          speed: 10.0,
          batteryLevel: 90.0,
          batteryTemp: 25.0,
          odometerKm: 100.1,
          ignition: true,
          gpsAccuracy: 5.0,
        );

        // Process initial batch
        final events1 = await useCase(
          DetectGeofenceTransitionsParams(
            packets: [p1, p2],
            activeVehicleGeofences: {},
          ),
        );
        expect(events1.length, 1);

        // Re-run batch with an additional late packet between p1 and p2
        final pLate = TelemetryPacket(
          packetId: 'p_late',
          vehicleId: 'v1',
          eventTimestamp: now.subtract(const Duration(minutes: 4, seconds: 30)),
          ingestTimestamp: now,
          latitude: centerLat,
          longitude: centerLng,
          speed: 10.0,
          batteryLevel: 90.0,
          batteryTemp: 25.0,
          odometerKm: 100.05,
          ignition: true,
          gpsAccuracy: 5.0,
        );

        final events2 = await useCase(
          DetectGeofenceTransitionsParams(
            packets: [p1, pLate, p2],
            activeVehicleGeofences: {},
          ),
        );

        // Result remains 1 ENTRY transition with deterministic packet id
        expect(events2.length, 1);
        expect(events2.first.packetId, 'p_late');
      },
    );

    test(
      '3. Duplicate packets produce identical deterministic transition identity',
      () async {
        final p1 = TelemetryPacket(
          packetId: 'p1',
          vehicleId: 'v1',
          eventTimestamp: now.subtract(const Duration(minutes: 2)),
          ingestTimestamp: now,
          latitude: centerLat,
          longitude: centerLng,
          speed: 10.0,
          batteryLevel: 90.0,
          batteryTemp: 25.0,
          odometerKm: 100.0,
          ignition: true,
          gpsAccuracy: 5.0,
        );

        final p2 = TelemetryPacket(
          packetId: 'p2',
          vehicleId: 'v1',
          eventTimestamp: now.subtract(const Duration(minutes: 1)),
          ingestTimestamp: now,
          latitude: centerLat,
          longitude: centerLng,
          speed: 10.0,
          batteryLevel: 90.0,
          batteryTemp: 25.0,
          odometerKm: 100.1,
          ignition: true,
          gpsAccuracy: 5.0,
        );

        final eventsA = await useCase(
          DetectGeofenceTransitionsParams(packets: [p1, p2]),
        );
        final eventsB = await useCase(
          DetectGeofenceTransitionsParams(packets: [p1, p2]),
        );

        expect(eventsA.length, 1);
        expect(eventsB.length, 1);
        expect(eventsA.first.id, equals('evt_entry_v1_g1_p2'));
        expect(eventsB.first.id, equals('evt_entry_v1_g1_p2'));
      },
    );

    test(
      '4. Missing intervals do not invent fake intermediate transitions',
      () async {
        // Vehicle jumps from outside depot to far away without intermediate pings
        final pFar1 = TelemetryPacket(
          packetId: 'p_far1',
          vehicleId: 'v1',
          eventTimestamp: now.subtract(const Duration(minutes: 20)),
          ingestTimestamp: now,
          latitude: 15.0000,
          longitude: 80.0000,
          speed: 80.0,
          batteryLevel: 80.0,
          batteryTemp: 30.0,
          odometerKm: 500.0,
          ignition: true,
          gpsAccuracy: 5.0,
        );

        final pFar2 = TelemetryPacket(
          packetId: 'p_far2',
          vehicleId: 'v1',
          eventTimestamp: now.subtract(const Duration(minutes: 10)),
          ingestTimestamp: now,
          latitude: 15.1000,
          longitude: 80.1000,
          speed: 80.0,
          batteryLevel: 75.0,
          batteryTemp: 30.0,
          odometerKm: 515.0,
          ignition: true,
          gpsAccuracy: 5.0,
        );

        final events = await useCase(
          DetectGeofenceTransitionsParams(
            packets: [pFar1, pFar2],
            activeVehicleGeofences: {},
          ),
        );

        expect(events, isEmpty); // No fake ENTER or EXIT invented!
      },
    );

    test(
      '5. Deactivated geofence generates zero transitions while historical data is preserved',
      () async {
        final deactivatedGeofence = activeGeofence.copyWith(isActive: false);
        geofenceRepo.geofencesList = [deactivatedGeofence];

        final p1 = TelemetryPacket(
          packetId: 'p1',
          vehicleId: 'v1',
          eventTimestamp: now.subtract(const Duration(minutes: 2)),
          ingestTimestamp: now,
          latitude: centerLat,
          longitude: centerLng,
          speed: 10.0,
          batteryLevel: 90.0,
          batteryTemp: 25.0,
          odometerKm: 100.0,
          ignition: true,
          gpsAccuracy: 5.0,
        );

        final p2 = TelemetryPacket(
          packetId: 'p2',
          vehicleId: 'v1',
          eventTimestamp: now.subtract(const Duration(minutes: 1)),
          ingestTimestamp: now,
          latitude: centerLat,
          longitude: centerLng,
          speed: 10.0,
          batteryLevel: 90.0,
          batteryTemp: 25.0,
          odometerKm: 100.1,
          ignition: true,
          gpsAccuracy: 5.0,
        );

        final events = await useCase(
          DetectGeofenceTransitionsParams(packets: [p1, p2]),
        );

        expect(events, isEmpty);
      },
    );
  });
}
