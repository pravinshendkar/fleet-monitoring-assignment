import '../entities/fleet_summary.dart';
import '../entities/vehicle.dart';

abstract class VehicleRepository {
  Future<List<Vehicle>> getVehicles({
    VehicleStatus? statusFilter,
    double? maxSoc,
    String? searchQuery,
    int limit = 50,
    int offset = 0,
    bool ignoreStaleness = false,
  });

  Future<Vehicle?> getVehicleById(String vehicleId);

  Future<FleetSummary> getFleetSummary();

  Stream<void> watchDatabaseChanges();
}
