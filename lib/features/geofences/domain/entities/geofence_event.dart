import 'package:equatable/equatable.dart';

enum GeofenceEventType { entry, exit }

class GeofenceEvent extends Equatable {
  final String id;
  final String vehicleId;
  final String geofenceId;
  final GeofenceEventType type;
  final DateTime eventTimestamp;
  final String packetId;

  const GeofenceEvent({
    required this.id,
    required this.vehicleId,
    required this.geofenceId,
    required this.type,
    required this.eventTimestamp,
    required this.packetId,
  });

  @override
  List<Object?> get props => [
        id,
        vehicleId,
        geofenceId,
        type,
        eventTimestamp,
        packetId,
      ];
}
