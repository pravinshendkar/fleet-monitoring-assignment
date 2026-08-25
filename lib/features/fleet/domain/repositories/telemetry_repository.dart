import '../entities/telemetry_packet.dart';

abstract class TelemetryRepository {
  Future<void> ingestBatch(List<TelemetryPacket> packets);
  Future<List<TelemetryPacket>> getVehicleTelemetryHistory(
    String vehicleId, {
    DateTime? startTime,
    DateTime? endTime,
    int limit = 100,
  });
  Future<List<TelemetryPacket>> getSocHistory(
    String vehicleId, {
    DateTime? startTime,
    int limit = 100,
  });
}
