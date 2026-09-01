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

class GetVehicleDetailsUseCase
    implements UseCase<VehicleDetailsResult, String> {
  final VehicleRepository vehicleRepository;
  final TelemetryRepository telemetryRepository;

  GetVehicleDetailsUseCase({
    required this.vehicleRepository,
    required this.telemetryRepository,
  });

  @override
  Future<VehicleDetailsResult> call(String vehicleId) async {
    final vehicle = await vehicleRepository.getVehicleById(vehicleId);
    final history = await telemetryRepository.getVehicleTelemetryHistory(
      vehicleId,
      limit: 100,
    );

    if (vehicle == null && history.isEmpty) {
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

    final latest = history.isNotEmpty ? history.first : null;
    final now = DateTime.now();
    bool isStale(DateTime? dt) =>
        dt == null || now.difference(dt) > const Duration(minutes: 10);

    bool useLatest(DateTime? vehicleSignalAt) {
      if (latest == null) return false;
      if (vehicleSignalAt == null) return true;
      return latest.eventTimestamp.isAfter(vehicleSignalAt);
    }

    final socVal = useLatest(vehicle?.lastSocAt)
        ? latest?.batteryLevel
        : (vehicle?.lastSoc ?? latest?.batteryLevel);
    final socTime = useLatest(vehicle?.lastSocAt)
        ? latest?.eventTimestamp
        : (vehicle?.lastSocAt ?? latest?.eventTimestamp);

    final speedVal = useLatest(vehicle?.lastSpeedAt)
        ? latest?.speed
        : (vehicle?.lastSpeed ?? latest?.speed);
    final speedTime = useLatest(vehicle?.lastSpeedAt)
        ? latest?.eventTimestamp
        : (vehicle?.lastSpeedAt ?? latest?.eventTimestamp);

    final tempVal = useLatest(vehicle?.lastTempAt)
        ? latest?.batteryTemp
        : (vehicle?.lastTemp ?? latest?.batteryTemp);
    final tempTime = useLatest(vehicle?.lastTempAt)
        ? latest?.eventTimestamp
        : (vehicle?.lastTempAt ?? latest?.eventTimestamp);

    final odoVal = useLatest(vehicle?.lastOdometerAt)
        ? latest?.odometerKm
        : (vehicle?.lastOdometer ?? latest?.odometerKm);
    final odoTime = useLatest(vehicle?.lastOdometerAt)
        ? latest?.eventTimestamp
        : (vehicle?.lastOdometerAt ?? latest?.eventTimestamp);

    final lastSeen = useLatest(vehicle?.lastSeenAt)
        ? latest?.eventTimestamp
        : (vehicle?.lastSeenAt ?? latest?.eventTimestamp);

    // SOC Signal
    SignalVerdict socVerdict;
    String? socAlert;
    if (socVal == null) {
      socVerdict = SignalVerdict.none;
    } else if (isStale(socTime)) {
      socVerdict = SignalVerdict.stale;
    } else if (socVal < 10.0) {
      socVerdict = SignalVerdict.alert;
      socAlert = 'Critical Low Battery (<10%)';
    } else if (socVal < 20.0) {
      socVerdict = SignalVerdict.alert;
      socAlert = 'Low Battery Warning (<20%)';
    } else {
      socVerdict = SignalVerdict.normal;
    }

    // Range Signal
    // Do not derive range artificially from SOC if missing
    final rangeSignal = _noneSignal('Range');

    // Speed Signal
    final speedVerdict = speedVal == null
        ? SignalVerdict.none
        : (isStale(speedTime)
            ? SignalVerdict.stale
            : SignalVerdict.normal);

    // Battery Temp Signal
    SignalVerdict tempVerdict;
    String? tempAlert;
    if (tempVal == null) {
      tempVerdict = SignalVerdict.none;
    } else if (isStale(tempTime)) {
      tempVerdict = SignalVerdict.stale;
    } else if (tempVal > 45.0) {
      tempVerdict = SignalVerdict.alert;
      tempAlert = 'Overheating (>45°C)';
    } else {
      tempVerdict = SignalVerdict.normal;
    }

    // Odometer & Last Ping
    final odoVerdict = odoVal == null
        ? SignalVerdict.none
        : (isStale(odoTime)
            ? SignalVerdict.stale
            : SignalVerdict.normal);
            
    final pingVerdict =
        isStale(lastSeen) ? SignalVerdict.stale : SignalVerdict.normal;

    // SOC History Points (Chronological ASC)
    final socPoints = history
        .where((p) => p.batteryLevel != null)
        .map((p) => SocPoint(timestamp: p.eventTimestamp, soc: p.batteryLevel!))
        .toList()
        .reversed
        .toList();

    return VehicleDetailsResult(
      vehicle: vehicle,
      socSignal: socVal == null
          ? _noneSignal('SOC')
          : SignalReading(
              label: 'SOC',
              displayValue: '${socVal.toStringAsFixed(0)}%',
              timestamp: socTime,
              verdict: socVerdict,
              alertMessage: socAlert,
            ),
      rangeSignal: rangeSignal,
      speedSignal: speedVal == null
          ? _noneSignal('Speed')
          : SignalReading(
              label: 'Speed',
              displayValue: '${speedVal.toStringAsFixed(1)} km/h',
              timestamp: speedTime,
              verdict: speedVerdict,
            ),
      tempSignal: tempVal == null
          ? _noneSignal('Battery Temp')
          : SignalReading(
              label: 'Battery Temp',
              displayValue: '${tempVal.toStringAsFixed(1)}°C',
              timestamp: tempTime,
              verdict: tempVerdict,
              alertMessage: tempAlert,
            ),
      odometerSignal: odoVal == null
          ? _noneSignal('Odometer')
          : SignalReading(
              label: 'Odometer',
              displayValue: '${odoVal.toStringAsFixed(1)} km',
              timestamp: odoTime,
              verdict: odoVerdict,
            ),
      lastPingSignal: lastSeen == null
          ? _noneSignal('Last Ping')
          : SignalReading(
              label: 'Last Ping',
              displayValue: _formatAge(lastSeen),
              timestamp: lastSeen,
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
    if (diff.isNegative) return 'Just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
