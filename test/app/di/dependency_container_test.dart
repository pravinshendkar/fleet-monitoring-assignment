import 'dart:io';
import 'package:fleet_console/app/di/dependency_container.dart';
import 'package:fleet_console/core/usecases/usecase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DependencyContainer Composition Root Tests', () {
    late String tempDbPath;

    setUp(() {
      tempDbPath = 'test_di_${DateTime.now().millisecondsSinceEpoch}.duckdb';
    });

    tearDown(() async {
      final file = File(tempDbPath);
      if (await file.exists()) {
        await file.delete();
      }
      final walFile = File('$tempDbPath.wal');
      if (await walFile.exists()) {
        await walFile.delete();
      }
    });

    test(
      '1. DependencyContainer.create constructs and wires all Clean Architecture components',
      () async {
        final container = await DependencyContainer.create(
          dbPath: tempDbPath,
          autoSeed: true,
        );

        expect(container.dbClient, isNotNull);
        expect(container.dbClient.databasePath, equals(tempDbPath));
        expect(container.eventBus, isNotNull);

        // Verify domain repository abstractions
        expect(container.telemetryRepository, isNotNull);
        expect(container.vehicleRepository, isNotNull);
        expect(container.alertRepository, isNotNull);
        expect(container.geofenceRepository, isNotNull);
        expect(container.tripRepository, isNotNull);

        // Verify domain use cases
        expect(container.getFleetSummaryUseCase, isNotNull);
        expect(container.getVehiclesUseCase, isNotNull);
        expect(container.processTelemetryBatchUseCase, isNotNull);

        // Verify 500 vehicles seeded
        final summary = await container.getFleetSummaryUseCase(NoParams());
        expect(summary.totalVehicles, 500);

        // Clean disposal
        await container.dispose();
      },
    );

    test(
      '2. resolvePlatformDatabasePath returns fallback when PathProvider is unmocked in unit test',
      () async {
        final path = await DependencyContainer.resolvePlatformDatabasePath();
        expect(path, isNotEmpty);
        expect(path.endsWith('fleet_console.duckdb'), isTrue);
      },
    );
  });
}
