import 'package:fleet_console/features/fleet/domain/entities/fleet_summary.dart';
import 'package:fleet_console/features/fleet/domain/entities/vehicle.dart';
import 'package:fleet_console/features/fleet/domain/repositories/vehicle_repository.dart';
import 'package:fleet_console/features/geofences/domain/entities/geofence.dart';
import 'package:fleet_console/features/geofences/domain/repositories/geofence_repository.dart';
import 'package:fleet_console/features/geofences/domain/usecases/create_geofence.dart';
import 'package:fleet_console/features/geofences/domain/usecases/deactivate_geofence.dart';
import 'package:fleet_console/features/geofences/domain/usecases/update_geofence.dart';
import 'package:fleet_console/features/geofences/presentation/cubits/geofences/geofences_cubit.dart';
import 'package:fleet_console/features/geofences/presentation/views/geofences_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class MockGeofenceRepoView implements GeofenceRepository {
  List<Geofence> list = [];

  @override
  Future<List<Geofence>> getGeofences() async => list;

  @override
  Future<Map<String, int>> getGeofenceVehicleCounts() async => {'g1': 3};

  @override
  Future<void> saveGeofence(Geofence geofence) async {
    list.add(geofence);
  }

  @override
  Future<void> setGeofenceActiveStatus(String geofenceId, bool isActive) async {
    final idx = list.indexWhere((g) => g.id == geofenceId);
    if (idx != -1) {
      list[idx] = list[idx].copyWith(isActive: isActive);
    }
  }

  @override
  Future<void> updateGeofence(Geofence geofence) async {
    final idx = list.indexWhere((g) => g.id == geofence.id);
    if (idx != -1) {
      list[idx] = geofence;
    }
  }
}

class MockVehicleRepoViewGeofences implements VehicleRepository {
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
  }) async => [];

  @override
  Stream<void> watchDatabaseChanges() => const Stream.empty();
}

void main() {
  group('GeofencesView Widget Tests', () {
    late MockGeofenceRepoView geofenceRepo;
    late MockVehicleRepoViewGeofences vehicleRepo;
    late CreateGeofenceUseCase createGeofence;
    late UpdateGeofenceUseCase updateGeofence;
    late DeactivateGeofenceUseCase deactivateGeofence;

    final now = DateTime.now();
    final testGeofence = Geofence(
      id: 'g1',
      name: 'Bangalore Central Depot',
      centerLat: 12.9716,
      centerLng: 77.5946,
      radiusMeters: 500.0,
      isActive: true,
      createdAt: now,
      activeVehicleCount: 3,
    );

    setUp(() {
      geofenceRepo = MockGeofenceRepoView();
      geofenceRepo.list = [testGeofence];

      vehicleRepo = MockVehicleRepoViewGeofences();
      createGeofence = CreateGeofenceUseCase(geofenceRepo);
      updateGeofence = UpdateGeofenceUseCase(geofenceRepo);
      deactivateGeofence = DeactivateGeofenceUseCase(geofenceRepo);
    });

    testWidgets(
      'renders geofence card with active status badge and SQL vehicle count',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider(
              create: (context) => GeofencesCubit(
                geofenceRepository: geofenceRepo,
                vehicleRepository: vehicleRepo,
                createGeofenceUseCase: createGeofence,
                updateGeofenceUseCase: updateGeofence,
                deactivateGeofenceUseCase: deactivateGeofence,
              ),
              child: const GeofencesView(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // App bar & title
        expect(find.text('Geofences'), findsOneWidget);

        // Geofence Card content
        expect(find.text('Bangalore Central Depot'), findsOneWidget);
        expect(find.text('ACTIVE'), findsOneWidget);
        expect(find.text('3 vehicles inside'), findsOneWidget);
        expect(find.text('Radius: 500 meters'), findsOneWidget);
      },
    );
  });
}
