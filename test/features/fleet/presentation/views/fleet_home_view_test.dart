import 'dart:async';
import 'package:fleet_console/features/fleet/domain/entities/fleet_summary.dart';
import 'package:fleet_console/features/fleet/domain/entities/vehicle.dart';
import 'package:fleet_console/features/fleet/domain/repositories/vehicle_repository.dart';
import 'package:fleet_console/features/fleet/domain/usecases/get_fleet_summary.dart';
import 'package:fleet_console/features/fleet/domain/usecases/get_vehicles.dart';
import 'package:fleet_console/features/fleet/presentation/cubits/fleet_home/fleet_home_cubit.dart';
import 'package:fleet_console/features/fleet/presentation/views/fleet_home_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class MockVehicleRepositoryView implements VehicleRepository {
  List<Vehicle> vehicleList = [];
  FleetSummary summary = const FleetSummary(
    totalVehicles: 500,
    movingCount: 150,
    idleCount: 100,
    stoppedCount: 150,
    offlineCount: 100,
    lowBatteryAlertCount: 20,
  );

  @override
  Future<FleetSummary> getFleetSummary() async => summary;

  @override
  Future<Vehicle?> getVehicleById(String vehicleId) async => null;

  @override
  Future<List<Vehicle>> getVehicles({
    VehicleStatus? statusFilter,
    double? maxSoc,
    String? searchQuery,
    int limit = 50,
    int offset = 0,
    bool ignoreStaleness = false,
  }) async {
    if (statusFilter != null) {
      return vehicleList.where((v) => v.status == statusFilter).toList();
    }
    return vehicleList;
  }

  @override
  Stream<void> watchDatabaseChanges() => const Stream.empty();
}

void main() {
  group('FleetHomeView Widget Tests', () {
    late MockVehicleRepositoryView vehicleRepo;
    late GetFleetSummaryUseCase getFleetSummary;
    late GetVehiclesUseCase getVehicles;

    final testVehicle = Vehicle(
      id: 'EV-001',
      name: 'EV-001',
      status: VehicleStatus.moving,
      lastLatitude: 12.97,
      lastLongitude: 77.59,
      lastSoc: 85.0,
      lastSeenAt: DateTime.now(),
      ignition: true,
    );

    setUp(() {
      vehicleRepo = MockVehicleRepositoryView();
      vehicleRepo.vehicleList = [testVehicle];

      getFleetSummary = GetFleetSummaryUseCase(vehicleRepo);
      getVehicles = GetVehiclesUseCase(vehicleRepo);
    });

    testWidgets(
      'renders header, live count chips, search bar, and vehicle card',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider(
              create: (context) => FleetHomeCubit(
                getFleetSummaryUseCase: getFleetSummary,
                getVehiclesUseCase: getVehicles,
                vehicleRepository: vehicleRepo,
              ),
              child: const FleetHomeView(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // App bar & Title
        expect(find.text('Fleet Console'), findsOneWidget);

        // Filter chips
        expect(find.text('All'), findsOneWidget);
        expect(find.text('Moving'), findsOneWidget);
        expect(find.text('Idle'), findsOneWidget);
        expect(find.text('Stopped'), findsOneWidget);
        expect(find.text('Offline'), findsOneWidget);

        // Counts
        expect(find.text('500'), findsOneWidget);

        // Vehicle card
        expect(find.text('EV-001'), findsOneWidget);
        expect(find.text('ID: EV-001'), findsOneWidget);
        expect(find.text('MOVING'), findsOneWidget);
        expect(find.text('85%'), findsOneWidget);
      },
    );
  });
}
