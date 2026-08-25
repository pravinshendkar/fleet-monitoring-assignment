import 'package:fleet_console/features/fleet/domain/entities/fleet_summary.dart';
import 'package:fleet_console/features/fleet/domain/entities/vehicle.dart';
import 'package:fleet_console/features/fleet/domain/repositories/vehicle_repository.dart';
import 'package:fleet_console/features/geofences/domain/entities/geofence_event.dart';
import 'package:fleet_console/features/trips/domain/entities/trip.dart';
import 'package:fleet_console/features/trips/domain/repositories/trip_repository.dart';
import 'package:fleet_console/features/trips/domain/usecases/get_all_trips.dart';
import 'package:fleet_console/features/trips/presentation/cubits/trips/trips_cubit.dart';
import 'package:fleet_console/features/trips/presentation/views/trips_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class MockTripRepoView implements TripRepository {
  List<Trip> tripList = [];

  @override
  Future<List<Trip>> getAllTrips() async => tripList;

  @override
  Future<List<Trip>> getVehicleTrips(String vehicleId) async {
    return tripList.where((t) => t.vehicleId == vehicleId).toList();
  }

  @override
  Future<void> processGeofenceTransitions(List<GeofenceEvent> events) async {}
}

class MockVehicleRepoViewTrips implements VehicleRepository {
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
  group('TripsView Widget Tests', () {
    late MockTripRepoView tripRepo;
    late MockVehicleRepoViewTrips vehicleRepo;
    late GetAllTripsUseCase getAllTripsUseCase;

    final now = DateTime.now();
    final ongoingTrip = Trip(
      id: 't1',
      vehicleId: 'EV-101',
      startGeofenceId: 'Warehouse Depot',
      startTime: now.subtract(const Duration(minutes: 30)),
      distanceKm: 8.2,
      maxSpeedKmh: 45.0,
      averageSocUsed: 6.0,
      status: TripStatus.ongoing,
    );

    setUp(() {
      tripRepo = MockTripRepoView();
      tripRepo.tripList = [ongoingTrip];

      vehicleRepo = MockVehicleRepoViewTrips();
      getAllTripsUseCase = GetAllTripsUseCase(tripRepo);
    });

    testWidgets('renders trip card with status badge, route header, and metrics grid', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider(
            create: (context) => TripsCubit(
              tripRepository: tripRepo,
              vehicleRepository: vehicleRepo,
              getAllTripsUseCase: getAllTripsUseCase,
            ),
            child: const TripsView(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // App bar & title
      expect(find.text('Fleet Trips'), findsOneWidget);

      // Trip Card content
      expect(find.text('Vehicle: EV-101'), findsOneWidget);
      expect(find.text('IN_PROGRESS'), findsOneWidget);
      expect(find.text('Warehouse Depot → In Progress...'), findsOneWidget);
      expect(find.text('8.2 km'), findsOneWidget);
      expect(find.text('45 km/h'), findsOneWidget);
      expect(find.text('6.0%'), findsOneWidget);
    });
  });
}
