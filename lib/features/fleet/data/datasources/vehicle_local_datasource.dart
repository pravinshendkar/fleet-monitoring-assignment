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
    bool ignoreStaleness = false,
  });

  Future<VehicleModel?> getVehicleById(String vehicleId);

  Future<FleetSummary> getFleetSummary();
}

class VehicleLocalDataSourceImpl implements VehicleLocalDataSource {
  final DuckDbClient dbClient;

  VehicleLocalDataSourceImpl({required this.dbClient});

  /// Whether a vehicle's last_seen_at is stale (> 10 minutes ago).
  /// This is the SQL equivalent of the Dart isStale check.
  static const _staleCondition = "last_seen_at < (now() - INTERVAL 10 MINUTE)";

  /// Whether a vehicle's last_seen_at is recent (<= 10 minutes ago).
  static const _recentCondition =
      "last_seen_at >= (now() - INTERVAL 10 MINUTE)";

  @override
  Future<List<VehicleModel>> getVehicles({
    VehicleStatus? statusFilter,
    double? maxSoc,
    String? searchQuery,
    int limit = 50,
    int offset = 0,
    bool ignoreStaleness = false,
  }) async {
    var conditions = <String>[];

    // Status filtering uses the same business rule as Vehicle.calculateStatus():
    // - OFFLINE: last_seen_at > 10 minutes ago (stale)
    // - MOVING/IDLE/STOPPED: stored status AND last_seen_at <= 10 minutes ago
    // When ignoreStaleness is true (e.g. simulation service), query raw DB status without staleness condition.
    if (statusFilter != null) {
      if (!ignoreStaleness && statusFilter == VehicleStatus.offline) {
        conditions.add("($_staleCondition)");
      } else if (!ignoreStaleness) {
        conditions.add("status = '${statusFilter.name}' AND $_recentCondition");
      } else {
        conditions.add("status = '${statusFilter.name}'");
      }
    }

    if (maxSoc != null) {
      conditions.add("last_soc <= $maxSoc");
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final cleanQuery = searchQuery.replaceAll("'", "''");
      conditions.add(
        "(LOWER(vehicle_id) LIKE LOWER('%$cleanQuery%') "
        "OR LOWER(name) LIKE LOWER('%$cleanQuery%'))",
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
    return maps
        .map((m) => VehicleModel.fromMap(m, ignoreStaleness: ignoreStaleness))
        .toList();
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
    // Uses the same business rule as Vehicle.calculateStatus():
    // - If last_seen_at > 10 minutes ago → OFFLINE (regardless of stored status)
    // - Else → use the stored status (which was set by Vehicle.calculateStatus() at ingest)
    final sql =
        '''
      SELECT
        COUNT(*) as total_vehicles,
        SUM(CASE WHEN $_recentCondition AND status = 'moving' THEN 1 ELSE 0 END) as moving_count,
        SUM(CASE WHEN $_recentCondition AND status = 'idle' THEN 1 ELSE 0 END) as idle_count,
        SUM(CASE WHEN $_recentCondition AND status = 'stopped' THEN 1 ELSE 0 END) as stopped_count,
        SUM(CASE WHEN $_staleCondition THEN 1 ELSE 0 END) as offline_count,
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
