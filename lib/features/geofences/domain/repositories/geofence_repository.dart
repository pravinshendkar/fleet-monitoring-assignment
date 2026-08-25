import '../entities/geofence.dart';

abstract class GeofenceRepository {
  Future<List<Geofence>> getGeofences();
  Future<void> saveGeofence(Geofence geofence);
  Future<void> updateGeofence(Geofence geofence);
  Future<void> setGeofenceActiveStatus(String geofenceId, bool isActive);
  Future<Map<String, int>> getGeofenceVehicleCounts();
}
