import '../../domain/entities/telemetry_packet.dart';

class TelemetryPacketModel extends TelemetryPacket {
  const TelemetryPacketModel({
    required super.packetId,
    required super.vehicleId,
    required super.eventTimestamp,
    required super.ingestTimestamp,
    required super.latitude,
    required super.longitude,
    required super.speed,
    required super.batteryLevel,
    required super.batteryTemp,
    required super.odometerKm,
    required super.ignition,
    super.gpsAccuracy = 5.0,
  });

  factory TelemetryPacketModel.fromMap(Map<String, dynamic> map) {
    return TelemetryPacketModel(
      packetId: map['packet_id'] as String,
      vehicleId: map['vehicle_id'] as String,
      eventTimestamp: map['event_timestamp'] is DateTime
          ? (map['event_timestamp'] as DateTime).toUtc()
          : DateTime.parse(map['event_timestamp'].toString()).toUtc(),
      ingestTimestamp: map['ingest_timestamp'] is DateTime
          ? (map['ingest_timestamp'] as DateTime).toUtc()
          : DateTime.parse(map['ingest_timestamp'].toString()).toUtc(),
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      speed: (map['speed'] as num).toDouble(),
      batteryLevel: (map['battery_level'] as num).toDouble(),
      batteryTemp: (map['battery_temp'] as num).toDouble(),
      odometerKm: (map['odometer_km'] as num).toDouble(),
      ignition: (map['ignition'] is bool)
          ? map['ignition'] as bool
          : (map['ignition'].toString() == '1' ||
                map['ignition'].toString() == 'true'),
      gpsAccuracy: map['gps_accuracy'] != null
          ? (map['gps_accuracy'] as num).toDouble()
          : 5.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'packet_id': packetId,
      'vehicle_id': vehicleId,
      'event_timestamp': eventTimestamp.toUtc().toIso8601String(),
      'ingest_timestamp': ingestTimestamp.toUtc().toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'speed': speed,
      'battery_level': batteryLevel,
      'battery_temp': batteryTemp,
      'odometer_km': odometerKm,
      'ignition': ignition,
      'gps_accuracy': gpsAccuracy,
    };
  }

  factory TelemetryPacketModel.fromEntity(TelemetryPacket packet) {
    return TelemetryPacketModel(
      packetId: packet.packetId,
      vehicleId: packet.vehicleId,
      eventTimestamp: packet.eventTimestamp,
      ingestTimestamp: packet.ingestTimestamp,
      latitude: packet.latitude,
      longitude: packet.longitude,
      speed: packet.speed,
      batteryLevel: packet.batteryLevel,
      batteryTemp: packet.batteryTemp,
      odometerKm: packet.odometerKm,
      ignition: packet.ignition,
      gpsAccuracy: packet.gpsAccuracy,
    );
  }
}
