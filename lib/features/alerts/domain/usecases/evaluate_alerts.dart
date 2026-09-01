import '../../../../core/usecases/usecase.dart';
import '../../../fleet/domain/entities/telemetry_packet.dart';
import '../repositories/alert_repository.dart';
import '../../../fleet/domain/repositories/vehicle_repository.dart';

class EvaluateAlertsUseCase implements UseCase<void, List<TelemetryPacket>> {
  final AlertRepository repository;
  final VehicleRepository vehicleRepository;

  EvaluateAlertsUseCase(this.repository, this.vehicleRepository);

  @override
  Future<void> call(List<TelemetryPacket> packets) async {
    if (packets.isEmpty) return;

    // Group by vehicle to only evaluate the latest in this batch
    final latestInBatch = <String, TelemetryPacket>{};
    for (final p in packets) {
      final existing = latestInBatch[p.vehicleId];
      if (existing == null || p.eventTimestamp.isAfter(existing.eventTimestamp)) {
        latestInBatch[p.vehicleId] = p;
      }
    }

    final validPackets = <TelemetryPacket>[];
    for (final p in latestInBatch.values) {
      // Ignore stale telemetry packets (older than 10 mins)
      if (DateTime.now().difference(p.eventTimestamp) > const Duration(minutes: 10)) {
        continue;
      }

      // Check if this packet is out-of-order compared to the latest known vehicle state
      final vehicle = await vehicleRepository.getVehicleById(p.vehicleId);
      if (vehicle != null && vehicle.lastSeenAt.isAfter(p.eventTimestamp)) {
        continue; // This packet is older than a previously processed packet
      }

      validPackets.add(p);
    }

    if (validPackets.isEmpty) return;

    await repository.evaluateTelemetryAlerts(validPackets);
  }
}
