import '../../../../core/usecases/usecase.dart';
import '../entities/alert.dart';
import '../repositories/alert_repository.dart';

class UndoAlertDismissalUseCase implements UseCase<void, String> {
  final AlertRepository repository;

  UndoAlertDismissalUseCase(this.repository);

  @override
  Future<void> call(String alertId) async {
    await repository.updateAlertStatus(alertId, AlertStatus.active);
  }
}
