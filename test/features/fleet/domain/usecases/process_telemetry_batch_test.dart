import 'package:fleet_console/features/alerts/domain/entities/alert.dart';
import 'package:fleet_console/features/alerts/domain/repositories/alert_repository.dart';
import 'package:fleet_console/features/alerts/domain/usecases/evaluate_alerts.dart';
import 'package:fleet_console/features/fleet/domain/entities/telemetry_packet.dart';
import 'package:fleet_console/features/fleet/domain/repositories/telemetry_repository.dart';
import 'package:fleet_console/features/fleet/domain/usecases/process_telemetry_batch.dart';
import 'package:fleet_console/features/geofences/domain/entities/geofence.dart';
import 'package:fleet_console/features/geofences/domain/entities/geofence_event.dart';
import 'package:fleet_console/features/geofences/domain/repositories/geofence_repository.dart';
import 'package:fleet_console/features/geofences/domain/usecases/detect_geofence_transitions.dart';
import 'package:fleet_console/features/trips/domain/entities/trip.dart';
import 'package:fleet_console/features/trips/domain/repositories/trip_repository.dart';
import 'package:fleet_console/features/trips/domain/usecases/process_trips.dart';
import 'package:flutter_test/flutter_test.dart';

class MockTelemetryRepo implements TelemetryRepository {
  List<TelemetryPacket> ingestedPackets = [];

  @override
  Future<void> ingestBatch(List<TelemetryPacket> packets) async {
    ingestedPackets = List.from(packets);
  }

  @override
  Future<List<TelemetryPacket>> getVehicleTelemetryHistory(
    String vehicleId, {
    DateTime? startTime,
    DateTime? endTime,
    int limit = 100,
  }) async => ingestedPackets;

  @override
  Future<List<TelemetryPacket>> getSocHistory(
    String vehicleId, {
    DateTime? startTime,
    int limit = 100,
  }) async => ingestedPackets;
}

class MockAlertRepo implements AlertRepository {
  @override
  Future<void> evaluateTelemetryAlerts(List<TelemetryPacket> packets) async {}

  @override
  Future<List<Alert>> getActiveAlerts() async => [];

  @override
  Future<List<Alert>> getVehicleAlerts(String vehicleId) async => [];

  @override
  Future<List<Alert>> getAllAlerts() async => [];

  @override
  Future<void> updateAlertStatus(
    String alertId,
    AlertStatus status, {
    String? dismissalReason,
  }) async {}
}

class MockGeofenceRepo implements GeofenceRepository {
  @override
  Future<List<Geofence>> getGeofences() async => [];

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

class MockTripRepo implements TripRepository {
  List<GeofenceEvent> processedEvents = [];

  @override
  Future<List<Trip>> getAllTrips() async => [];

  @override
  Future<List<Trip>> getVehicleTrips(String vehicleId) async => [];

  @override
  Future<void> processGeofenceTransitions(List<GeofenceEvent> events) async {
    processedEvents = List.from(events);
  }
}

void main() {
  group('ProcessTelemetryBatchUseCase Orchestration Tests', () {
    late MockTelemetryRepo telemetryRepo;
    late MockAlertRepo alertRepo;
    late MockGeofenceRepo geofenceRepo;
    late MockTripRepo tripRepo;

    late ProcessTelemetryBatchUseCase useCase;

    setUp(() {
      telemetryRepo = MockTelemetryRepo();
      alertRepo = MockAlertRepo();
      geofenceRepo = MockGeofenceRepo();
      tripRepo = MockTripRepo();

      final evalAlerts = EvaluateAlertsUseCase(alertRepo);
      final detectTransitions = DetectGeofenceTransitionsUseCase(geofenceRepo);
      final processTrips = ProcessTripsUseCase(tripRepo);

      useCase = ProcessTelemetryBatchUseCase(
        telemetryRepository: telemetryRepo,
        evaluateAlertsUseCase: evalAlerts,
        detectGeofenceTransitionsUseCase: detectTransitions,
        processTripsUseCase: processTrips,
      );
    });

    test(
      'sorts packets chronologically and orchestrates telemetry ingest',
      () async {
        final now = DateTime.now();
        final packetLater = TelemetryPacket(
          packetId: 'p2',
          vehicleId: 'v1',
          eventTimestamp: now.add(const Duration(minutes: 2)),
          ingestTimestamp: now,
          latitude: 12.0,
          longitude: 77.0,
          speed: 30.0,
          batteryLevel: 80.0,
          batteryTemp: 28.0,
          odometerKm: 100.0,
          ignition: true,
        );

        final packetEarlier = TelemetryPacket(
          packetId: 'p1',
          vehicleId: 'v1',
          eventTimestamp: now,
          ingestTimestamp: now,
          latitude: 12.0,
          longitude: 77.0,
          speed: 25.0,
          batteryLevel: 81.0,
          batteryTemp: 28.0,
          odometerKm: 99.0,
          ignition: true,
        );

        await useCase(
          ProcessTelemetryBatchParams([packetLater, packetEarlier]),
        );

        expect(telemetryRepo.ingestedPackets.length, 2);
        expect(telemetryRepo.ingestedPackets[0].packetId, 'p1');
        expect(telemetryRepo.ingestedPackets[1].packetId, 'p2');
      },
    );
  });
}
