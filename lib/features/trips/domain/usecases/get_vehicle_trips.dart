import '../../../../core/usecases/usecase.dart';
import '../entities/trip.dart';
import '../repositories/trip_repository.dart';

class GetVehicleTripsUseCase implements UseCase<List<Trip>, String> {
  final TripRepository repository;

  GetVehicleTripsUseCase(this.repository);

  @override
  Future<List<Trip>> call(String vehicleId) async {
    return await repository.getVehicleTrips(vehicleId);
  }
}
