import 'package:fleet_console/features/fleet/domain/entities/fleet_summary.dart';
import 'package:fleet_console/features/fleet/domain/entities/signal_reading.dart';
import 'package:fleet_console/features/fleet/domain/entities/telemetry_packet.dart';
import 'package:fleet_console/features/fleet/domain/entities/vehicle.dart';
import 'package:fleet_console/features/fleet/domain/repositories/telemetry_repository.dart';
import 'package:fleet_console/features/fleet/domain/repositories/vehicle_repository.dart';
import 'package:fleet_console/features/fleet/domain/usecases/get_vehicle_details.dart';
import 'package:flutter_test/flutter_test.dart';

class MockVehicleRepository implements VehicleRepository {
  Vehicle? vehicle;

  @override
  Future<Vehicle?> getVehicleById(String vehicleId) async {
    if (vehicle?.id == vehicleId) return vehicle;
    return null;
  }

  @override
  Future<FleetSummary> getFleetSummary() async => throw UnimplementedError();

  @override
  Future<List<Vehicle>> getVehicles({
    VehicleStatus? statusFilter,
    double? maxSoc,
    String? searchQuery,
    int limit = 50,
    int offset = 0,
    bool ignoreStaleness = false,
  }) async => throw UnimplementedError();

  @override
  Stream<void> watchDatabaseChanges() => const Stream.empty();
}

class MockTelemetryRepository implements TelemetryRepository {
  List<TelemetryPacket> history = [];

  @override
  Future<List<TelemetryPacket>> getVehicleTelemetryHistory(
    String vehicleId, {
    DateTime? startTime,
    DateTime? endTime,
    int limit = 100,
  }) async {
    return history;
  }

  @override
  Future<List<TelemetryPacket>> getSocHistory(
    String vehicleId, {
    DateTime? startTime,
    int limit = 100,
  }) async => history;

  @override
  Future<void> ingestBatch(List<TelemetryPacket> packets) async {}
}

void main() {
  group('GetVehicleDetailsUseCase Domain Tests', () {
    late MockVehicleRepository vehicleRepo;
    late MockTelemetryRepository telemetryRepo;
    late GetVehicleDetailsUseCase useCase;

    final now = DateTime.now();

    final testVehicle = Vehicle(
      id: 'EV-101',
      name: 'EV-101',
      status: VehicleStatus.moving,
      lastLatitude: 12.97,
      lastLongitude: 77.59,
      lastSoc: 85.0,
      lastSeenAt: now,
      ignition: true,
    );

    setUp(() {
      vehicleRepo = MockVehicleRepository();
      telemetryRepo = MockTelemetryRepository();
      useCase = GetVehicleDetailsUseCase(
        vehicleRepository: vehicleRepo,
        telemetryRepository: telemetryRepo,
      );
    });

    test(
      '1. Vehicle not found returns null vehicle and empty signals',
      () async {
        final result = await useCase('UNKNOWN-999');

        expect(result.vehicle, isNull);
        expect(result.socSignal.displayValue, '—');
        expect(result.socSignal.verdict, SignalVerdict.none);
        expect(result.socHistory, isEmpty);
      },
    );

    test('2. Fresh NORMAL telemetry packet returns NORMAL verdicts', () async {
      vehicleRepo.vehicle = testVehicle;
      telemetryRepo.history = [
        TelemetryPacket(
          packetId: 'p1',
          vehicleId: 'EV-101',
          eventTimestamp: now.subtract(const Duration(seconds: 30)),
          ingestTimestamp: now,
          latitude: 12.97,
          longitude: 77.59,
          speed: 42.0,
          batteryLevel: 85.0,
          batteryTemp: 32.0,
          odometerKm: 52340.0,
          ignition: true,
        ),
      ];

      final result = await useCase('EV-101');

      expect(result.vehicle?.id, 'EV-101');
      expect(result.socSignal.displayValue, '85%');
      expect(result.socSignal.verdict, SignalVerdict.normal);

      expect(result.rangeSignal.displayValue, '—');
      expect(result.rangeSignal.verdict, SignalVerdict.none);

      expect(result.speedSignal.displayValue, '42.0 km/h');
      expect(result.speedSignal.verdict, SignalVerdict.normal);

      expect(result.tempSignal.displayValue, '32.0°C');
      expect(result.tempSignal.verdict, SignalVerdict.normal);

      expect(result.odometerSignal.displayValue, '52340.0 km');
      expect(result.odometerSignal.verdict, SignalVerdict.normal);
    });

    test('3. Low Battery (<20%) returns ALERT verdict', () async {
      vehicleRepo.vehicle = testVehicle;
      telemetryRepo.history = [
        TelemetryPacket(
          packetId: 'p1',
          vehicleId: 'EV-101',
          eventTimestamp: now.subtract(const Duration(seconds: 30)),
          ingestTimestamp: now,
          latitude: 12.97,
          longitude: 77.59,
          speed: 0.0,
          batteryLevel: 15.0,
          batteryTemp: 30.0,
          odometerKm: 1000.0,
          ignition: false,
        ),
      ];

      final result = await useCase('EV-101');

      expect(result.socSignal.displayValue, '15%');
      expect(result.socSignal.verdict, SignalVerdict.alert);
    });

    test('4. Overheating (>45°C) returns ALERT verdict', () async {
      vehicleRepo.vehicle = testVehicle;
      telemetryRepo.history = [
        TelemetryPacket(
          packetId: 'p1',
          vehicleId: 'EV-101',
          eventTimestamp: now.subtract(const Duration(seconds: 30)),
          ingestTimestamp: now,
          latitude: 12.97,
          longitude: 77.59,
          speed: 50.0,
          batteryLevel: 60.0,
          batteryTemp: 48.5,
          odometerKm: 1000.0,
          ignition: true,
        ),
      ];

      final result = await useCase('EV-101');

      expect(result.tempSignal.displayValue, '48.5°C');
      expect(result.tempSignal.verdict, SignalVerdict.alert);
    });

    test('5. Stale packet (>10 mins old) returns STALE verdict', () async {
      vehicleRepo.vehicle = testVehicle;
      telemetryRepo.history = [
        TelemetryPacket(
          packetId: 'p1',
          vehicleId: 'EV-101',
          eventTimestamp: now.subtract(const Duration(minutes: 15)),
          ingestTimestamp: now,
          latitude: 12.97,
          longitude: 77.59,
          speed: 0.0,
          batteryLevel: 80.0,
          batteryTemp: 30.0,
          odometerKm: 1000.0,
          ignition: false,
        ),
      ];

      final result = await useCase('EV-101');

      expect(result.socSignal.verdict, SignalVerdict.stale);
      expect(result.speedSignal.verdict, SignalVerdict.stale);
      expect(result.tempSignal.verdict, SignalVerdict.stale);
    });

    test('6. SOC history is ordered chronologically ASC', () async {
      final t1 = now.subtract(const Duration(minutes: 20));
      final t2 = now.subtract(const Duration(minutes: 10));

      vehicleRepo.vehicle = testVehicle;
      // DB returns DESC (t2 then t1)
      telemetryRepo.history = [
        TelemetryPacket(
          packetId: 'p2',
          vehicleId: 'EV-101',
          eventTimestamp: t2,
          ingestTimestamp: now,
          latitude: 12.97,
          longitude: 77.59,
          speed: 0.0,
          batteryLevel: 75.0,
          batteryTemp: 30.0,
          odometerKm: 1000.0,
          ignition: false,
        ),
        TelemetryPacket(
          packetId: 'p1',
          vehicleId: 'EV-101',
          eventTimestamp: t1,
          ingestTimestamp: now,
          latitude: 12.97,
          longitude: 77.59,
          speed: 0.0,
          batteryLevel: 80.0,
          batteryTemp: 30.0,
          odometerKm: 1000.0,
          ignition: false,
        ),
      ];

      final result = await useCase('EV-101');

      expect(result.socHistory.length, 2);
      expect(result.socHistory[0].soc, 80.0); // t1 first
      expect(result.socHistory[1].soc, 75.0); // t2 second
    });
  });
}
