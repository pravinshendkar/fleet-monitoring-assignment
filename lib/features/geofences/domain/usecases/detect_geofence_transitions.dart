import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/geo_utils.dart';
import '../../../fleet/domain/entities/telemetry_packet.dart';
import '../entities/geofence_event.dart';
import '../repositories/geofence_repository.dart';
import '../../../fleet/domain/repositories/vehicle_repository.dart';

class DetectGeofenceTransitionsParams {
  final List<TelemetryPacket> packets;
  final Map<String, Set<String>>
  activeVehicleGeofences; // (vehicleId -> Set of geofenceIds currently inside)

  DetectGeofenceTransitionsParams({
    required this.packets,
    this.activeVehicleGeofences = const {},
  });
}

class DetectGeofenceTransitionsUseCase
    implements UseCase<List<GeofenceEvent>, DetectGeofenceTransitionsParams> {
  final GeofenceRepository geofenceRepository;
  final VehicleRepository vehicleRepository;

  DetectGeofenceTransitionsUseCase(this.geofenceRepository, this.vehicleRepository);

  @override
  Future<List<GeofenceEvent>> call(
    DetectGeofenceTransitionsParams params,
  ) async {
    if (params.packets.isEmpty) return [];

    final activeGeofences = await geofenceRepository.getGeofences();
    final geofences = activeGeofences.where((g) => g.isActive).toList();
    if (geofences.isEmpty) return [];

    // Filter out inaccurate GPS readings or partial updates, and sort by eventTimestamp ASC
    final validPackets =
        params.packets.where((p) => p.latitude != null && p.longitude != null && (p.gpsAccuracy ?? 100.0) <= 50.0).toList()
          ..sort((a, b) => a.eventTimestamp.compareTo(b.eventTimestamp));

    // Drop out-of-order packets relative to the previously known state
    final chronologicalPackets = <TelemetryPacket>[];
    for (final p in validPackets) {
      final vehicle = await vehicleRepository.getVehicleById(p.vehicleId);
      if (vehicle != null && vehicle.lastSeenAt.isAfter(p.eventTimestamp)) {
        continue; // Skip late arriving telemetry for transition detection
      }
      chronologicalPackets.add(p);
    }

    final detectedEvents = <GeofenceEvent>[];
    // Tracking state: vehicleId -> geofenceId -> consecutive count state
    final vehicleInsideState = <String, Set<String>>{};
    final consecutiveInsideCounts = <String, Map<String, int>>{};
    final consecutiveOutsideCounts = <String, Map<String, int>>{};

    params.activeVehicleGeofences.forEach((vid, gSet) {
      vehicleInsideState[vid] = Set.from(gSet);
    });

    for (final packet in chronologicalPackets) {
      final insideSet = vehicleInsideState.putIfAbsent(
        packet.vehicleId,
        () => <String>{},
      );
      final insideCounts = consecutiveInsideCounts.putIfAbsent(
        packet.vehicleId,
        () => <String, int>{},
      );
      final outsideCounts = consecutiveOutsideCounts.putIfAbsent(
        packet.vehicleId,
        () => <String, int>{},
      );

      for (final geofence in geofences) {
        final distance = GeoUtils.calculateDistanceMeters(
          packet.latitude!,
          packet.longitude!,
          geofence.centerLat,
          geofence.centerLng,
        );

        final isCurrentlyInside = insideSet.contains(geofence.id);
        final isWithinRadius = distance <= geofence.radiusMeters;
        // Hysteresis buffer for EXIT: must be outside radius + 50m
        final isOutsideBuffer = distance > (geofence.radiusMeters + 50.0);

        if (!isCurrentlyInside) {
          if (isWithinRadius) {
            final count = (insideCounts[geofence.id] ?? 0) + 1;
            insideCounts[geofence.id] = count;

            if (count >= 2) {
              // Confirmed ENTRY after 2 consecutive inside readings
              insideSet.add(geofence.id);
              insideCounts[geofence.id] = 0;
              outsideCounts[geofence.id] = 0;

              detectedEvents.add(
                GeofenceEvent(
                  id: 'evt_entry_${packet.vehicleId}_${geofence.id}_${packet.packetId}',
                  vehicleId: packet.vehicleId,
                  geofenceId: geofence.id,
                  type: GeofenceEventType.entry,
                  eventTimestamp: packet.eventTimestamp,
                  packetId: packet.packetId,
                ),
              );
            }
          } else {
            insideCounts[geofence.id] = 0;
          }
        } else {
          if (isOutsideBuffer) {
            final count = (outsideCounts[geofence.id] ?? 0) + 1;
            outsideCounts[geofence.id] = count;

            if (count >= 2) {
              // Confirmed EXIT after 2 consecutive outside buffer readings
              insideSet.remove(geofence.id);
              outsideCounts[geofence.id] = 0;
              insideCounts[geofence.id] = 0;

              detectedEvents.add(
                GeofenceEvent(
                  id: 'evt_exit_${packet.vehicleId}_${geofence.id}_${packet.packetId}',
                  vehicleId: packet.vehicleId,
                  geofenceId: geofence.id,
                  type: GeofenceEventType.exit,
                  eventTimestamp: packet.eventTimestamp,
                  packetId: packet.packetId,
                ),
              );
            }
          } else {
            outsideCounts[geofence.id] = 0;
          }
        }
      }
    }

    return detectedEvents;
  }
}
