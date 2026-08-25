import 'package:equatable/equatable.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/signal_reading.dart';
import '../entities/telemetry_packet.dart';
import '../entities/vehicle.dart';
import '../repositories/telemetry_repository.dart';
import '../repositories/vehicle_repository.dart';

class VehicleDetailsResult extends Equatable {
  final Vehicle? vehicle;
  final SignalReading socSignal;
  final SignalReading rangeSignal;
  final SignalReading speedSignal;
  final SignalReading tempSignal;
  final SignalReading odometerSignal;
  final SignalReading lastPingSignal;
  final List<SocPoint> socHistory;
  final List<TelemetryPacket> telemetryHistory;

  const VehicleDetailsResult({
    required this.vehicle,
    required this.socSignal,
    required this.rangeSignal,
    required this.speedSignal,
    required this.tempSignal,
    required this.odometerSignal,
    required this.lastPingSignal,
    required this.socHistory,
    required this.telemetryHistory,
  });

  @override
  List<Object?> get props => [
        vehicle,
        socSignal,
        rangeSignal,
        speedSignal,
        tempSignal,
        odometerSignal,
        lastPingSignal,
        socHistory,
        telemetryHistory,
      ];
}

class GetVehicleDetailsUseCase implements UseCase<VehicleDetailsResult, String> {
  final VehicleRepository vehicleRepository;
  final TelemetryRepository telemetryRepository;

  GetVehicleDetailsUseCase({
    required this.vehicleRepository,
    required this.telemetryRepository,
  });

  @override
  Future<VehicleDetailsResult> call(String vehicleId) async {
    final vehicle = await vehicleRepository.getVehicleById(vehicleId);
    final history = await telemetryRepository.getVehicleTelemetryHistory(vehicleId, limit: 100);

    if (history.isEmpty) {
      if (vehicle == null) {
        return VehicleDetailsResult(
          vehicle: null,
          socSignal: _noneSignal('SOC'),
          rangeSignal: _noneSignal('Range'),
          speedSignal: _noneSignal('Speed'),
          tempSignal: _noneSignal('Battery Temp'),
          odometerSignal: _noneSignal('Odometer'),
          lastPingSignal: _noneSignal('Last Ping'),
          socHistory: const [],
          telemetryHistory: const [],
        );
      }

      // If vehicle exists in DuckDB table but has no telemetry packet log yet
      final isStale = vehicle.isStale;
      final socVerdict = isStale
          ? SignalVerdict.stale
          : (vehicle.lastSoc < 20.0 ? SignalVerdict.alert : SignalVerdict.normal);

      return VehicleDetailsResult(
        vehicle: vehicle,
        socSignal: SignalReading(
          label: 'SOC',
          displayValue: '${vehicle.lastSoc.toStringAsFixed(0)}%',
          timestamp: vehicle.lastSeenAt,
          verdict: socVerdict,
          alertMessage: vehicle.lastSoc < 20.0 ? 'Low Battery' : null,
        ),
        rangeSignal: SignalReading(
          label: 'Range',
          displayValue: '${(vehicle.lastSoc * 3.0).round()} km',
          timestamp: vehicle.lastSeenAt,
          verdict: isStale ? SignalVerdict.stale : SignalVerdict.normal,
        ),
        speedSignal: _noneSignal('Speed'),
        tempSignal: _noneSignal('Battery Temp'),
        odometerSignal: _noneSignal('Odometer'),
        lastPingSignal: SignalReading(
          label: 'Last Ping',
          displayValue: _formatAge(vehicle.lastSeenAt),
          timestamp: vehicle.lastSeenAt,
          verdict: isStale ? SignalVerdict.stale : SignalVerdict.normal,
        ),
        socHistory: const [],
        telemetryHistory: const [],
      );
    }

    // Process from latest telemetry packet
    final latest = history.first;
    final now = DateTime.now();
    final isStale = now.difference(latest.eventTimestamp) > const Duration(minutes: 10);

    // SOC Signal
    SignalVerdict socVerdict;
    String? socAlert;
    if (isStale) {
      socVerdict = SignalVerdict.stale;
    } else if (latest.batteryLevel < 10.0) {
      socVerdict = SignalVerdict.alert;
      socAlert = 'Critical Low Battery (<10%)';
    } else if (latest.batteryLevel < 20.0) {
      socVerdict = SignalVerdict.alert;
      socAlert = 'Low Battery Warning (<20%)';
    } else {
      socVerdict = SignalVerdict.normal;
    }

    // Range Signal
    final rangeKm = (latest.batteryLevel * 3.0).round();
    final rangeVerdict = isStale ? SignalVerdict.stale : (latest.batteryLevel < 20.0 ? SignalVerdict.alert : SignalVerdict.normal);

    // Speed Signal
    final speedVerdict = isStale ? SignalVerdict.stale : SignalVerdict.normal;

    // Battery Temp Signal
    SignalVerdict tempVerdict;
    String? tempAlert;
    if (isStale) {
      tempVerdict = SignalVerdict.stale;
    } else if (latest.batteryTemp > 45.0) {
      tempVerdict = SignalVerdict.alert;
      tempAlert = 'Overheating (>45°C)';
    } else {
      tempVerdict = SignalVerdict.normal;
    }

    // Odometer & Last Ping
    final odoVerdict = isStale ? SignalVerdict.stale : SignalVerdict.normal;
    final pingVerdict = isStale ? SignalVerdict.stale : SignalVerdict.normal;

    // SOC History Points (Chronological ASC)
    final socPoints = history
        .map((p) => SocPoint(timestamp: p.eventTimestamp, soc: p.batteryLevel))
        .toList()
        .reversed
        .toList();

    return VehicleDetailsResult(
      vehicle: vehicle,
      socSignal: SignalReading(
        label: 'SOC',
        displayValue: '${latest.batteryLevel.toStringAsFixed(0)}%',
        timestamp: latest.eventTimestamp,
        verdict: socVerdict,
        alertMessage: socAlert,
      ),
      rangeSignal: SignalReading(
        label: 'Range',
        displayValue: '$rangeKm km',
        timestamp: latest.eventTimestamp,
        verdict: rangeVerdict,
      ),
      speedSignal: SignalReading(
        label: 'Speed',
        displayValue: '${latest.speed.toStringAsFixed(1)} km/h',
        timestamp: latest.eventTimestamp,
        verdict: speedVerdict,
      ),
      tempSignal: SignalReading(
        label: 'Battery Temp',
        displayValue: '${latest.batteryTemp.toStringAsFixed(1)}°C',
        timestamp: latest.eventTimestamp,
        verdict: tempVerdict,
        alertMessage: tempAlert,
      ),
      odometerSignal: SignalReading(
        label: 'Odometer',
        displayValue: '${latest.odometerKm.toStringAsFixed(1)} km',
        timestamp: latest.eventTimestamp,
        verdict: odoVerdict,
      ),
      lastPingSignal: SignalReading(
        label: 'Last Ping',
        displayValue: _formatAge(latest.eventTimestamp),
        timestamp: latest.eventTimestamp,
        verdict: pingVerdict,
      ),
      socHistory: socPoints,
      telemetryHistory: history,
    );
  }

  SignalReading _noneSignal(String label) {
    return SignalReading(
      label: label,
      displayValue: '—',
      timestamp: null,
      verdict: SignalVerdict.none,
    );
  }

  String _formatAge(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
