import '../../../../core/database/duckdb_client.dart';
import '../../domain/entities/fleet_summary.dart';
import '../../domain/entities/vehicle.dart';
import '../models/vehicle_model.dart';

abstract class VehicleLocalDataSource {
  Future<List<VehicleModel>> getVehicles({
    VehicleStatus? statusFilter,
    double? maxSoc,
    String? searchQuery,
    int limit = 50,
    int offset = 0,
  });

  Future<VehicleModel?> getVehicleById(String vehicleId);

  Future<FleetSummary> getFleetSummary();
}

class VehicleLocalDataSourceImpl implements VehicleLocalDataSource {
  final DuckDbClient dbClient;

  VehicleLocalDataSourceImpl({required this.dbClient});

  @override
  Future<List<VehicleModel>> getVehicles({
    VehicleStatus? statusFilter,
    double? maxSoc,
    String? searchQuery,
    int limit = 50,
    int offset = 0,
  }) async {
    var conditions = <String>[];

    if (statusFilter != null) {
      if (statusFilter == VehicleStatus.offline) {
        conditions.add("last_seen_at < (now() - INTERVAL 10 MINUTE)");
      } else {
        conditions.add(
          "status = '${statusFilter.name}' AND last_seen_at >= (now() - INTERVAL 10 MINUTE)",
        );
      }
    }

    if (maxSoc != null) {
      conditions.add("last_soc <= $maxSoc");
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final cleanQuery = searchQuery.replaceAll("'", "''");
      conditions.add(
        "(vehicle_id LIKE '%$cleanQuery%' OR name LIKE '%$cleanQuery%')",
      );
    }

    final whereClause = conditions.isNotEmpty
        ? "WHERE ${conditions.join(' AND ')}"
        : "";

    final sql =
        '''
      SELECT * FROM vehicles
      $whereClause
      ORDER BY name ASC
      LIMIT $limit OFFSET $offset;
    ''';

    final maps = await dbClient.query(sql);
    return maps.map((m) => VehicleModel.fromMap(m)).toList();
  }

  @override
  Future<VehicleModel?> getVehicleById(String vehicleId) async {
    final cleanId = vehicleId.replaceAll("'", "''");
    final sql = "SELECT * FROM vehicles WHERE vehicle_id = '$cleanId' LIMIT 1;";
    final maps = await dbClient.query(sql);
    if (maps.isEmpty) return null;
    return VehicleModel.fromMap(maps.first);
  }

  @override
  Future<FleetSummary> getFleetSummary() async {
    final sql = '''
      SELECT
        COUNT(*) as total_vehicles,
        SUM(CASE WHEN last_seen_at >= (now() - INTERVAL 10 MINUTE) AND status = 'moving' THEN 1 ELSE 0 END) as moving_count,
        SUM(CASE WHEN last_seen_at >= (now() - INTERVAL 10 MINUTE) AND status = 'idle' THEN 1 ELSE 0 END) as idle_count,
        SUM(CASE WHEN last_seen_at >= (now() - INTERVAL 10 MINUTE) AND status = 'stopped' THEN 1 ELSE 0 END) as stopped_count,
        SUM(CASE WHEN last_seen_at < (now() - INTERVAL 10 MINUTE) THEN 1 ELSE 0 END) as offline_count,
        SUM(CASE WHEN last_soc <= 20.0 THEN 1 ELSE 0 END) as low_battery_count
      FROM vehicles;
    ''';

    final maps = await dbClient.query(sql);
    if (maps.isEmpty) {
      return const FleetSummary(
        totalVehicles: 0,
        movingCount: 0,
        idleCount: 0,
        stoppedCount: 0,
        offlineCount: 0,
        lowBatteryAlertCount: 0,
      );
    }

    final row = maps.first;
    return FleetSummary(
      totalVehicles: _parseInt(row['total_vehicles']),
      movingCount: _parseInt(row['moving_count']),
      idleCount: _parseInt(row['idle_count']),
      stoppedCount: _parseInt(row['stopped_count']),
      offlineCount: _parseInt(row['offline_count']),
      lowBatteryAlertCount: _parseInt(row['low_battery_count']),
    );
  }

  int _parseInt(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val.toInt();
    if (val is BigInt) return val.toInt();
    return int.tryParse(val.toString()) ?? 0;
  }
}
