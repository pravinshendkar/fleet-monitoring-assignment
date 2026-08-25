import '../../../../core/usecases/usecase.dart';
import '../entities/geofence.dart';
import '../repositories/geofence_repository.dart';

class GetActiveGeofencesUseCase implements UseCase<List<Geofence>, NoParams> {
  final GeofenceRepository repository;

  GetActiveGeofencesUseCase(this.repository);

  @override
  Future<List<Geofence>> call(NoParams params) async {
    final geofences = await repository.getGeofences();
    return geofences.where((g) => g.isActive).toList();
  }
}
