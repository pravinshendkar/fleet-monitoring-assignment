import 'package:equatable/equatable.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/geofence_repository.dart';

class DeactivateGeofenceParams extends Equatable {
  final String geofenceId;
  final bool isActive;

  const DeactivateGeofenceParams({
    required this.geofenceId,
    required this.isActive,
  });

  @override
  List<Object?> get props => [geofenceId, isActive];
}

class DeactivateGeofenceUseCase implements UseCase<void, DeactivateGeofenceParams> {
  final GeofenceRepository repository;

  DeactivateGeofenceUseCase(this.repository);

  @override
  Future<void> call(DeactivateGeofenceParams params) async {
    await repository.setGeofenceActiveStatus(params.geofenceId, params.isActive);
  }
}
