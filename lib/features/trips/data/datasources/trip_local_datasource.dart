import '../../../../core/database/duckdb_client.dart';
import '../../../../core/utils/geo_utils.dart';
import '../../../geofences/domain/entities/geofence_event.dart';
import '../models/trip_model.dart';

abstract class TripLocalDataSource {
  Future<List<TripModel>> getAllTrips();
  Future<List<TripModel>> getVehicleTrips(String vehicleId);
  Future<void> processGeofenceTransitions(List<GeofenceEvent> events);
}

class TripLocalDataSourceImpl implements TripLocalDataSource {
  final DuckDbClient dbClient;

  TripLocalDataSourceImpl({required this.dbClient});

  @override
  Future<List<TripModel>> getAllTrips() async {
    const sql = '''
      SELECT * FROM trips
      ORDER BY start_time DESC;
    ''';
    final maps = await dbClient.query(sql);
    return maps.map((m) => TripModel.fromMap(m)).toList();
  }

  @override
  Future<List<TripModel>> getVehicleTrips(String vehicleId) async {
    final cleanVid = vehicleId.replaceAll("'", "''");
    final sql = '''
      SELECT * FROM trips
      WHERE vehicle_id = '$cleanVid'
      ORDER BY start_time DESC;
    ''';
    final maps = await dbClient.query(sql);
    return maps.map((m) => TripModel.fromMap(m)).toList();
  }

  @override
  Future<void> processGeofenceTransitions(List<GeofenceEvent> events) async {
    if (events.isEmpty) return;

    // Sort events chronologically by original eventTimestamp ASC
    final sortedEvents = List<GeofenceEvent>.from(events)
      ..sort((a, b) => a.eventTimestamp.compareTo(b.eventTimestamp));

    for (final event in sortedEvents) {
      final eid = event.id.replaceAll("'", "''");
      final vid = event.vehicleId.replaceAll("'", "''");
      final gid = event.geofenceId.replaceAll("'", "''");
      final ts = event.eventTimestamp.toUtc().toIso8601String();
      final pid = event.packetId.replaceAll("'", "''");

      // 1. Idempotency Check via DuckDB geofence_events table
      final checkEventSql = "SELECT event_id FROM geofence_events WHERE event_id = '$eid';";
      final existingEvents = await dbClient.query(checkEventSql);
      if (existingEvents.isNotEmpty) {
        // Event already processed -> strictly idempotent skip!
        continue;
      }

      // Record geofence event in DuckDB
      final insertEventSql = '''
        INSERT INTO geofence_events (
          event_id, vehicle_id, geofence_id, event_type, event_timestamp, packet_id
        ) VALUES (
          '$eid', '$vid', '$gid', '${event.type.name}', '$ts', '$pid'
        )
        ON CONFLICT (event_id) DO NOTHING;
      ''';
      await dbClient.execute(insertEventSql);

      // 2. Process Trip State
      if (event.type == GeofenceEventType.exit) {
        // Check for existing active (ongoing) trip for this vehicle
        final activeTripSql = '''
          SELECT trip_id, start_time FROM trips
          WHERE vehicle_id = '$vid' AND status = 'ongoing'
          LIMIT 1;
        ''';
        final activeTripMaps = await dbClient.query(activeTripSql);

        if (activeTripMaps.isNotEmpty) {
          final activeTrip = activeTripMaps.first;
          final existingStartTs = DateTime.parse(activeTrip['start_time'].toString());

          if (event.eventTimestamp.isBefore(existingStartTs)) {
            // Late EXIT event revises existing trip's start boundary
            final tripId = activeTrip['trip_id'] as String;
            final updateSql = '''
              UPDATE trips
              SET start_geofence_id = '$gid',
                  start_time = '$ts'
              WHERE trip_id = '$tripId';
            ''';
            await dbClient.execute(updateSql);
            await _recalculateTripMetrics(tripId, vid, ts, null);
          }
          // Active trip already exists -> do NOT create duplicate active trip
        } else {
          // No active trip: create new ongoing trip
          final tripId = 'trip_${vid}_${event.eventTimestamp.millisecondsSinceEpoch}';
          final sql = '''
            INSERT INTO trips (
              trip_id, vehicle_id, start_geofence_id, start_time, distance_km, max_speed, average_soc_used, status
            ) VALUES (
              '$tripId', '$vid', '$gid', '$ts', 0.0, 0.0, 0.0, 'ongoing'
            )
            ON CONFLICT (trip_id) DO NOTHING;
          ''';
          await dbClient.execute(sql);
          await _recalculateTripMetrics(tripId, vid, ts, null);
        }
      } else if (event.type == GeofenceEventType.entry) {
        // Check ongoing trip first
        final ongoingTripSql = '''
          SELECT trip_id, start_time FROM trips
          WHERE vehicle_id = '$vid' AND status = 'ongoing'
          ORDER BY start_time DESC
          LIMIT 1;
        ''';
        final ongoingMaps = await dbClient.query(ongoingTripSql);

        if (ongoingMaps.isNotEmpty) {
          final ongoingTrip = ongoingMaps.first;
          final ongoingTripId = ongoingTrip['trip_id'] as String;
          final startTs = ongoingTrip['start_time'].toString();

          final updateSql = '''
            UPDATE trips
            SET end_geofence_id = '$gid',
                end_time = '$ts',
                status = 'completed'
            WHERE trip_id = '$ongoingTripId';
          ''';
          await dbClient.execute(updateSql);
          await _recalculateTripMetrics(ongoingTripId, vid, startTs, ts);
        } else {
          // Check if late ENTRY revises the completion boundary of the latest completed trip
          final latestTripSql = '''
            SELECT trip_id, start_time, end_time FROM trips
            WHERE vehicle_id = '$vid' AND status = 'completed'
            ORDER BY start_time DESC
            LIMIT 1;
          ''';
          final latestMaps = await dbClient.query(latestTripSql);
          if (latestMaps.isNotEmpty) {
            final latestTrip = latestMaps.first;
            final latestTripId = latestTrip['trip_id'] as String;
            final startTs = latestTrip['start_time'].toString();

            final updateSql = '''
              UPDATE trips
              SET end_geofence_id = '$gid',
                  end_time = '$ts'
              WHERE trip_id = '$latestTripId';
            ''';
            await dbClient.execute(updateSql);
            await _recalculateTripMetrics(latestTripId, vid, startTs, ts);
          }
        }
      }
    }
  }

  Future<void> _recalculateTripMetrics(
    String tripId,
    String vehicleId,
    String startTimeStr,
    String? endTimeStr,
  ) async {
    final endTimeClause = endTimeStr != null ? "AND event_timestamp <= '$endTimeStr'" : "";
    final sql = '''
      SELECT latitude, longitude, speed, battery_level
      FROM telemetry_packets
      WHERE vehicle_id = '$vehicleId'
        AND event_timestamp >= '$startTimeStr'
        $endTimeClause
      ORDER BY event_timestamp ASC;
    ''';
    final rows = await dbClient.query(sql);

    double distanceKm = 0.0;
    double maxSpeed = 0.0;
    double averageSocUsed = 0.0;

    if (rows.isNotEmpty) {
      for (int i = 0; i < rows.length; i++) {
        final s = (rows[i]['speed'] as num).toDouble();
        if (s > maxSpeed) maxSpeed = s;

        if (i > 0) {
          final lat1 = (rows[i - 1]['latitude'] as num).toDouble();
          final lng1 = (rows[i - 1]['longitude'] as num).toDouble();
          final lat2 = (rows[i]['latitude'] as num).toDouble();
          final lng2 = (rows[i]['longitude'] as num).toDouble();
          final dMeters = GeoUtils.calculateDistanceMeters(lat1, lng1, lat2, lng2);
          distanceKm += (dMeters / 1000.0);
        }
      }

      final startSoc = (rows.first['battery_level'] as num).toDouble();
      final endSoc = (rows.last['battery_level'] as num).toDouble();
      averageSocUsed = (startSoc - endSoc).clamp(0.0, 100.0);
    }

    final updateSql = '''
      UPDATE trips
      SET distance_km = $distanceKm,
          max_speed = $maxSpeed,
          average_soc_used = $averageSocUsed
      WHERE trip_id = '$tripId';
    ''';
    await dbClient.execute(updateSql);
  }
}
