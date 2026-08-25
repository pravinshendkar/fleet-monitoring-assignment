import 'dart:async';
import 'package:fleet_console/features/fleet/domain/entities/fleet_summary.dart';
import 'package:fleet_console/features/fleet/domain/entities/vehicle.dart';
import 'package:fleet_console/features/fleet/domain/repositories/vehicle_repository.dart';
import 'package:fleet_console/features/fleet/domain/usecases/get_fleet_summary.dart';
import 'package:fleet_console/features/fleet/domain/usecases/get_vehicles.dart';
import 'package:fleet_console/features/fleet/presentation/cubits/fleet_home/fleet_home_cubit.dart';
import 'package:fleet_console/features/fleet/presentation/cubits/fleet_home/fleet_home_state.dart';
import 'package:flutter_test/flutter_test.dart';

class MockVehicleRepository implements VehicleRepository {
  final StreamController<void> _controller = StreamController<void>.broadcast();

  List<Vehicle> vehicleList = [];
  FleetSummary summary = const FleetSummary(
    totalVehicles: 500,
    movingCount: 125,
    idleCount: 125,
    stoppedCount: 125,
    offlineCount: 125,
    lowBatteryAlertCount: 10,
  );

  @override
  Future<FleetSummary> getFleetSummary() async => summary;

  @override
  Future<Vehicle?> getVehicleById(String vehicleId) async {
    return vehicleList.firstWhere((v) => v.id == vehicleId);
  }

  @override
  Future<List<Vehicle>> getVehicles({
    VehicleStatus? statusFilter,
    double? maxSoc,
    String? searchQuery,
    int limit = 50,
    int offset = 0,
    bool ignoreStaleness = false,
  }) async {
    var result = vehicleList;
    if (statusFilter != null) {
      result = result.where((v) => v.status == statusFilter).toList();
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      result = result
          .where(
            (v) => v.name.contains(searchQuery) || v.id.contains(searchQuery),
          )
          .toList();
    }
    return result;
  }

  @override
  Stream<void> watchDatabaseChanges() => _controller.stream;

  void triggerDbChange() {
    _controller.add(null);
  }
}

void main() {
  group('FleetHomeCubit Tests', () {
    late MockVehicleRepository vehicleRepo;
    late GetFleetSummaryUseCase getFleetSummary;
    late GetVehiclesUseCase getVehicles;
    late FleetHomeCubit cubit;

    final vMoving = Vehicle(
      id: 'EV-001',
      name: 'EV-001',
      status: VehicleStatus.moving,
      lastLatitude: 12.97,
      lastLongitude: 77.59,
      lastSoc: 80.0,
      lastSeenAt: DateTime.now(),
      ignition: true,
    );

    final vOffline = Vehicle(
      id: 'EV-400',
      name: 'EV-400',
      status: VehicleStatus.offline,
      lastLatitude: 12.97,
      lastLongitude: 77.59,
      lastSoc: 40.0,
      lastSeenAt: DateTime.now().subtract(const Duration(minutes: 15)),
      ignition: false,
    );

    setUp(() {
      vehicleRepo = MockVehicleRepository();
      vehicleRepo.vehicleList = [vMoving, vOffline];

      getFleetSummary = GetFleetSummaryUseCase(vehicleRepo);
      getVehicles = GetVehiclesUseCase(vehicleRepo);

      cubit = FleetHomeCubit(
        getFleetSummaryUseCase: getFleetSummary,
        getVehiclesUseCase: getVehicles,
        vehicleRepository: vehicleRepo,
      );
    });

    tearDown(() {
      cubit.close();
    });

    test('1. Initial state is FleetHomeInitial', () {
      expect(cubit.state, equals(FleetHomeInitial()));
    });

    test(
      '2. loadFleetData emits Loading then Loaded with summary & vehicles',
      () async {
        await cubit.loadFleetData();

        expect(cubit.state, isA<FleetHomeLoaded>());
        final loadedState = cubit.state as FleetHomeLoaded;
        expect(loadedState.summary.totalVehicles, 500);
        expect(loadedState.vehicles.length, 2);
        expect(loadedState.selectedFilter, isNull);
      },
    );

    test(
      '3. setFilter updates selectedFilter and queries filtered list',
      () async {
        await cubit.setFilter(VehicleStatus.moving);

        expect(cubit.state, isA<FleetHomeLoaded>());
        final loadedState = cubit.state as FleetHomeLoaded;
        expect(loadedState.selectedFilter, VehicleStatus.moving);
        expect(loadedState.vehicles.length, 1);
        expect(loadedState.vehicles.first.id, 'EV-001');
      },
    );

    test('4. setSearchQuery filters vehicles by query', () async {
      await cubit.setSearchQuery('EV-400');

      expect(cubit.state, isA<FleetHomeLoaded>());
      final loadedState = cubit.state as FleetHomeLoaded;
      expect(loadedState.searchQuery, 'EV-400');
      expect(loadedState.vehicles.length, 1);
      expect(loadedState.vehicles.first.id, 'EV-400');
    });

    test(
      '5. Empty results handled cleanly when filter matches no vehicles',
      () async {
        await cubit.setFilter(VehicleStatus.idle);

        expect(cubit.state, isA<FleetHomeLoaded>());
        final loadedState = cubit.state as FleetHomeLoaded;
        expect(loadedState.vehicles, isEmpty);
      },
    );
  });
}
