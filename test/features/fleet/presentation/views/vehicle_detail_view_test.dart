import 'package:fleet_console/features/fleet/domain/entities/fleet_summary.dart';
import 'package:fleet_console/features/fleet/domain/entities/signal_reading.dart';
import 'package:fleet_console/features/fleet/domain/entities/telemetry_packet.dart';
import 'package:fleet_console/features/fleet/domain/entities/vehicle.dart';
import 'package:fleet_console/features/fleet/domain/repositories/telemetry_repository.dart';
import 'package:fleet_console/features/fleet/domain/repositories/vehicle_repository.dart';
import 'package:fleet_console/features/fleet/domain/usecases/get_vehicle_details.dart';
import 'package:fleet_console/features/fleet/presentation/cubits/vehicle_detail/vehicle_detail_cubit.dart';
import 'package:fleet_console/features/fleet/presentation/views/vehicle_detail_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class MockVehicleRepositoryViewDetail implements VehicleRepository {
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
  Stream<void> watchDatabaseChanges() => const Stream.empty();
}

class FakeTelemetryRepositoryView implements TelemetryRepository {
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

class MockGetVehicleDetailsViewUseCase extends GetVehicleDetailsUseCase {
  VehicleDetailsResult mockResult;

  MockGetVehicleDetailsViewUseCase(this.mockResult)
    : super(
        vehicleRepository: MockVehicleRepositoryViewDetail(),
        telemetryRepository: FakeTelemetryRepositoryView(),
      );

  @override
  Future<VehicleDetailsResult> call(String vehicleId) async {
    return mockResult;
  }
}

void main() {
  group('VehicleDetailView Widget Tests', () {
    late MockVehicleRepositoryViewDetail vehicleRepo;
    late MockGetVehicleDetailsViewUseCase getVehicleDetails;

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

    final mockResult = VehicleDetailsResult(
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
      socHistory: [
        SocPoint(
          timestamp: now.subtract(const Duration(minutes: 10)),
          soc: 88.0,
        ),
        SocPoint(timestamp: now, soc: 85.0),
      ],
      telemetryHistory: const [],
    );

    setUp(() {
      vehicleRepo = MockVehicleRepositoryViewDetail();
      getVehicleDetails = MockGetVehicleDetailsViewUseCase(mockResult);
    });

    testWidgets(
      'renders vehicle detail headers, signals, verdicts, and SOC history table',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider(
              create: (context) => VehicleDetailCubit(
                vehicleId: 'EV-101',
                getVehicleDetailsUseCase: getVehicleDetails,
                vehicleRepository: vehicleRepo,
              ),
              child: const VehicleDetailView(vehicleId: 'EV-101'),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // App bar & title
        expect(find.text('Vehicle EV-101'), findsOneWidget);

        // Section Headers
        expect(find.text('SIGNAL READINGS'), findsOneWidget);
        expect(find.text('SOC HISTORY'), findsOneWidget);

        // Signal labels & values
        expect(find.text('SOC'), findsOneWidget);
        expect(
          find.text('85%'),
          findsNWidgets(2),
        ); // Signal value & table value

        expect(find.text('Range'), findsOneWidget);
        expect(find.text('255 km'), findsOneWidget);

        expect(find.text('Speed'), findsOneWidget);
        expect(find.text('42 km/h'), findsOneWidget);

        expect(find.text('Battery Temp'), findsOneWidget);
        expect(find.text('32°C'), findsOneWidget);

        // Verdict Pills
        expect(find.text('NORMAL'), findsNWidgets(6));
      },
    );
  });
}
