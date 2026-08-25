import 'package:equatable/equatable.dart';
import 'package:fleet_console/features/geofences/domain/entities/geofence.dart';

abstract class GeofencesState extends Equatable {
  const GeofencesState();

  @override
  List<Object?> get props => [];
}

class GeofencesInitial extends GeofencesState {}

class GeofencesLoading extends GeofencesState {}

class GeofencesLoaded extends GeofencesState {
  final List<Geofence> geofences;

  const GeofencesLoaded(this.geofences);

  @override
  List<Object?> get props => [geofences];
}

class GeofencesError extends GeofencesState {
  final String message;

  const GeofencesError(this.message);

  @override
  List<Object?> get props => [message];
}
