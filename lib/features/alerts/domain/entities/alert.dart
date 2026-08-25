import 'package:equatable/equatable.dart';

enum AlertType { lowBattery, criticalBattery, overheating }
enum AlertStatus { active, escalated, dismissed, resolved }

class Alert extends Equatable {
  final String id;
  final String vehicleId;
  final AlertType type;
  final AlertStatus status;
  final double triggerValue;
  final double threshold;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? dismissedAt;
  final String? dismissalReason;

  const Alert({
    required this.id,
    required this.vehicleId,
    required this.type,
    required this.status,
    required this.triggerValue,
    required this.threshold,
    required this.createdAt,
    required this.updatedAt,
    this.dismissedAt,
    this.dismissalReason,
  });

  bool get isCritical =>
      (type == AlertType.lowBattery && triggerValue <= 10.0) ||
      type == AlertType.criticalBattery ||
      type == AlertType.overheating;

  String get severityLabel => isCritical ? 'CRITICAL' : 'WARNING';

  bool get canUndoDismissal =>
      status == AlertStatus.dismissed &&
      dismissedAt != null &&
      DateTime.now().difference(dismissedAt!) <= const Duration(seconds: 10);

  Alert copyWith({
    String? id,
    String? vehicleId,
    AlertType? type,
    AlertStatus? status,
    double? triggerValue,
    double? threshold,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? dismissedAt,
    bool clearDismissedAt = false,
    String? dismissalReason,
    bool clearDismissalReason = false,
  }) {
    return Alert(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      type: type ?? this.type,
      status: status ?? this.status,
      triggerValue: triggerValue ?? this.triggerValue,
      threshold: threshold ?? this.threshold,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      dismissedAt: clearDismissedAt ? null : (dismissedAt ?? this.dismissedAt),
      dismissalReason: clearDismissalReason ? null : (dismissalReason ?? this.dismissalReason),
    );
  }

  @override
  List<Object?> get props => [
        id,
        vehicleId,
        type,
        status,
        triggerValue,
        threshold,
        createdAt,
        updatedAt,
        dismissedAt,
        dismissalReason,
      ];
}
