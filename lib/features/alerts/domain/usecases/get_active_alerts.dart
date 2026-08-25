import '../../../../core/usecases/usecase.dart';
import '../entities/alert.dart';
import '../repositories/alert_repository.dart';

class GetActiveAlertsUseCase implements UseCase<List<Alert>, NoParams> {
  final AlertRepository repository;

  GetActiveAlertsUseCase(this.repository);

  @override
  Future<List<Alert>> call(NoParams params) async {
    return await repository.getActiveAlerts();
  }
}
