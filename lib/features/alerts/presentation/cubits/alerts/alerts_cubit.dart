import 'dart:async';
import 'package:fleet_console/features/alerts/domain/entities/alert.dart';
import 'package:fleet_console/features/alerts/domain/repositories/alert_repository.dart';
import 'package:fleet_console/features/alerts/domain/usecases/undo_alert_dismissal.dart';
import 'package:fleet_console/features/alerts/domain/usecases/update_alert_status.dart';
import 'package:fleet_console/features/fleet/domain/repositories/vehicle_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'alerts_state.dart';

class AlertsCubit extends Cubit<AlertsState> {
  final AlertRepository alertRepository;
  final VehicleRepository vehicleRepository;
  final UpdateAlertStatusUseCase updateAlertStatusUseCase;
  final UndoAlertDismissalUseCase undoAlertDismissalUseCase;

  StreamSubscription? _dbSubscription;
  Timer? _undoTimer;
  Alert? _lastDismissedAlert;

  AlertsCubit({
    required this.alertRepository,
    required this.vehicleRepository,
    required this.updateAlertStatusUseCase,
    required this.undoAlertDismissalUseCase,
  }) : super(AlertsInitial()) {
    _listenToDatabaseChanges();
  }

  void _listenToDatabaseChanges() {
    _dbSubscription = vehicleRepository.watchDatabaseChanges().listen((_) {
      loadAlerts();
    });
  }

  Future<void> loadAlerts() async {
    if (state is! AlertsLoaded) {
      emit(AlertsLoading());
    }

    try {
      final active = await alertRepository.getActiveAlerts();
      final all = await alertRepository.getAllAlerts();
      final isUndoActive = _undoTimer != null && _undoTimer!.isActive;

      emit(
        AlertsLoaded(
          activeAlerts: active,
          allAlerts: all,
          recentlyDismissedAlert: isUndoActive ? _lastDismissedAlert : null,
          showUndoBanner: isUndoActive,
        ),
      );
    } catch (e) {
      emit(AlertsError('Failed to load alerts: ${e.toString()}'));
    }
  }

  Future<void> dismissAlert(Alert alert, String reason) async {
    _lastDismissedAlert = alert;
    _undoTimer?.cancel();

    // Start 5-second timer for Undo availability (single source of truth)
    _undoTimer = Timer(const Duration(seconds: 5), () {
      _lastDismissedAlert = null;
      _undoTimer = null;
      if (state is AlertsLoaded) {
        final current = state as AlertsLoaded;
        emit(
          current.copyWith(clearRecentlyDismissed: true, showUndoBanner: false),
        );
      }
    });

    await updateAlertStatusUseCase(
      UpdateAlertStatusParams(
        alertId: alert.id,
        status: AlertStatus.dismissed,
        dismissalReason: reason,
      ),
    );

    final active = await alertRepository.getActiveAlerts();
    final all = await alertRepository.getAllAlerts();

    emit(
      AlertsLoaded(
        activeAlerts: active,
        allAlerts: all,
        recentlyDismissedAlert: alert,
        showUndoBanner: true,
      ),
    );
  }

  Future<void> undoDismissal() async {
    if (_lastDismissedAlert == null ||
        _undoTimer == null ||
        !_undoTimer!.isActive) {
      return;
    }

    final alertToRestore = _lastDismissedAlert!;
    _undoTimer?.cancel();
    _undoTimer = null;
    _lastDismissedAlert = null;

    await undoAlertDismissalUseCase(alertToRestore.id);
    await loadAlerts();
  }

  @override
  Future<void> close() {
    _dbSubscription?.cancel();
    _undoTimer?.cancel();
    return super.close();
  }
}
