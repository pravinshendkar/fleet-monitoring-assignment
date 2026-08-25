import '../../../../core/usecases/usecase.dart';
import '../../../alerts/domain/usecases/evaluate_alerts.dart';
import '../../../geofences/domain/usecases/detect_geofence_transitions.dart';
import '../../../trips/domain/usecases/process_trips.dart';
import '../entities/telemetry_packet.dart';
import '../repositories/telemetry_repository.dart';

class ProcessTelemetryBatchParams {
  final List<TelemetryPacket> packets;

  ProcessTelemetryBatchParams(this.packets);
}

class ProcessTelemetryBatchUseCase implements UseCase<void, ProcessTelemetryBatchParams> {
  final TelemetryRepository telemetryRepository;
  final EvaluateAlertsUseCase evaluateAlertsUseCase;
  final DetectGeofenceTransitionsUseCase detectGeofenceTransitionsUseCase;
  final ProcessTripsUseCase processTripsUseCase;

  ProcessTelemetryBatchUseCase({
    required this.telemetryRepository,
    required this.evaluateAlertsUseCase,
    required this.detectGeofenceTransitionsUseCase,
    required this.processTripsUseCase,
  });

  @override
  Future<void> call(ProcessTelemetryBatchParams params) async {
    if (params.packets.isEmpty) return;

    // 1. Sort packets chronologically by eventTimestamp
    final sortedPackets = List<TelemetryPacket>.from(params.packets)
      ..sort((a, b) => a.eventTimestamp.compareTo(b.eventTimestamp));

    // 2. Persist telemetry batch in DuckDB
    await telemetryRepository.ingestBatch(sortedPackets);

    // 3. Orchestrate alert evaluation
    await evaluateAlertsUseCase(sortedPackets);

    // 4. Orchestrate geofence transition detection
    final transitionEvents = await detectGeofenceTransitionsUseCase(
      DetectGeofenceTransitionsParams(packets: sortedPackets),
    );

    // 5. Orchestrate idempotent trip creation / completion
    if (transitionEvents.isNotEmpty) {
      await processTripsUseCase(ProcessTripsParams(transitionEvents));
    }
  }
}
