import 'package:equatable/equatable.dart';
import 'package:fleet_console/features/fleet/domain/usecases/get_vehicle_details.dart';

abstract class VehicleDetailState extends Equatable {
  const VehicleDetailState();

  @override
  List<Object?> get props => [];
}

class VehicleDetailInitial extends VehicleDetailState {}

class VehicleDetailLoading extends VehicleDetailState {}

class VehicleDetailLoaded extends VehicleDetailState {
  final VehicleDetailsResult details;

  const VehicleDetailLoaded(this.details);

  @override
  List<Object?> get props => [details];
}

class VehicleDetailError extends VehicleDetailState {
  final String message;

  const VehicleDetailError(this.message);

  @override
  List<Object?> get props => [message];
}
