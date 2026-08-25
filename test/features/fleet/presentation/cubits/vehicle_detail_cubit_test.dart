import 'dart:async';
import 'package:fleet_console/features/fleet/domain/entities/fleet_summary.dart';
import 'package:fleet_console/features/fleet/domain/entities/signal_reading.dart';
import 'package:fleet_console/features/fleet/domain/entities/telemetry_packet.dart';
import 'package:fleet_console/features/fleet/domain/entities/vehicle.dart';
import 'package:fleet_console/features/fleet/domain/repositories/telemetry_repository.dart';
import 'package:fleet_console/features/fleet/domain/repositories/vehicle_repository.dart';
import 'package:fleet_console/features/fleet/domain/usecases/get_vehicle_details.dart';
import 'package:fleet_console/features/fleet/presentation/cubits/vehicle_detail/vehicle_detail_cubit.dart';
import 'package:fleet_console/features/fleet/presentation/cubits/vehicle_detail/vehicle_detail_state.dart';
import 'package:flutter_test/flutter_test.dart';

class MockVehicleRepositoryDetail implements VehicleRepository {
  final StreamController<void> _controller = StreamController<void>.broadcast();

  @override
  Future<Vehicle?> getVehicleById(String vehicleId) async => null;

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
  }) async => [];

  @override
  Stream<void> watchDatabaseChanges() => _controller.stream;

  void triggerDbChange() => _controller.add(null);
}

class FakeTelemetryRepository implements TelemetryRepository {
  @override
  Future<List<TelemetryPacket>> getSocHistory(
    String vehicleId, {
    DateTime? startTime,
    int limit = 100,
  }) async => [];

  @override
  Future<List<TelemetryPacket>> getVehicleTelemetryHistory(
    String vehicleId, {
    DateTime? startTime,
    DateTime? endTime,
    int limit = 100,
  }) async => [];

  @override
  Future<void> ingestBatch(List<TelemetryPacket> packets) async {}
}

class MockGetVehicleDetailsUseCase extends GetVehicleDetailsUseCase {
  VehicleDetailsResult mockResult;

  MockGetVehicleDetailsUseCase(this.mockResult)
    : super(
        vehicleRepository: MockVehicleRepositoryDetail(),
        telemetryRepository: FakeTelemetryRepository(),
      );

  @override
  Future<VehicleDetailsResult> call(String vehicleId) async {
    return mockResult;
  }
}

void main() {
  group('VehicleDetailCubit Tests', () {
    late MockVehicleRepositoryDetail vehicleRepo;
    late MockGetVehicleDetailsUseCase getVehicleDetails;
    late VehicleDetailCubit cubit;

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

    final mockSuccessDetails = VehicleDetailsResult(
      vehicle: testVehicle,
      socSignal: SignalReading(
        label: 'SOC',
        displayValue: '85%',
        timestamp: now,
        verdict: SignalVerdict.normal,
      ),
      rangeSignal: SignalReading(
        label: 'Range',
        displayValue: '255 km',
        timestamp: now,
        verdict: SignalVerdict.normal,
      ),
      speedSignal: SignalReading(
        label: 'Speed',
        displayValue: '42 km/h',
        timestamp: now,
        verdict: SignalVerdict.normal,
      ),
      tempSignal: SignalReading(
        label: 'Battery Temp',
        displayValue: '32°C',
        timestamp: now,
        verdict: SignalVerdict.normal,
      ),
      odometerSignal: SignalReading(
        label: 'Odometer',
        displayValue: '52340 km',
        timestamp: now,
        verdict: SignalVerdict.normal,
      ),
      lastPingSignal: SignalReading(
        label: 'Last Ping',
        displayValue: '30s ago',
        timestamp: now,
        verdict: SignalVerdict.normal,
      ),
      socHistory: const [],
      telemetryHistory: const [],
    );

    setUp(() {
      vehicleRepo = MockVehicleRepositoryDetail();
      getVehicleDetails = MockGetVehicleDetailsUseCase(mockSuccessDetails);
      cubit = VehicleDetailCubit(
        vehicleId: 'EV-101',
        getVehicleDetailsUseCase: getVehicleDetails,
        vehicleRepository: vehicleRepo,
      );
    });

    tearDown(() {
      cubit.close();
    });

    test('1. Initial state is VehicleDetailInitial', () {
      expect(cubit.state, equals(VehicleDetailInitial()));
    });

    test('2. loadVehicleDetail emits Loading then Loaded state', () async {
      await cubit.loadVehicleDetail();

      expect(cubit.state, isA<VehicleDetailLoaded>());
      final loaded = cubit.state as VehicleDetailLoaded;
      expect(loaded.details.vehicle?.id, 'EV-101');
      expect(loaded.details.socSignal.displayValue, '85%');
    });

    test('3. Vehicle not found emits VehicleDetailError state', () async {
      getVehicleDetails.mockResult = VehicleDetailsResult(
        vehicle: null,
        socSignal: const SignalReading(
          label: 'SOC',
          displayValue: '—',
          verdict: SignalVerdict.none,
        ),
        rangeSignal: const SignalReading(
          label: 'Range',
          displayValue: '—',
          verdict: SignalVerdict.none,
        ),
        speedSignal: const SignalReading(
          label: 'Speed',
          displayValue: '—',
          verdict: SignalVerdict.none,
        ),
        tempSignal: const SignalReading(
          label: 'Battery Temp',
          displayValue: '—',
          verdict: SignalVerdict.none,
        ),
        odometerSignal: const SignalReading(
          label: 'Odometer',
          displayValue: '—',
          verdict: SignalVerdict.none,
        ),
        lastPingSignal: const SignalReading(
          label: 'Last Ping',
          displayValue: '—',
          verdict: SignalVerdict.none,
        ),
        socHistory: const [],
        telemetryHistory: const [],
      );

      await cubit.loadVehicleDetail();

      expect(cubit.state, isA<VehicleDetailError>());
      final errorState = cubit.state as VehicleDetailError;
      expect(errorState.message, contains('not found'));
    });
  });
}
