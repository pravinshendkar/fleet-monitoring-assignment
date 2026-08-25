import 'package:equatable/equatable.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/alert.dart';
import '../repositories/alert_repository.dart';

class UpdateAlertStatusParams extends Equatable {
  final String alertId;
  final AlertStatus status;
  final String? dismissalReason;

  const UpdateAlertStatusParams({
    required this.alertId,
    required this.status,
    this.dismissalReason,
  });

  @override
  List<Object?> get props => [alertId, status, dismissalReason];
}

class UpdateAlertStatusUseCase implements UseCase<void, UpdateAlertStatusParams> {
  final AlertRepository repository;

  UpdateAlertStatusUseCase(this.repository);

  @override
  Future<void> call(UpdateAlertStatusParams params) async {
    await repository.updateAlertStatus(
      params.alertId,
      params.status,
      dismissalReason: params.dismissalReason,
    );
  }
}
