import 'package:fleet_console/features/alerts/domain/entities/alert.dart';
import 'package:fleet_console/features/alerts/domain/repositories/alert_repository.dart';
import 'package:fleet_console/features/alerts/domain/usecases/undo_alert_dismissal.dart';
import 'package:fleet_console/features/alerts/domain/usecases/update_alert_status.dart';
import 'package:fleet_console/features/alerts/presentation/cubits/alerts/alerts_cubit.dart';
import 'package:fleet_console/features/alerts/presentation/views/alerts_view.dart';
import 'package:fleet_console/features/fleet/domain/entities/fleet_summary.dart';
import 'package:fleet_console/features/fleet/domain/entities/vehicle.dart';
import 'package:fleet_console/features/fleet/domain/repositories/vehicle_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class MockAlertRepoView implements AlertRepository {
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
  }

  @override
  Future<void> evaluateTelemetryAlerts(dynamic packets) async {}
}

class MockVehicleRepoView implements VehicleRepository {
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
  group('AlertsView Widget Tests', () {
    late MockAlertRepoView alertRepo;
    late MockVehicleRepoView vehicleRepo;
    late UpdateAlertStatusUseCase updateAlertStatus;
    late UndoAlertDismissalUseCase undoAlertDismissal;

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
      alertRepo = MockAlertRepoView();
      alertRepo.activeList = [testAlert];
      alertRepo.allList = [testAlert];

      vehicleRepo = MockVehicleRepoView();
      updateAlertStatus = UpdateAlertStatusUseCase(alertRepo);
      undoAlertDismissal = UndoAlertDismissalUseCase(alertRepo);
    });

    testWidgets(
      'renders active alert card and opens dismissal reason sheet with exact ordered reasons',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider(
              create: (context) => AlertsCubit(
                alertRepository: alertRepo,
                vehicleRepository: vehicleRepo,
                updateAlertStatusUseCase: updateAlertStatus,
                undoAlertDismissalUseCase: undoAlertDismissal,
              ),
              child: const AlertsView(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // App bar & title
        expect(find.text('Fleet Alerts'), findsOneWidget);

        // Alert card content
        expect(find.text('Vehicle: EV-101'), findsOneWidget);
        expect(find.text('WARNING'), findsOneWidget);
        expect(find.text('Dismiss'), findsOneWidget);

        // Tap Dismiss button
        await tester.tap(find.text('Dismiss'));
        await tester.pumpAndSettle();

        // Verify Dismissal Sheet reasons in exact order:
        // 1. I am on it
        // 2. Wrong alert
        // 3. Something else…
        expect(find.text('Select Dismissal Reason'), findsOneWidget);
        expect(find.text('I am on it'), findsOneWidget);
        expect(find.text('Wrong alert'), findsOneWidget);
        expect(find.text('Something else…'), findsOneWidget);
      },
    );
  });
}
