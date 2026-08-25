import 'package:fleet_console/features/fleet/domain/entities/fleet_summary.dart';
import 'package:fleet_console/features/fleet/domain/entities/vehicle.dart';
import 'package:fleet_console/features/fleet/domain/repositories/vehicle_repository.dart';
import 'package:fleet_console/features/geofences/domain/entities/geofence_event.dart';
import 'package:fleet_console/features/trips/domain/entities/trip.dart';
import 'package:fleet_console/features/trips/domain/repositories/trip_repository.dart';
import 'package:fleet_console/features/trips/domain/usecases/get_all_trips.dart';
import 'package:fleet_console/features/trips/presentation/cubits/trips/trips_cubit.dart';
import 'package:fleet_console/features/trips/presentation/cubits/trips/trips_state.dart';
import 'package:flutter_test/flutter_test.dart';

class MockTripRepoPresentation implements TripRepository {
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

class MockVehicleRepoTrips implements VehicleRepository {
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
  group('TripsCubit Tests', () {
    late MockTripRepoPresentation tripRepo;
    late MockVehicleRepoTrips vehicleRepo;
    late GetAllTripsUseCase getAllTripsUseCase;
    late TripsCubit cubit;

    final now = DateTime.now();
    final ongoingTrip = Trip(
      id: 't1',
      vehicleId: 'EV-101',
      startGeofenceId: 'Warehouse',
      startTime: now.subtract(const Duration(minutes: 30)),
      distanceKm: 5.0,
      maxSpeedKmh: 40.0,
      averageSocUsed: 4.0,
      status: TripStatus.ongoing,
    );

    final completedTrip = Trip(
      id: 't2',
      vehicleId: 'EV-102',
      startGeofenceId: 'Hub A',
      endGeofenceId: 'Hub B',
      startTime: now.subtract(const Duration(hours: 2)),
      endTime: now.subtract(const Duration(hours: 1)),
      distanceKm: 22.5,
      maxSpeedKmh: 65.0,
      averageSocUsed: 15.0,
      status: TripStatus.completed,
    );

    setUp(() {
      tripRepo = MockTripRepoPresentation();
      tripRepo.tripList = [ongoingTrip, completedTrip];

      vehicleRepo = MockVehicleRepoTrips();
      getAllTripsUseCase = GetAllTripsUseCase(tripRepo);

      cubit = TripsCubit(
        tripRepository: tripRepo,
        vehicleRepository: vehicleRepo,
        getAllTripsUseCase: getAllTripsUseCase,
      );
    });

    tearDown(() {
      cubit.close();
    });

    test('1. Initial state is TripsInitial', () {
      expect(cubit.state, equals(TripsInitial()));
    });

    test('2. loadTrips emits Loading then Loaded with ongoing and completed trips separated', () async {
      await cubit.loadTrips();

      expect(cubit.state, isA<TripsLoaded>());
      final loaded = cubit.state as TripsLoaded;
      expect(loaded.allTrips.length, 2);
      expect(loaded.ongoingTrips.length, 1);
      expect(loaded.completedTrips.length, 1);
      expect(loaded.ongoingTrips.first.vehicleId, 'EV-101');
      expect(loaded.completedTrips.first.vehicleId, 'EV-102');
    });
  });
}
