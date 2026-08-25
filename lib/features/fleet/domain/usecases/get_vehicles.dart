import 'package:equatable/equatable.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/vehicle.dart';
import '../repositories/vehicle_repository.dart';

class GetVehiclesParams extends Equatable {
  final VehicleStatus? statusFilter;
  final double? maxSoc;
  final String? searchQuery;
  final int limit;
  final int offset;

  const GetVehiclesParams({
    this.statusFilter,
    this.maxSoc,
    this.searchQuery,
    this.limit = 50,
    this.offset = 0,
  });

  @override
  List<Object?> get props => [statusFilter, maxSoc, searchQuery, limit, offset];
}

class GetVehiclesUseCase implements UseCase<List<Vehicle>, GetVehiclesParams> {
  final VehicleRepository repository;

  GetVehiclesUseCase(this.repository);

  @override
  Future<List<Vehicle>> call(GetVehiclesParams params) async {
    return await repository.getVehicles(
      statusFilter: params.statusFilter,
      maxSoc: params.maxSoc,
      searchQuery: params.searchQuery,
      limit: params.limit,
      offset: params.offset,
    );
  }
}
