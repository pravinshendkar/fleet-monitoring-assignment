import '../../../../core/usecases/usecase.dart';
import '../../../fleet/domain/entities/telemetry_packet.dart';
import '../repositories/alert_repository.dart';

class EvaluateAlertsUseCase implements UseCase<void, List<TelemetryPacket>> {
  final AlertRepository repository;

  EvaluateAlertsUseCase(this.repository);

  @override
  Future<void> call(List<TelemetryPacket> packets) async {
    if (packets.isEmpty) return;

    // Ignore stale telemetry packets (older than 10 mins relative to current time)
    final now = DateTime.now();
    final freshPackets = packets.where((p) {
      return now.difference(p.eventTimestamp) <= const Duration(minutes: 10);
    }).toList();

    if (freshPackets.isEmpty) return;

    await repository.evaluateTelemetryAlerts(freshPackets);
  }
}
