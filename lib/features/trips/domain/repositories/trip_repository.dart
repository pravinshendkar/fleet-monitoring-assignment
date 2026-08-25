import 'package:fleet_console/features/geofences/domain/entities/geofence_event.dart';
import '../entities/trip.dart';

abstract class TripRepository {
  Future<List<Trip>> getAllTrips();
  Future<List<Trip>> getVehicleTrips(String vehicleId);
  Future<void> processGeofenceTransitions(List<GeofenceEvent> events);
}
