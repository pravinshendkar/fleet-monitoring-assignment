import 'dart:io';
import 'package:fleet_console/core/database/database_event_bus.dart';
import 'package:fleet_console/core/database/duckdb_client.dart';
import 'package:fleet_console/features/alerts/data/datasources/alert_local_datasource.dart';
import 'package:fleet_console/features/alerts/data/repositories/alert_repository_impl.dart';
import 'package:fleet_console/features/alerts/domain/entities/alert.dart';
import 'package:fleet_console/features/alerts/domain/usecases/evaluate_alerts.dart';
import 'package:fleet_console/features/alerts/domain/usecases/undo_alert_dismissal.dart';
import 'package:fleet_console/features/alerts/domain/usecases/update_alert_status.dart';
import 'package:fleet_console/features/fleet/domain/entities/telemetry_packet.dart';
import 'package:fleet_console/features/fleet/data/datasources/vehicle_local_datasource.dart';
import 'package:fleet_console/features/fleet/data/repositories/vehicle_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Alert Lifecycle & Escalation Integration Tests', () {
    late DuckDbClient dbClient;
    late DatabaseEventBus eventBus;
    late AlertLocalDataSourceImpl alertDS;
    late AlertRepositoryImpl alertRepo;
    late EvaluateAlertsUseCase evaluateAlerts;
    late UpdateAlertStatusUseCase updateAlertStatus;
    late UndoAlertDismissalUseCase undoAlertDismissal;

    late String tempDbPath;
    final now = DateTime.now();

    setUp(() async {
      tempDbPath =
          'test_alerts_${DateTime.now().millisecondsSinceEpoch}.duckdb';
      dbClient = DuckDbClient();
      await dbClient.init(tempDbPath);

      eventBus = DatabaseEventBus();
      alertDS = AlertLocalDataSourceImpl(dbClient: dbClient);
      alertRepo = AlertRepositoryImpl(
        localDataSource: alertDS,
        eventBus: eventBus,
      );

      final vehicleDS = VehicleLocalDataSourceImpl(dbClient: dbClient);
      final vehicleRepo = VehicleRepositoryImpl(
        localDataSource: vehicleDS,
        eventBus: eventBus,
      );

      evaluateAlerts = EvaluateAlertsUseCase(alertRepo, vehicleRepo);
      updateAlertStatus = UpdateAlertStatusUseCase(alertRepo);
      undoAlertDismissal = UndoAlertDismissalUseCase(alertRepo);
    });

    tearDown(() async {
      eventBus.dispose();
      await dbClient.close();
      final file = File(tempDbPath);
      if (await file.exists()) {
        await file.delete();
      }
    });

    test('1. SOC 19% creates Low Battery WARNING alert', () async {
      final p1 = TelemetryPacket(
        packetId: 'p1',
        vehicleId: 'EV-101',
        eventTimestamp: now.subtract(const Duration(seconds: 30)),
        ingestTimestamp: now,
        latitude: 12.97,
        longitude: 77.59,
        speed: 0.0,
        batteryLevel: 19.0,
        batteryTemp: 30.0,
        odometerKm: 1000.0,
        ignition: false,
      );

      await evaluateAlerts([p1]);

      final active = await alertRepo.getActiveAlerts();
      expect(active.length, 1);
      expect(active.first.vehicleId, 'EV-101');
      expect(active.first.type, AlertType.lowBattery);
      expect(active.first.status, AlertStatus.active);
      expect(active.first.severityLabel, 'WARNING');
    });

    test(
      '2. SOC 8% escalates existing SOC alert to CRITICAL without creating a second alert',
      () async {
        final p1 = TelemetryPacket(
          packetId: 'p1',
          vehicleId: 'EV-101',
          eventTimestamp: now.subtract(const Duration(minutes: 2)),
          ingestTimestamp: now,
          latitude: 12.97,
          longitude: 77.59,
          speed: 0.0,
          batteryLevel: 19.0,
          batteryTemp: 30.0,
          odometerKm: 1000.0,
          ignition: false,
        );

        await evaluateAlerts([p1]);

        final p2 = TelemetryPacket(
          packetId: 'p2',
          vehicleId: 'EV-101',
          eventTimestamp: now.subtract(const Duration(seconds: 30)),
          ingestTimestamp: now,
          latitude: 12.97,
          longitude: 77.59,
          speed: 0.0,
          batteryLevel: 8.0, // Critical
          batteryTemp: 30.0,
          odometerKm: 1000.0,
          ignition: false,
        );

        await evaluateAlerts([p2]);

        final active = await alertRepo.getActiveAlerts();
        expect(active.length, 1); // Single SOC alert!
        expect(active.first.id, 'alert_soc_EV-101');
        expect(active.first.type, AlertType.criticalBattery);
        expect(active.first.status, AlertStatus.escalated);
        expect(active.first.severityLabel, 'CRITICAL');
      },
    );

    test(
      '3. Temperature > 45°C creates Overheating alert alongside SOC alert',
      () async {
        final p1 = TelemetryPacket(
          packetId: 'p1',
          vehicleId: 'EV-101',
          eventTimestamp: now.subtract(const Duration(seconds: 30)),
          ingestTimestamp: now,
          latitude: 12.97,
          longitude: 77.59,
          speed: 50.0,
          batteryLevel: 15.0,
          batteryTemp: 48.0, // Overheating
          odometerKm: 1000.0,
          ignition: true,
        );

        await evaluateAlerts([p1]);

        final active = await alertRepo.getActiveAlerts();
        expect(
          active.length,
          2,
        ); // SOC alert AND Overheating alert co-existing!
        expect(active.any((a) => a.type == AlertType.lowBattery), isTrue);
        expect(active.any((a) => a.type == AlertType.overheating), isTrue);
      },
    );

    test(
      '4. Stale telemetry (>10m old) does not create or escalate alerts',
      () async {
        final stalePacket = TelemetryPacket(
          packetId: 'p_stale',
          vehicleId: 'EV-101',
          eventTimestamp: now.subtract(const Duration(minutes: 15)),
          ingestTimestamp: now,
          latitude: 12.97,
          longitude: 77.59,
          speed: 0.0,
          batteryLevel: 5.0,
          batteryTemp: 50.0,
          odometerKm: 1000.0,
          ignition: false,
        );

        await evaluateAlerts([stalePacket]);

        final active = await alertRepo.getActiveAlerts();
        expect(active, isEmpty);
      },
    );

    test(
      '5. Alert dismissal persists dismissal reason and allows UNDO',
      () async {
        final p1 = TelemetryPacket(
          packetId: 'p1',
          vehicleId: 'EV-101',
          eventTimestamp: now.subtract(const Duration(seconds: 30)),
          ingestTimestamp: now,
          latitude: 12.97,
          longitude: 77.59,
          speed: 0.0,
          batteryLevel: 15.0,
          batteryTemp: 30.0,
          odometerKm: 1000.0,
          ignition: false,
        );

        await evaluateAlerts([p1]);

        final activeBefore = await alertRepo.getActiveAlerts();
        final alertId = activeBefore.first.id;

        // Dismiss with reason
        await updateAlertStatus(
          UpdateAlertStatusParams(
            alertId: alertId,
            status: AlertStatus.dismissed,
            dismissalReason: 'I am on it',
          ),
        );

        final activeAfterDismiss = await alertRepo.getActiveAlerts();
        expect(activeAfterDismiss, isEmpty);

        final allAlerts = await alertRepo.getAllAlerts();
        expect(allAlerts.first.status, AlertStatus.dismissed);
        expect(allAlerts.first.dismissalReason, 'I am on it');

        // Execute UNDO
        await undoAlertDismissal(alertId);

        final activeAfterUndo = await alertRepo.getActiveAlerts();
        expect(activeAfterUndo.length, 1);
        expect(activeAfterUndo.first.status, AlertStatus.active);
        expect(activeAfterUndo.first.dismissalReason, isNull);
      },
    );

    test(
      '6. Condition clearing resolves active AND dismissed alerts independently',
      () async {
        final p1 = TelemetryPacket(
          packetId: 'p1',
          vehicleId: 'EV-101',
          eventTimestamp: now.subtract(const Duration(minutes: 5)),
          ingestTimestamp: now,
          latitude: 12.97,
          longitude: 77.59,
          speed: 0.0,
          batteryLevel: 15.0,
          batteryTemp: 30.0,
          odometerKm: 1000.0,
          ignition: false,
        );

        await evaluateAlerts([p1]);

        // User dismisses alert
        await updateAlertStatus(
          UpdateAlertStatusParams(
            alertId: 'alert_soc_EV-101',
            status: AlertStatus.dismissed,
            dismissalReason: 'Wrong alert',
          ),
        );

        // Vehicle recovers battery level (>20%)
        final p2 = TelemetryPacket(
          packetId: 'p2',
          vehicleId: 'EV-101',
          eventTimestamp: now.subtract(const Duration(seconds: 30)),
          ingestTimestamp: now,
          latitude: 12.97,
          longitude: 77.59,
          speed: 0.0,
          batteryLevel: 25.0, // Recovered!
          batteryTemp: 30.0,
          odometerKm: 1000.0,
          ignition: false,
        );

        await evaluateAlerts([p2]);

        final all = await alertRepo.getAllAlerts();
        expect(all.first.status, AlertStatus.resolved);
      },
    );
  });
}
