import '../../../../core/database/database_event_bus.dart';
import '../../domain/entities/fleet_summary.dart';
import '../../domain/entities/vehicle.dart';
import '../../domain/repositories/vehicle_repository.dart';
import '../datasources/vehicle_local_datasource.dart';

class VehicleRepositoryImpl implements VehicleRepository {
  final VehicleLocalDataSource localDataSource;
  final DatabaseEventBus eventBus;

  VehicleRepositoryImpl({
    required this.localDataSource,
    required this.eventBus,
  });

  @override
  Future<List<Vehicle>> getVehicles({
    VehicleStatus? statusFilter,
    double? maxSoc,
    String? searchQuery,
    int limit = 50,
    int offset = 0,
  }) async {
    return await localDataSource.getVehicles(
      statusFilter: statusFilter,
      maxSoc: maxSoc,
      searchQuery: searchQuery,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<Vehicle?> getVehicleById(String vehicleId) async {
    return await localDataSource.getVehicleById(vehicleId);
  }

  @override
  Future<FleetSummary> getFleetSummary() async {
    return await localDataSource.getFleetSummary();
  }

  @override
  Stream<void> watchDatabaseChanges() {
    return eventBus.stream;
  }
}
