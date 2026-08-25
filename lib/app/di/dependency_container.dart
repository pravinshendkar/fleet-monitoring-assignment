import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/database/database_event_bus.dart';
import '../../core/database/duckdb_client.dart';
import '../../core/database/seed_data_service.dart';
import '../../features/alerts/data/datasources/alert_local_datasource.dart';
import '../../features/alerts/data/repositories/alert_repository_impl.dart';
import '../../features/alerts/domain/repositories/alert_repository.dart';
import '../../features/alerts/domain/usecases/evaluate_alerts.dart';
import '../../features/alerts/domain/usecases/get_active_alerts.dart';
import '../../features/alerts/domain/usecases/undo_alert_dismissal.dart';
import '../../features/alerts/domain/usecases/update_alert_status.dart';
import '../../features/fleet/data/datasources/telemetry_local_datasource.dart';
import '../../features/fleet/data/datasources/vehicle_local_datasource.dart';
import '../../features/fleet/data/repositories/telemetry_repository_impl.dart';
import '../../features/fleet/data/repositories/vehicle_repository_impl.dart';
import '../../features/fleet/domain/repositories/telemetry_repository.dart';
import '../../features/fleet/domain/repositories/vehicle_repository.dart';
import '../../features/fleet/domain/usecases/get_fleet_summary.dart';
import '../../features/fleet/domain/usecases/get_vehicle_details.dart';
import '../../features/fleet/domain/usecases/get_vehicles.dart';
import '../../features/fleet/domain/usecases/process_telemetry_batch.dart';
import '../../features/geofences/data/datasources/geofence_local_datasource.dart';
import '../../features/geofences/data/repositories/geofence_repository_impl.dart';
import '../../features/geofences/domain/repositories/geofence_repository.dart';
import '../../features/geofences/domain/usecases/create_geofence.dart';
import '../../features/geofences/domain/usecases/deactivate_geofence.dart';
import '../../features/geofences/domain/usecases/detect_geofence_transitions.dart';
import '../../features/geofences/domain/usecases/get_active_geofences.dart';
import '../../features/geofences/domain/usecases/update_geofence.dart';
import '../../features/trips/data/datasources/trip_local_datasource.dart';
import '../../features/trips/data/repositories/trip_repository_impl.dart';
import '../../features/trips/domain/repositories/trip_repository.dart';
import '../../features/trips/domain/usecases/get_all_trips.dart';
import '../../features/trips/domain/usecases/get_vehicle_trips.dart';
import '../../features/trips/domain/usecases/process_trips.dart';

class DependencyContainer {
  final DuckDbClient dbClient;
  final DatabaseEventBus eventBus;

  static Future<String> resolvePlatformDatabasePath() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      return p.join(appDir.path, 'fleet_console.duckdb');
    } catch (_) {
      // Fallback for non-Flutter environments / unit tests without PathProvider mocking
      return 'fleet_console.duckdb';
    }
  }

  // Repositories (Domain Abstractions)
  final TelemetryRepository telemetryRepository;
  final VehicleRepository vehicleRepository;
  final AlertRepository alertRepository;
  final GeofenceRepository geofenceRepository;
  final TripRepository tripRepository;

  // Domain Use Cases
  final GetFleetSummaryUseCase getFleetSummaryUseCase;
  final GetVehiclesUseCase getVehiclesUseCase;
  final GetVehicleDetailsUseCase getVehicleDetailsUseCase;
  final ProcessTelemetryBatchUseCase processTelemetryBatchUseCase;

  final GetActiveAlertsUseCase getActiveAlertsUseCase;
  final EvaluateAlertsUseCase evaluateAlertsUseCase;
  final UpdateAlertStatusUseCase updateAlertStatusUseCase;
  final UndoAlertDismissalUseCase undoAlertDismissalUseCase;

  final CreateGeofenceUseCase createGeofenceUseCase;
  final UpdateGeofenceUseCase updateGeofenceUseCase;
  final DeactivateGeofenceUseCase deactivateGeofenceUseCase;
  final GetActiveGeofencesUseCase getActiveGeofencesUseCase;
  final DetectGeofenceTransitionsUseCase detectGeofenceTransitionsUseCase;

  final ProcessTripsUseCase processTripsUseCase;
  final GetVehicleTripsUseCase getVehicleTripsUseCase;
  final GetAllTripsUseCase getAllTripsUseCase;

  DependencyContainer._({
    required this.dbClient,
    required this.eventBus,
    required this.telemetryRepository,
    required this.vehicleRepository,
    required this.alertRepository,
    required this.geofenceRepository,
    required this.tripRepository,
    required this.getFleetSummaryUseCase,
    required this.getVehiclesUseCase,
    required this.getVehicleDetailsUseCase,
    required this.processTelemetryBatchUseCase,
    required this.getActiveAlertsUseCase,
    required this.evaluateAlertsUseCase,
    required this.updateAlertStatusUseCase,
    required this.undoAlertDismissalUseCase,
    required this.createGeofenceUseCase,
    required this.updateGeofenceUseCase,
    required this.deactivateGeofenceUseCase,
    required this.getActiveGeofencesUseCase,
    required this.detectGeofenceTransitionsUseCase,
    required this.processTripsUseCase,
    required this.getVehicleTripsUseCase,
    required this.getAllTripsUseCase,
  });

  static Future<DependencyContainer> create({
    String? dbPath,
    bool autoSeed = true,
  }) async {
    final resolvedPath = dbPath ?? await resolvePlatformDatabasePath();

    // 1. Core Infrastructure
    final dbClient = DuckDbClient(databasePath: resolvedPath);
    await dbClient.init();

    final eventBus = DatabaseEventBus();

    // 2. Data Sources
    final telemetryDS = TelemetryLocalDataSourceImpl(dbClient: dbClient);
    final vehicleDS = VehicleLocalDataSourceImpl(dbClient: dbClient);
    final alertDS = AlertLocalDataSourceImpl(dbClient: dbClient);
    final geofenceDS = GeofenceLocalDataSourceImpl(dbClient: dbClient);
    final tripDS = TripLocalDataSourceImpl(dbClient: dbClient);

    // 3. Repository Implementations bound to Domain Interfaces
    final TelemetryRepository telemetryRepo = TelemetryRepositoryImpl(
      localDataSource: telemetryDS,
      eventBus: eventBus,
    );
    final VehicleRepository vehicleRepo = VehicleRepositoryImpl(
      localDataSource: vehicleDS,
      eventBus: eventBus,
    );
    final AlertRepository alertRepo = AlertRepositoryImpl(
      localDataSource: alertDS,
      eventBus: eventBus,
    );
    final GeofenceRepository geofenceRepo = GeofenceRepositoryImpl(
      localDataSource: geofenceDS,
      eventBus: eventBus,
    );
    final TripRepository tripRepo = TripRepositoryImpl(
      localDataSource: tripDS,
      eventBus: eventBus,
    );

    // 4. Domain Use Cases
    final getFleetSummary = GetFleetSummaryUseCase(vehicleRepo);
    final getVehicles = GetVehiclesUseCase(vehicleRepo);
    final getVehicleDetails = GetVehicleDetailsUseCase(
      vehicleRepository: vehicleRepo,
      telemetryRepository: telemetryRepo,
    );

    final getActiveAlerts = GetActiveAlertsUseCase(alertRepo);
    final evalAlerts = EvaluateAlertsUseCase(alertRepo);
    final updateAlertStatus = UpdateAlertStatusUseCase(alertRepo);
    final undoAlertDismissal = UndoAlertDismissalUseCase(alertRepo);

    final createGeofence = CreateGeofenceUseCase(geofenceRepo);
    final updateGeofence = UpdateGeofenceUseCase(geofenceRepo);
    final deactivateGeofence = DeactivateGeofenceUseCase(geofenceRepo);
    final getActiveGeofences = GetActiveGeofencesUseCase(geofenceRepo);
    final detectTransitions = DetectGeofenceTransitionsUseCase(geofenceRepo);

    final processTrips = ProcessTripsUseCase(tripRepo);
    final getVehicleTrips = GetVehicleTripsUseCase(tripRepo);
    final getAllTrips = GetAllTripsUseCase(tripRepo);

    final processTelemetryBatch = ProcessTelemetryBatchUseCase(
      telemetryRepository: telemetryRepo,
      evaluateAlertsUseCase: evalAlerts,
      detectGeofenceTransitionsUseCase: detectTransitions,
      processTripsUseCase: processTrips,
    );

    final container = DependencyContainer._(
      dbClient: dbClient,
      eventBus: eventBus,
      telemetryRepository: telemetryRepo,
      vehicleRepository: vehicleRepo,
      alertRepository: alertRepo,
      geofenceRepository: geofenceRepo,
      tripRepository: tripRepo,
      getFleetSummaryUseCase: getFleetSummary,
      getVehiclesUseCase: getVehicles,
      getVehicleDetailsUseCase: getVehicleDetails,
      processTelemetryBatchUseCase: processTelemetryBatch,
      getActiveAlertsUseCase: getActiveAlerts,
      evaluateAlertsUseCase: evalAlerts,
      updateAlertStatusUseCase: updateAlertStatus,
      undoAlertDismissalUseCase: undoAlertDismissal,
      createGeofenceUseCase: createGeofence,
      updateGeofenceUseCase: updateGeofence,
      deactivateGeofenceUseCase: deactivateGeofence,
      getActiveGeofencesUseCase: getActiveGeofences,
      detectGeofenceTransitionsUseCase: detectTransitions,
      processTripsUseCase: processTrips,
      getVehicleTripsUseCase: getVehicleTrips,
      getAllTripsUseCase: getAllTrips,
    );

    // 5. Seed Data Execution
    if (autoSeed) {
      final seedService = SeedDataService(
        dbClient: dbClient,
        processTelemetryBatchUseCase: processTelemetryBatch,
        createGeofenceUseCase: createGeofence,
      );
      await seedService.seedIfEmpty(vehicleCount: 500);
    }

    return container;
  }

  Future<void> dispose() async {
    eventBus.dispose();
    await dbClient.close();
  }
}
