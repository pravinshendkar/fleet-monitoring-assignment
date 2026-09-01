import 'package:fleet_console/features/alerts/domain/entities/alert.dart';
import 'package:fleet_console/features/alerts/domain/repositories/alert_repository.dart';
import 'package:fleet_console/features/alerts/domain/usecases/evaluate_alerts.dart';
import 'package:fleet_console/features/fleet/domain/entities/telemetry_packet.dart';
import 'package:fleet_console/features/fleet/domain/entities/vehicle.dart';
import 'package:fleet_console/features/fleet/domain/repositories/vehicle_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class MockAlertRepository implements AlertRepository {
  List<TelemetryPacket> evaluatedPackets = [];

  @override
  Future<void> evaluateTelemetryAlerts(List<TelemetryPacket> packets) async {
    evaluatedPackets = List.from(packets);
  }

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

class MockVehicleRepository implements VehicleRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Vehicle?> getVehicleById(String id) async => null;
}

void main() {
  group('EvaluateAlertsUseCase Tests', () {
    late MockAlertRepository alertRepository;
    late EvaluateAlertsUseCase useCase;

    setUp(() {
      alertRepository = MockAlertRepository();
      useCase = EvaluateAlertsUseCase(alertRepository, MockVehicleRepository());
    });

    test(
      'evaluates fresh packets for low battery and overheating alerts',
      () async {
        final now = DateTime.now();
        final freshPacket = TelemetryPacket(
          packetId: 'p1',
          vehicleId: 'v1',
          eventTimestamp: now.subtract(const Duration(minutes: 1)),
          ingestTimestamp: now,
          latitude: 12.9716,
          longitude: 77.5946,
          speed: 0.0,
          batteryLevel: 15.0, // Low battery < 20%
          batteryTemp: 48.0, // Overheating > 45°C
          odometerKm: 120.0,
          ignition: true,
        );

        await useCase([freshPacket]);

        expect(alertRepository.evaluatedPackets.length, 1);
        expect(alertRepository.evaluatedPackets.first.packetId, 'p1');
      },
    );

    test('ignores stale readings (> 10 mins old)', () async {
      final now = DateTime.now();
      final stalePacket = TelemetryPacket(
        packetId: 'p_stale',
        vehicleId: 'v1',
        eventTimestamp: now.subtract(const Duration(minutes: 15)),
        ingestTimestamp: now,
        latitude: 12.9716,
        longitude: 77.5946,
        speed: 0.0,
        batteryLevel: 5.0,
        batteryTemp: 50.0,
        odometerKm: 120.0,
        ignition: false,
      );

      await useCase([stalePacket]);

      expect(alertRepository.evaluatedPackets, isEmpty);
    });
  });
}
