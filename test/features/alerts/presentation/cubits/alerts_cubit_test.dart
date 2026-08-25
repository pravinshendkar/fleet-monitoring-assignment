import 'package:fleet_console/features/alerts/domain/entities/alert.dart';
import 'package:fleet_console/features/alerts/domain/repositories/alert_repository.dart';
import 'package:fleet_console/features/alerts/domain/usecases/undo_alert_dismissal.dart';
import 'package:fleet_console/features/alerts/domain/usecases/update_alert_status.dart';
import 'package:fleet_console/features/alerts/presentation/cubits/alerts/alerts_cubit.dart';
import 'package:fleet_console/features/alerts/presentation/cubits/alerts/alerts_state.dart';
import 'package:fleet_console/features/fleet/domain/entities/fleet_summary.dart';
import 'package:fleet_console/features/fleet/domain/entities/vehicle.dart';
import 'package:fleet_console/features/fleet/domain/repositories/vehicle_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class MockAlertRepositoryPresentation implements AlertRepository {
  List<Alert> activeList = [];
  List<Alert> allList = [];

  @override
  Future<List<Alert>> getActiveAlerts() async => activeList;

  @override
  Future<List<Alert>> getVehicleAlerts(String vehicleId) async => [];

  @override
  Future<List<Alert>> getAllAlerts() async => allList;

  @override
  Future<void> updateAlertStatus(
    String alertId,
    AlertStatus status, {
    String? dismissalReason,
  }) async {
    final idx = allList.indexWhere((a) => a.id == alertId);
    if (idx != -1) {
      allList[idx] = allList[idx].copyWith(
        status: status,
        dismissalReason: dismissalReason,
      );
    }
    if (status == AlertStatus.dismissed) {
      activeList.removeWhere((a) => a.id == alertId);
    } else if (status == AlertStatus.active) {
      if (idx != -1 && !activeList.any((a) => a.id == alertId)) {
        activeList.add(allList[idx]);
      }
    }
  }

  @override
  Future<void> evaluateTelemetryAlerts(dynamic packets) async {}
}

class MockVehicleRepositoryAlerts implements VehicleRepository {
  @override
  Future<Vehicle?> getVehicleById(String vehicleId) async => null;

  @override
  Future<FleetSummary> getFleetSummary() async => throw UnimplementedError();

  @override
  Future<List<Vehicle>> getVehicles({
    VehicleStatus? statusFilter,
    double? maxSoc,
    String? searchQuery,
    int limit = 50,
    int offset = 0,
    bool ignoreStaleness = false,
  }) async => [];

  @override
  Stream<void> watchDatabaseChanges() => const Stream.empty();
}

void main() {
  group('AlertsCubit Tests', () {
    late MockAlertRepositoryPresentation alertRepo;
    late MockVehicleRepositoryAlerts vehicleRepo;
    late UpdateAlertStatusUseCase updateAlertStatus;
    late UndoAlertDismissalUseCase undoAlertDismissal;
    late AlertsCubit cubit;

    final now = DateTime.now();
    final testAlert = Alert(
      id: 'alert_1',
      vehicleId: 'EV-101',
      type: AlertType.lowBattery,
      status: AlertStatus.active,
      triggerValue: 15.0,
      threshold: 20.0,
      createdAt: now,
      updatedAt: now,
    );

    setUp(() {
      alertRepo = MockAlertRepositoryPresentation();
      alertRepo.activeList = [testAlert];
      alertRepo.allList = [testAlert];

      vehicleRepo = MockVehicleRepositoryAlerts();
      updateAlertStatus = UpdateAlertStatusUseCase(alertRepo);
      undoAlertDismissal = UndoAlertDismissalUseCase(alertRepo);

      cubit = AlertsCubit(
        alertRepository: alertRepo,
        vehicleRepository: vehicleRepo,
        updateAlertStatusUseCase: updateAlertStatus,
        undoAlertDismissalUseCase: undoAlertDismissal,
      );
    });

    tearDown(() {
      cubit.close();
    });

    test('1. Initial state is AlertsInitial', () {
      expect(cubit.state, equals(AlertsInitial()));
    });

    test(
      '2. loadAlerts emits Loading then Loaded with active & all alerts',
      () async {
        await cubit.loadAlerts();

        expect(cubit.state, isA<AlertsLoaded>());
        final loaded = cubit.state as AlertsLoaded;
        expect(loaded.activeAlerts.length, 1);
        expect(loaded.allAlerts.length, 1);
        expect(loaded.activeAlerts.first.vehicleId, 'EV-101');
      },
    );

    test('3. dismissAlert updates status and shows undo banner', () async {
      await cubit.loadAlerts();
      await cubit.dismissAlert(testAlert, 'I am on it');

      expect(cubit.state, isA<AlertsLoaded>());
      final loaded = cubit.state as AlertsLoaded;
      expect(loaded.activeAlerts, isEmpty);
      expect(loaded.showUndoBanner, isTrue);
      expect(loaded.recentlyDismissedAlert?.id, 'alert_1');
    });

    test(
      '4. undoDismissal restores alert to active status before 5s',
      () async {
        await cubit.loadAlerts();
        await cubit.dismissAlert(testAlert, 'I am on it');
        await cubit.undoDismissal();

        expect(cubit.state, isA<AlertsLoaded>());
        final loaded = cubit.state as AlertsLoaded;
        expect(loaded.activeAlerts.length, 1);
        expect(loaded.activeAlerts.first.status, AlertStatus.active);
        expect(loaded.showUndoBanner, isFalse);
      },
    );

    test(
      '5. dismiss -> Undo available -> 5 seconds expire -> Undo unavailable & pressing UNDO after 5s does nothing',
      () async {
        await cubit.loadAlerts();
        await cubit.dismissAlert(testAlert, 'I am on it');

        // Immediately after dismiss: Undo is available
        var loaded = cubit.state as AlertsLoaded;
        expect(loaded.showUndoBanner, isTrue);
        expect(loaded.recentlyDismissedAlert?.id, 'alert_1');

        // Wait 5 seconds for timer to expire
        await Future<void>.delayed(
          const Duration(seconds: 5, milliseconds: 100),
        );

        // After 5 seconds expire: Undo is unavailable
        loaded = cubit.state as AlertsLoaded;
        expect(loaded.showUndoBanner, isFalse);
        expect(loaded.recentlyDismissedAlert, isNull);

        // Pressing UNDO after 5 seconds does nothing
        await cubit.undoDismissal();
        loaded = cubit.state as AlertsLoaded;
        expect(loaded.activeAlerts, isEmpty); // Alert remains dismissed
      },
    );
  });
}
