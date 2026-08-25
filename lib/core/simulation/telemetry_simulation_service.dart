import 'dart:async';
import 'dart:math';

import '../../features/fleet/domain/entities/telemetry_packet.dart';
import '../../features/fleet/domain/entities/vehicle.dart';
import '../../features/fleet/domain/repositories/vehicle_repository.dart';
import '../../features/fleet/domain/usecases/process_telemetry_batch.dart';

class TelemetrySimulationService {
  final VehicleRepository vehicleRepository;
  final ProcessTelemetryBatchUseCase processTelemetryBatchUseCase;

  Timer? _timer;
  final Random _rng = Random(42);

  bool _isDisposed = false;
  Future<void>? _activeTickFuture;

  TelemetrySimulationService({
    required this.vehicleRepository,
    required this.processTelemetryBatchUseCase,
  });

  bool get isRunning => _timer != null && _timer!.isActive;
  bool get isDisposed => _isDisposed;

  /// Starts the periodic simulation.
  /// Performs an immediate initial tick before starting the periodic timer.
  Future<void> startSimulation({
    Duration interval = const Duration(seconds: 30),
  }) async {
    if (_isDisposed) return;
    await stopSimulation();
    if (_isDisposed) return;

    // Perform an immediate simulation tick on start
    await simulateTick();

    if (_isDisposed) return;
    _timer = Timer.periodic(interval, (_) {
      if (!_isDisposed) {
        simulateTick();
      }
    });
  }

  /// Stops the periodic timer and awaits any in-flight simulation tick.
  Future<void> stopSimulation() async {
    _timer?.cancel();
    _timer = null;

    if (_activeTickFuture != null) {
      await _activeTickFuture;
    }
  }

  /// Executes a single simulation tick: fetches active vehicles using persisted DB status
  /// (ignoring 10-minute staleness override so stale active vehicles still receive pings),
  /// generates fresh telemetry pings for them, and processes them through
  /// the production processTelemetryBatchUseCase pipeline.
  ///
  /// If a simulation tick is already in progress, overlapping calls are safely skipped.
  Future<void> simulateTick({DateTime? tickTime}) async {
    if (_isDisposed || _activeTickFuture != null) return;

    final completer = Completer<void>();
    _activeTickFuture = completer.future;

    try {
      final now = tickTime ?? DateTime.now();

      if (_isDisposed) return;
      final movingVehicles = await vehicleRepository.getVehicles(
        statusFilter: VehicleStatus.moving,
        limit: 500,
        ignoreStaleness: true,
      );
      if (_isDisposed) return;

      final idleVehicles = await vehicleRepository.getVehicles(
        statusFilter: VehicleStatus.idle,
        limit: 500,
        ignoreStaleness: true,
      );
      if (_isDisposed) return;

      final stoppedVehicles = await vehicleRepository.getVehicles(
        statusFilter: VehicleStatus.stopped,
        limit: 500,
        ignoreStaleness: true,
      );
      if (_isDisposed) return;

      final activeVehicles = [
        ...movingVehicles,
        ...idleVehicles,
        ...stoppedVehicles,
      ];

      if (activeVehicles.isEmpty || _isDisposed) return;

      final freshPackets = <TelemetryPacket>[];

      for (final vehicle in activeVehicles) {
        double speed;
        bool ignition;
        double lat = vehicle.lastLatitude;
        double lng = vehicle.lastLongitude;
        double soc = vehicle.lastSoc;

        switch (vehicle.status) {
          case VehicleStatus.moving:
            speed = 20.0 + _rng.nextDouble() * 40.0;
            ignition = true;
            lat += (_rng.nextDouble() - 0.5) * 0.0002;
            lng += (_rng.nextDouble() - 0.5) * 0.0002;
            soc = (soc - 0.01).clamp(10.0, 100.0);
            break;

          case VehicleStatus.idle:
            speed = 0.0;
            ignition = true;
            soc = (soc - 0.005).clamp(10.0, 100.0);
            break;

          case VehicleStatus.stopped:
            speed = 0.0;
            ignition = false;
            break;

          case VehicleStatus.offline:
            continue;
        }

        freshPackets.add(
          TelemetryPacket(
            packetId: 'pkt_sim_${vehicle.id}_${now.millisecondsSinceEpoch}',
            vehicleId: vehicle.id,
            eventTimestamp: now,
            ingestTimestamp: now,
            latitude: lat,
            longitude: lng,
            speed: speed,
            batteryLevel: soc,
            batteryTemp: 28.0 + _rng.nextDouble() * 5.0,
            odometerKm: 5000.0,
            ignition: ignition,
            gpsAccuracy: 5.0,
          ),
        );
      }

      if (freshPackets.isNotEmpty && !_isDisposed) {
        await processTelemetryBatchUseCase(
          ProcessTelemetryBatchParams(freshPackets),
        );
      }
    } finally {
      if (!completer.isCompleted) {
        completer.complete();
      }
      if (_activeTickFuture == completer.future) {
        _activeTickFuture = null;
      }
    }
  }

  Future<void> dispose() async {
    _isDisposed = true;
    await stopSimulation();
  }
}
