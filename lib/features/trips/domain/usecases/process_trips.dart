import '../../../../core/usecases/usecase.dart';
import '../../../geofences/domain/entities/geofence_event.dart';
import '../repositories/trip_repository.dart';

class ProcessTripsParams {
  final List<GeofenceEvent> events;

  ProcessTripsParams(this.events);
}

class ProcessTripsUseCase implements UseCase<void, ProcessTripsParams> {
  final TripRepository repository;

  ProcessTripsUseCase(this.repository);

  @override
  Future<void> call(ProcessTripsParams params) async {
    if (params.events.isEmpty) return;

    // Idempotent processing of geofence transitions
    await repository.processGeofenceTransitions(params.events);
  }
}
