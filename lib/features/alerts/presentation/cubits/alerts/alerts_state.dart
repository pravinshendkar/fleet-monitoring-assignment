import 'package:equatable/equatable.dart';
import 'package:fleet_console/features/alerts/domain/entities/alert.dart';

abstract class AlertsState extends Equatable {
  const AlertsState();

  @override
  List<Object?> get props => [];
}

class AlertsInitial extends AlertsState {}

class AlertsLoading extends AlertsState {}

class AlertsLoaded extends AlertsState {
  final List<Alert> activeAlerts;
  final List<Alert> allAlerts;
  final Alert? recentlyDismissedAlert;
  final bool showUndoBanner;

  const AlertsLoaded({
    required this.activeAlerts,
    required this.allAlerts,
    this.recentlyDismissedAlert,
    this.showUndoBanner = false,
  });

  AlertsLoaded copyWith({
    List<Alert>? activeAlerts,
    List<Alert>? allAlerts,
    Alert? recentlyDismissedAlert,
    bool clearRecentlyDismissed = false,
    bool? showUndoBanner,
  }) {
    return AlertsLoaded(
      activeAlerts: activeAlerts ?? this.activeAlerts,
      allAlerts: allAlerts ?? this.allAlerts,
      recentlyDismissedAlert: clearRecentlyDismissed
          ? null
          : (recentlyDismissedAlert ?? this.recentlyDismissedAlert),
      showUndoBanner: showUndoBanner ?? this.showUndoBanner,
    );
  }

  @override
  List<Object?> get props => [
    activeAlerts,
    allAlerts,
    recentlyDismissedAlert,
    showUndoBanner,
  ];
}

class AlertsError extends AlertsState {
  final String message;

  const AlertsError(this.message);

  @override
  List<Object?> get props => [message];
}
