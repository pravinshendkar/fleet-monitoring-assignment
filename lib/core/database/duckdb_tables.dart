class DuckDbTables {
  static const String createTelemetryPacketsTable = '''
    CREATE TABLE IF NOT EXISTS telemetry_packets (
      packet_id VARCHAR PRIMARY KEY,
      vehicle_id VARCHAR NOT NULL,
      event_timestamp TIMESTAMP NOT NULL,
      ingest_timestamp TIMESTAMP NOT NULL,
      latitude DOUBLE,
      longitude DOUBLE,
      speed DOUBLE,
      battery_level DOUBLE,
      battery_temp DOUBLE,
      odometer_km DOUBLE,
      ignition BOOLEAN,
      gps_accuracy DOUBLE
    );
  ''';

  static const String createTelemetryIndex = '''
    CREATE INDEX IF NOT EXISTS idx_telemetry_vehicle_timestamp 
    ON telemetry_packets (vehicle_id, event_timestamp);
  ''';

  static const String createVehiclesTable = '''
    CREATE TABLE IF NOT EXISTS vehicles (
      vehicle_id VARCHAR PRIMARY KEY,
      name VARCHAR NOT NULL,
      status VARCHAR NOT NULL,
      last_latitude DOUBLE,
      last_longitude DOUBLE,
      last_location_at TIMESTAMP,
      last_soc DOUBLE,
      last_soc_at TIMESTAMP,
      last_speed DOUBLE,
      last_speed_at TIMESTAMP,
      ignition BOOLEAN,
      last_ignition_at TIMESTAMP,
      last_temp DOUBLE,
      last_temp_at TIMESTAMP,
      last_odometer DOUBLE,
      last_odometer_at TIMESTAMP,
      last_seen_at TIMESTAMP NOT NULL
    );
  ''';

  static const String createVehiclesIndex = '''
    CREATE INDEX IF NOT EXISTS idx_vehicles_status_ping 
    ON vehicles (status, last_seen_at);
  ''';

  static const String createAlertsTable = '''
    CREATE TABLE IF NOT EXISTS alerts (
      alert_id VARCHAR PRIMARY KEY,
      vehicle_id VARCHAR NOT NULL,
      type VARCHAR NOT NULL,
      status VARCHAR NOT NULL,
      trigger_value DOUBLE NOT NULL,
      threshold DOUBLE NOT NULL,
      created_at TIMESTAMP NOT NULL,
      updated_at TIMESTAMP NOT NULL,
      dismissed_at TIMESTAMP,
      dismissal_reason VARCHAR
    );
  ''';

  static const String createAlertsIndex = '''
    CREATE INDEX IF NOT EXISTS idx_alerts_vehicle_status 
    ON alerts (vehicle_id, status);
  ''';

  static const String createGeofencesTable = '''
    CREATE TABLE IF NOT EXISTS geofences (
      geofence_id VARCHAR PRIMARY KEY,
      name VARCHAR NOT NULL,
      center_lat DOUBLE NOT NULL,
      center_lng DOUBLE NOT NULL,
      radius_meters DOUBLE NOT NULL,
      is_active BOOLEAN NOT NULL,
      created_at TIMESTAMP NOT NULL
    );
  ''';

  static const String createGeofenceEventsTable = '''
    CREATE TABLE IF NOT EXISTS geofence_events (
      event_id VARCHAR PRIMARY KEY,
      vehicle_id VARCHAR NOT NULL,
      geofence_id VARCHAR NOT NULL,
      event_type VARCHAR NOT NULL,
      event_timestamp TIMESTAMP NOT NULL,
      packet_id VARCHAR NOT NULL
    );
  ''';

  static const String createTripsTable = '''
    CREATE TABLE IF NOT EXISTS trips (
      trip_id VARCHAR PRIMARY KEY,
      vehicle_id VARCHAR NOT NULL,
      start_geofence_id VARCHAR NOT NULL,
      end_geofence_id VARCHAR,
      start_time TIMESTAMP NOT NULL,
      end_time TIMESTAMP,
      distance_km DOUBLE NOT NULL,
      max_speed DOUBLE NOT NULL,
      average_soc_used DOUBLE NOT NULL,
      status VARCHAR NOT NULL
    );
  ''';

  static const String createTripsIndex = '''
    CREATE INDEX IF NOT EXISTS idx_trips_vehicle_status 
    ON trips (vehicle_id, status, start_time);
  ''';
}
