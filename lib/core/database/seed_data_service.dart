import '../../features/fleet/domain/usecases/process_telemetry_batch.dart';
import '../../features/geofences/domain/usecases/create_geofence.dart';
import 'duckdb_client.dart';
import 'seed_data_generator.dart';

class SeedDataService {
  final DuckDbClient dbClient;
  final ProcessTelemetryBatchUseCase processTelemetryBatchUseCase;
  final CreateGeofenceUseCase createGeofenceUseCase;

  SeedDataService({
    required this.dbClient,
    required this.processTelemetryBatchUseCase,
    required this.createGeofenceUseCase,
  });

  /// Seeds DuckDB with 500 vehicles and initial geofences if empty.
  Future<void> seedIfEmpty({int vehicleCount = 500}) async {
    final vehicleCheck = await dbClient.query(
      'SELECT COUNT(*) as count FROM vehicles;',
    );
    final count = (vehicleCheck.first['count'] as num?)?.toInt() ?? 0;

    if (count == 0) {
      // Seed geofences
      final seedGeofences = SeedDataGenerator.generateSeedGeofences();
      for (final geofence in seedGeofences) {
        await createGeofenceUseCase(geofence);
      }

      // Seed 500 vehicles with telemetry
      final seedTelemetry = SeedDataGenerator.generateSeedTelemetry(
        vehicleCount: vehicleCount,
      );
      await processTelemetryBatchUseCase(
        ProcessTelemetryBatchParams(seedTelemetry),
      );
    }
  }
}
