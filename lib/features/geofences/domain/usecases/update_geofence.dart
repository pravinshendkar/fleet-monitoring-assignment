import '../../../../core/usecases/usecase.dart';
import '../entities/geofence.dart';
import '../repositories/geofence_repository.dart';

class UpdateGeofenceUseCase implements UseCase<void, Geofence> {
  final GeofenceRepository repository;

  UpdateGeofenceUseCase(this.repository);

  @override
  Future<void> call(Geofence geofence) async {
    _validate(geofence);
    await repository.updateGeofence(geofence);
  }

  void _validate(Geofence geofence) {
    if (geofence.name.trim().isEmpty) {
      throw ArgumentError('Geofence name cannot be empty.');
    }
    if (geofence.centerLat < -90.0 || geofence.centerLat > 90.0) {
      throw ArgumentError('Latitude must be between -90 and 90 degrees.');
    }
    if (geofence.centerLng < -180.0 || geofence.centerLng > 180.0) {
      throw ArgumentError('Longitude must be between -180 and 180 degrees.');
    }
    if (geofence.radiusMeters <= 0.0) {
      throw ArgumentError('Radius must be greater than 0 meters.');
    }
  }
}
