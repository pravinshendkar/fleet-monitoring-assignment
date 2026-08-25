import '../../../../core/database/duckdb_client.dart';
import '../models/geofence_model.dart';

abstract class GeofenceLocalDataSource {
  Future<List<GeofenceModel>> getGeofences();
  Future<void> saveGeofence(GeofenceModel geofence);
  Future<void> updateGeofence(GeofenceModel geofence);
  Future<void> setGeofenceActiveStatus(String geofenceId, bool isActive);
  Future<Map<String, int>> getGeofenceVehicleCounts();
}

class GeofenceLocalDataSourceImpl implements GeofenceLocalDataSource {
  final DuckDbClient dbClient;

  GeofenceLocalDataSourceImpl({required this.dbClient});

  @override
  Future<List<GeofenceModel>> getGeofences() async {
    const sql = '''
      SELECT * FROM geofences ORDER BY created_at DESC;
    ''';
    final maps = await dbClient.query(sql);
    final counts = await getGeofenceVehicleCounts();

    return maps.map((m) {
      final model = GeofenceModel.fromMap(m);
      final count = counts[model.id] ?? 0;
      return model.copyWith(activeVehicleCount: count);
    }).toList();
  }

  @override
  Future<void> saveGeofence(GeofenceModel geofence) async {
    final cleanId = geofence.id.replaceAll("'", "''");
    final cleanName = geofence.name.replaceAll("'", "''");
    final createdAt = geofence.createdAt.toIso8601String();

    final sql =
        '''
      INSERT INTO geofences (
        geofence_id, name, center_lat, center_lng, radius_meters, is_active, created_at
      ) VALUES (
        '$cleanId', '$cleanName', ${geofence.centerLat}, ${geofence.centerLng}, ${geofence.radiusMeters}, ${geofence.isActive}, '$createdAt'
      )
      ON CONFLICT (geofence_id) DO UPDATE SET
        name = EXCLUDED.name,
        center_lat = EXCLUDED.center_lat,
        center_lng = EXCLUDED.center_lng,
        radius_meters = EXCLUDED.radius_meters,
        is_active = EXCLUDED.is_active;
    ''';
    await dbClient.execute(sql);
  }

  @override
  Future<void> updateGeofence(GeofenceModel geofence) async {
    await saveGeofence(geofence);
  }

  @override
  Future<void> setGeofenceActiveStatus(String geofenceId, bool isActive) async {
    final cleanId = geofenceId.replaceAll("'", "''");
    final sql =
        '''
      UPDATE geofences
      SET is_active = $isActive
      WHERE geofence_id = '$cleanId';
    ''';
    await dbClient.execute(sql);
  }

  @override
  Future<Map<String, int>> getGeofenceVehicleCounts() async {
    // Calculates vehicle count inside active geofences dynamically via SQL
    const geofenceSql = "SELECT * FROM geofences WHERE is_active = true;";
    final geofenceMaps = await dbClient.query(geofenceSql);
    if (geofenceMaps.isEmpty) return {};

    const vehicleSql =
        "SELECT vehicle_id, last_latitude, last_longitude FROM vehicles WHERE last_seen_at >= (now() - INTERVAL 5 MINUTE);";
    final vehicleMaps = await dbClient.query(vehicleSql);

    final result = <String, int>{};

    for (final gMap in geofenceMaps) {
      final gId = gMap['geofence_id'] as String;
      final cLat = (gMap['center_lat'] as num).toDouble();
      final cLng = (gMap['center_lng'] as num).toDouble();
      final rMeters = (gMap['radius_meters'] as num).toDouble();

      int insideCount = 0;
      for (final vMap in vehicleMaps) {
        final vLat = (vMap['last_latitude'] as num).toDouble();
        final vLng = (vMap['last_longitude'] as num).toDouble();

        if (_isWithinRadius(vLat, vLng, cLat, cLng, rMeters)) {
          insideCount++;
        }
      }
      result[gId] = insideCount;
    }

    return result;
  }

  bool _isWithinRadius(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
    double radiusMeters,
  ) {
    // Distance check helper
    final dLat = (lat2 - lat1) * 111000.0;
    final dLng = (lng2 - lng1) * 111000.0 * 0.8; // Approximate scaling
    return (dLat * dLat + dLng * dLng) <= (radiusMeters * radiusMeters);
  }
}
