import '../../../../core/database/database_event_bus.dart';
import '../../domain/entities/geofence.dart';
import '../../domain/repositories/geofence_repository.dart';
import '../datasources/geofence_local_datasource.dart';
import '../models/geofence_model.dart';

class GeofenceRepositoryImpl implements GeofenceRepository {
  final GeofenceLocalDataSource localDataSource;
  final DatabaseEventBus eventBus;

  GeofenceRepositoryImpl({
    required this.localDataSource,
    required this.eventBus,
  });

  @override
  Future<List<Geofence>> getGeofences() async {
    return await localDataSource.getGeofences();
  }

  @override
  Future<void> saveGeofence(Geofence geofence) async {
    final model = GeofenceModel.fromEntity(geofence);
    await localDataSource.saveGeofence(model);
    eventBus.notify(
      DatabaseChangeEvent(
        table: DatabaseTable.geofences,
        entityId: geofence.id,
      ),
    );
  }

  @override
  Future<void> updateGeofence(Geofence geofence) async {
    final model = GeofenceModel.fromEntity(geofence);
    await localDataSource.updateGeofence(model);
    eventBus.notify(
      DatabaseChangeEvent(
        table: DatabaseTable.geofences,
        entityId: geofence.id,
      ),
    );
  }

  @override
  Future<void> setGeofenceActiveStatus(String geofenceId, bool isActive) async {
    await localDataSource.setGeofenceActiveStatus(geofenceId, isActive);
    eventBus.notify(
      DatabaseChangeEvent(table: DatabaseTable.geofences, entityId: geofenceId),
    );
  }

  @override
  Future<Map<String, int>> getGeofenceVehicleCounts() async {
    return await localDataSource.getGeofenceVehicleCounts();
  }
}
