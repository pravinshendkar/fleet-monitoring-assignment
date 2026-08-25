import '../../../../core/database/database_event_bus.dart';
import '../../../geofences/domain/entities/geofence_event.dart';
import '../../domain/entities/trip.dart';
import '../../domain/repositories/trip_repository.dart';
import '../datasources/trip_local_datasource.dart';

class TripRepositoryImpl implements TripRepository {
  final TripLocalDataSource localDataSource;
  final DatabaseEventBus eventBus;

  TripRepositoryImpl({required this.localDataSource, required this.eventBus});

  @override
  Future<List<Trip>> getAllTrips() async {
    return await localDataSource.getAllTrips();
  }

  @override
  Future<List<Trip>> getVehicleTrips(String vehicleId) async {
    return await localDataSource.getVehicleTrips(vehicleId);
  }

  @override
  Future<void> processGeofenceTransitions(List<GeofenceEvent> events) async {
    await localDataSource.processGeofenceTransitions(events);
    eventBus.notify(DatabaseChangeEvent(table: DatabaseTable.trips));
  }
}
