import '../../domain/entities/vehicle.dart';

class VehicleModel extends Vehicle {
  const VehicleModel({
    required super.id,
    required super.name,
    required super.status,
    required super.lastLatitude,
    required super.lastLongitude,
    required super.lastSoc,
    required super.lastSeenAt,
    required super.ignition,
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
      lastLatitude: (map['last_latitude'] as num).toDouble(),
      lastLongitude: (map['last_longitude'] as num).toDouble(),
      lastSoc: (map['last_soc'] as num).toDouble(),
      lastSeenAt: lastSeen,
      ignition: (map['ignition'] is bool)
          ? map['ignition'] as bool
          : (map['ignition'].toString() == '1' ||
                map['ignition'].toString() == 'true'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vehicle_id': id,
      'name': name,
      'status': status.name,
      'last_latitude': lastLatitude,
      'last_longitude': lastLongitude,
      'last_soc': lastSoc,
      'last_seen_at': lastSeenAt.toUtc().toIso8601String(),
      'ignition': ignition,
    };
  }

  factory VehicleModel.fromEntity(Vehicle vehicle) {
    return VehicleModel(
      id: vehicle.id,
      name: vehicle.name,
      status: vehicle.status,
      lastLatitude: vehicle.lastLatitude,
      lastLongitude: vehicle.lastLongitude,
      lastSoc: vehicle.lastSoc,
      lastSeenAt: vehicle.lastSeenAt,
      ignition: vehicle.ignition,
    );
  }
}
