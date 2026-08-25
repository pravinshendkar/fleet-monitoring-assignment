import '../../../../core/database/database_event_bus.dart';
import '../../domain/entities/telemetry_packet.dart';
import '../../domain/repositories/telemetry_repository.dart';
import '../datasources/telemetry_local_datasource.dart';
import '../models/telemetry_packet_model.dart';

class TelemetryRepositoryImpl implements TelemetryRepository {
  final TelemetryLocalDataSource localDataSource;
  final DatabaseEventBus eventBus;

  TelemetryRepositoryImpl({
    required this.localDataSource,
    required this.eventBus,
  });

  @override
  Future<void> ingestBatch(List<TelemetryPacket> packets) async {
    final models = packets
        .map((p) => TelemetryPacketModel.fromEntity(p))
        .toList();
    await localDataSource.insertTelemetryBatch(models);
    eventBus.notify(DatabaseChangeEvent(table: DatabaseTable.telemetry));
  }

  @override
  Future<List<TelemetryPacket>> getVehicleTelemetryHistory(
    String vehicleId, {
    DateTime? startTime,
    DateTime? endTime,
    int limit = 100,
  }) async {
    return await localDataSource.getVehicleTelemetryHistory(
      vehicleId,
      startTime: startTime,
      endTime: endTime,
      limit: limit,
    );
  }

  @override
  Future<List<TelemetryPacket>> getSocHistory(
    String vehicleId, {
    DateTime? startTime,
    int limit = 100,
  }) async {
    return await localDataSource.getSocHistory(
      vehicleId,
      startTime: startTime,
      limit: limit,
    );
  }
}
