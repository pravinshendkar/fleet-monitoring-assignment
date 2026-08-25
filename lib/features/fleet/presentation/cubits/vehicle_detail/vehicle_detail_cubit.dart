import 'dart:async';
import 'package:fleet_console/features/fleet/domain/repositories/vehicle_repository.dart';
import 'package:fleet_console/features/fleet/domain/usecases/get_vehicle_details.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'vehicle_detail_state.dart';

class VehicleDetailCubit extends Cubit<VehicleDetailState> {
  final String vehicleId;
  final GetVehicleDetailsUseCase getVehicleDetailsUseCase;
  final VehicleRepository vehicleRepository;
  StreamSubscription? _dbSubscription;

  VehicleDetailCubit({
    required this.vehicleId,
    required this.getVehicleDetailsUseCase,
    required this.vehicleRepository,
  }) : super(VehicleDetailInitial()) {
    _listenToDatabaseChanges();
  }

  void _listenToDatabaseChanges() {
    _dbSubscription = vehicleRepository.watchDatabaseChanges().listen((_) {
      loadVehicleDetail();
    });
  }

  Future<void> loadVehicleDetail() async {
    if (state is! VehicleDetailLoaded) {
      emit(VehicleDetailLoading());
    }

    try {
      final details = await getVehicleDetailsUseCase(vehicleId);
      if (details.vehicle == null && details.telemetryHistory.isEmpty) {
        emit(VehicleDetailError('Vehicle "$vehicleId" not found in DuckDB database.'));
        return;
      }

      emit(VehicleDetailLoaded(details));
    } catch (e) {
      emit(VehicleDetailError('Failed to load vehicle details: ${e.toString()}'));
    }
  }

  @override
  Future<void> close() {
    _dbSubscription?.cancel();
    return super.close();
  }
}
