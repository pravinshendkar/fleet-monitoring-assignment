import '../../../../core/usecases/usecase.dart';
import '../entities/trip.dart';
import '../repositories/trip_repository.dart';

class GetAllTripsUseCase implements UseCase<List<Trip>, NoParams> {
  final TripRepository repository;

  GetAllTripsUseCase(this.repository);

  @override
  Future<List<Trip>> call(NoParams params) async {
    return await repository.getAllTrips();
  }
}
