import '../../domain/entities/vehicle.dart';

class VehicleModel extends Vehicle {
  const VehicleModel({
    required super.id,
    required super.name,
    required super.status,
    super.lastLatitude,
    super.lastLongitude,
    super.lastLocationAt,
    super.lastSoc,
    super.lastSocAt,
    super.lastSpeed,
    super.lastSpeedAt,
    super.ignition,
    super.lastIgnitionAt,
    super.lastTemp,
    super.lastTempAt,
    super.lastOdometer,
    super.lastOdometerAt,
    required super.lastSeenAt,
  });

  /// Parses a timestamp value from DuckDB.
  ///
  /// DuckDB TIMESTAMP columns strip timezone information, so values stored
  /// as UTC come back as naive datetime strings (e.g. '2026-08-25 08:30:00').
  /// Since we consistently store UTC values, we must interpret these naive
  /// strings as UTC and then convert to local time.
  static DateTime parseUtcDateTime(dynamic val) {
    if (val == null) return DateTime.now();
    if (val is DateTime) {
      // If DuckDB returns a DateTime object, it may be naive (isUtc == false).
      // Since we store UTC, interpret it as UTC.
      if (!val.isUtc) {
        return DateTime.utc(
          val.year,
          val.month,
          val.day,
          val.hour,
          val.minute,
          val.second,
          val.millisecond,
          val.microsecond,
        ).toLocal();
      }
      return val.toLocal();
    }
    final str = val.toString().trim();
    if (str.isEmpty) return DateTime.now();

    // Normalize the string to ISO 8601 format
    var normalized = str.contains(' ') ? str.replaceAll(' ', 'T') : str;

    // If no timezone indicator is present, append 'Z' to treat as UTC
    // since we store all timestamps as UTC in DuckDB.
    if (!normalized.endsWith('Z') &&
        !normalized.contains('+') &&
        !RegExp(r'-\d{2}:\d{2}$').hasMatch(normalized)) {
      normalized = '${normalized}Z';
    }

    return DateTime.parse(normalized).toLocal();
  }

  factory VehicleModel.fromMap(
    Map<String, dynamic> map, {
    bool ignoreStaleness = false,
  }) {
    final lastSeen = parseUtcDateTime(map['last_seen_at']);
    final isStale =
        DateTime.now().difference(lastSeen) > const Duration(minutes: 10);

    final rawStatusStr = map['status']?.toString();
    final dbStatus = VehicleStatus.values.firstWhere(
      (e) => e.name == rawStatusStr,
      orElse: () => VehicleStatus.offline,
    );

    final status = (!ignoreStaleness && isStale)
        ? VehicleStatus.offline
        : dbStatus;

    return VehicleModel(
      id: map['vehicle_id'] as String,
      name: map['name'] as String,
      status: status,
      lastLatitude: map['last_latitude'] != null ? (map['last_latitude'] as num).toDouble() : null,
      lastLongitude: map['last_longitude'] != null ? (map['last_longitude'] as num).toDouble() : null,
      lastLocationAt: map['last_location_at'] != null ? parseUtcDateTime(map['last_location_at']) : null,
      lastSoc: map['last_soc'] != null ? (map['last_soc'] as num).toDouble() : null,
      lastSocAt: map['last_soc_at'] != null ? parseUtcDateTime(map['last_soc_at']) : null,
      lastSpeed: map['last_speed'] != null ? (map['last_speed'] as num).toDouble() : null,
      lastSpeedAt: map['last_speed_at'] != null ? parseUtcDateTime(map['last_speed_at']) : null,
      ignition: map['ignition'] != null
          ? ((map['ignition'] is bool)
              ? map['ignition'] as bool
              : (map['ignition'].toString() == '1' || map['ignition'].toString() == 'true'))
          : null,
      lastIgnitionAt: map['last_ignition_at'] != null ? parseUtcDateTime(map['last_ignition_at']) : null,
      lastTemp: map['last_temp'] != null ? (map['last_temp'] as num).toDouble() : null,
      lastTempAt: map['last_temp_at'] != null ? parseUtcDateTime(map['last_temp_at']) : null,
      lastOdometer: map['last_odometer'] != null ? (map['last_odometer'] as num).toDouble() : null,
      lastOdometerAt: map['last_odometer_at'] != null ? parseUtcDateTime(map['last_odometer_at']) : null,
      lastSeenAt: lastSeen,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vehicle_id': id,
      'name': name,
      'status': status.name,
      'last_latitude': lastLatitude,
      'last_longitude': lastLongitude,
      'last_location_at': lastLocationAt?.toUtc().toIso8601String(),
      'last_soc': lastSoc,
      'last_soc_at': lastSocAt?.toUtc().toIso8601String(),
      'last_speed': lastSpeed,
      'last_speed_at': lastSpeedAt?.toUtc().toIso8601String(),
      'ignition': ignition,
      'last_ignition_at': lastIgnitionAt?.toUtc().toIso8601String(),
      'last_temp': lastTemp,
      'last_temp_at': lastTempAt?.toUtc().toIso8601String(),
      'last_odometer': lastOdometer,
      'last_odometer_at': lastOdometerAt?.toUtc().toIso8601String(),
      'last_seen_at': lastSeenAt.toUtc().toIso8601String(),
    };
  }

  factory VehicleModel.fromEntity(Vehicle vehicle) {
    return VehicleModel(
      id: vehicle.id,
      name: vehicle.name,
      status: vehicle.status,
      lastLatitude: vehicle.lastLatitude,
      lastLongitude: vehicle.lastLongitude,
      lastLocationAt: vehicle.lastLocationAt,
      lastSoc: vehicle.lastSoc,
      lastSocAt: vehicle.lastSocAt,
      lastSpeed: vehicle.lastSpeed,
      lastSpeedAt: vehicle.lastSpeedAt,
      ignition: vehicle.ignition,
      lastIgnitionAt: vehicle.lastIgnitionAt,
      lastTemp: vehicle.lastTemp,
      lastTempAt: vehicle.lastTempAt,
      lastOdometer: vehicle.lastOdometer,
      lastOdometerAt: vehicle.lastOdometerAt,
      lastSeenAt: vehicle.lastSeenAt,
    );
  }
}
