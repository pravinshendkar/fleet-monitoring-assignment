import 'dart:async';
import 'package:fleet_console/features/fleet/domain/entities/fleet_summary.dart';
import 'package:fleet_console/features/fleet/domain/entities/vehicle.dart';
import 'package:fleet_console/features/fleet/domain/repositories/vehicle_repository.dart';
import 'package:fleet_console/features/geofences/domain/entities/geofence.dart';
import 'package:fleet_console/features/geofences/domain/repositories/geofence_repository.dart';
import 'package:fleet_console/features/geofences/domain/usecases/create_geofence.dart';
import 'package:fleet_console/features/geofences/domain/usecases/deactivate_geofence.dart';
import 'package:fleet_console/features/geofences/domain/usecases/update_geofence.dart';
import 'package:fleet_console/features/geofences/presentation/cubits/geofences/geofences_cubit.dart';
import 'package:fleet_console/features/geofences/presentation/cubits/geofences/geofences_state.dart';
import 'package:flutter_test/flutter_test.dart';

class MockGeofenceRepositoryPresentation implements GeofenceRepository {
  List<Geofence> geofenceList = [];

  @override
  Future<List<Geofence>> getGeofences() async => geofenceList;

  @override
  Future<Map<String, int>> getGeofenceVehicleCounts() async => {};

  @override
  Future<void> saveGeofence(Geofence geofence) async {
    geofenceList.add(geofence);
  }

  @override
  Future<void> setGeofenceActiveStatus(String geofenceId, bool isActive) async {
    final idx = geofenceList.indexWhere((g) => g.id == geofenceId);
    if (idx != -1) {
      geofenceList[idx] = geofenceList[idx].copyWith(isActive: isActive);
    }
  }

  @override
  Future<void> updateGeofence(Geofence geofence) async {
    final idx = geofenceList.indexWhere((g) => g.id == geofence.id);
    if (idx != -1) {
      geofenceList[idx] = geofence;
    }
  }
}

class MockVehicleRepositoryGeofences implements VehicleRepository {
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

void main() {
  group('GeofencesCubit Tests', () {
    late MockGeofenceRepositoryPresentation geofenceRepo;
    late MockVehicleRepositoryGeofences vehicleRepo;
    late CreateGeofenceUseCase createGeofence;
    late UpdateGeofenceUseCase updateGeofence;
    late DeactivateGeofenceUseCase deactivateGeofence;
    late GeofencesCubit cubit;

    final now = DateTime.now();
    final testGeofence = Geofence(
      id: 'g1',
      name: 'Central Depot',
      centerLat: 12.9716,
      centerLng: 77.5946,
      radiusMeters: 500.0,
      isActive: true,
      createdAt: now,
    );

    setUp(() {
      geofenceRepo = MockGeofenceRepositoryPresentation();
      geofenceRepo.geofenceList = [testGeofence];

      vehicleRepo = MockVehicleRepositoryGeofences();
      createGeofence = CreateGeofenceUseCase(geofenceRepo);
      updateGeofence = UpdateGeofenceUseCase(geofenceRepo);
      deactivateGeofence = DeactivateGeofenceUseCase(geofenceRepo);

      cubit = GeofencesCubit(
        geofenceRepository: geofenceRepo,
        vehicleRepository: vehicleRepo,
        createGeofenceUseCase: createGeofence,
        updateGeofenceUseCase: updateGeofence,
        deactivateGeofenceUseCase: deactivateGeofence,
      );
    });

    tearDown(() {
      cubit.close();
    });

    test('1. Initial state is GeofencesInitial', () {
      expect(cubit.state, equals(GeofencesInitial()));
    });

    test('2. loadGeofences emits Loading then Loaded state', () async {
      await cubit.loadGeofences();

      expect(cubit.state, isA<GeofencesLoaded>());
      final loaded = cubit.state as GeofencesLoaded;
      expect(loaded.geofences.length, 1);
      expect(loaded.geofences.first.name, 'Central Depot');
    });

    test('3. createGeofence adds geofence and reloads state', () async {
      await cubit.loadGeofences();
      await cubit.createGeofence(
        name: 'North Hub',
        lat: 13.0000,
        lng: 77.6000,
        radiusMeters: 800.0,
      );

      expect(cubit.state, isA<GeofencesLoaded>());
      final loaded = cubit.state as GeofencesLoaded;
      expect(loaded.geofences.length, 2);
    });

    test('4. deactivateGeofence updates active status', () async {
      await cubit.loadGeofences();
      await cubit.deactivateGeofence('g1');

      expect(cubit.state, isA<GeofencesLoaded>());
      final loaded = cubit.state as GeofencesLoaded;
      expect(loaded.geofences.first.isActive, isFalse);
    });
  });
}
