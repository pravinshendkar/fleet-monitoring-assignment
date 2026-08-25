import '../../../../core/usecases/usecase.dart';
import '../entities/fleet_summary.dart';
import '../repositories/vehicle_repository.dart';

class GetFleetSummaryUseCase implements UseCase<FleetSummary, NoParams> {
  final VehicleRepository repository;

  GetFleetSummaryUseCase(this.repository);

  @override
  Future<FleetSummary> call(NoParams params) async {
    return await repository.getFleetSummary();
  }
}
