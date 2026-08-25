import '../../domain/entities/alert.dart';

class AlertModel extends Alert {
  const AlertModel({
    required super.id,
    required super.vehicleId,
    required super.type,
    required super.status,
    required super.triggerValue,
    required super.threshold,
    required super.createdAt,
    required super.updatedAt,
    super.dismissedAt,
    super.dismissalReason,
  });

  factory AlertModel.fromMap(Map<String, dynamic> map) {
    return AlertModel(
      id: map['alert_id'] as String,
      vehicleId: map['vehicle_id'] as String,
      type: AlertType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => AlertType.lowBattery,
      ),
      status: AlertStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => AlertStatus.active,
      ),
      triggerValue: (map['trigger_value'] as num).toDouble(),
      threshold: (map['threshold'] as num).toDouble(),
      createdAt: map['created_at'] is DateTime
          ? (map['created_at'] as DateTime).toUtc()
          : DateTime.parse(map['created_at'].toString()).toUtc(),
      updatedAt: map['updated_at'] is DateTime
          ? (map['updated_at'] as DateTime).toUtc()
          : DateTime.parse(map['updated_at'].toString()).toUtc(),
      dismissedAt: map['dismissed_at'] != null
          ? (map['dismissed_at'] is DateTime
                ? (map['dismissed_at'] as DateTime).toUtc()
                : DateTime.parse(map['dismissed_at'].toString()).toUtc())
          : null,
      dismissalReason: map['dismissal_reason'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'alert_id': id,
      'vehicle_id': vehicleId,
      'type': type.name,
      'status': status.name,
      'trigger_value': triggerValue,
      'threshold': threshold,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'dismissed_at': dismissedAt?.toUtc().toIso8601String(),
      'dismissal_reason': dismissalReason,
    };
  }

  factory AlertModel.fromEntity(Alert alert) {
    return AlertModel(
      id: alert.id,
      vehicleId: alert.vehicleId,
      type: alert.type,
      status: alert.status,
      triggerValue: alert.triggerValue,
      threshold: alert.threshold,
      createdAt: alert.createdAt,
      updatedAt: alert.updatedAt,
      dismissedAt: alert.dismissedAt,
      dismissalReason: alert.dismissalReason,
    );
  }
}
