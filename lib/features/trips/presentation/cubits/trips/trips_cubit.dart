import 'dart:async';
import 'package:fleet_console/core/usecases/usecase.dart';
import 'package:fleet_console/features/fleet/domain/repositories/vehicle_repository.dart';
import 'package:fleet_console/features/trips/domain/entities/trip.dart';
import 'package:fleet_console/features/trips/domain/repositories/trip_repository.dart';
import 'package:fleet_console/features/trips/domain/usecases/get_all_trips.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'trips_state.dart';

class TripsCubit extends Cubit<TripsState> {
  final TripRepository tripRepository;
  final VehicleRepository vehicleRepository;
  final GetAllTripsUseCase getAllTripsUseCase;

  StreamSubscription? _dbSubscription;

  TripsCubit({
    required this.tripRepository,
    required this.vehicleRepository,
    required this.getAllTripsUseCase,
  }) : super(TripsInitial()) {
    _listenToDatabaseChanges();
  }

  void _listenToDatabaseChanges() {
    _dbSubscription = vehicleRepository.watchDatabaseChanges().listen((_) {
      loadTrips();
    });
  }

  Future<void> loadTrips() async {
    if (state is! TripsLoaded) {
      emit(TripsLoading());
    }

    try {
      final list = await getAllTripsUseCase(NoParams());
      final ongoing = list
          .where((t) => t.status == TripStatus.ongoing)
          .toList();
      final completed = list
          .where((t) => t.status == TripStatus.completed)
          .toList();

      emit(
        TripsLoaded(
          allTrips: list,
          ongoingTrips: ongoing,
          completedTrips: completed,
        ),
      );
    } catch (e) {
      emit(TripsError('Failed to load trips: ${e.toString()}'));
    }
  }

  @override
  Future<void> close() {
    _dbSubscription?.cancel();
    return super.close();
  }
}
