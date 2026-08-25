import 'package:equatable/equatable.dart';
import 'package:fleet_console/features/trips/domain/entities/trip.dart';

abstract class TripsState extends Equatable {
  const TripsState();

  @override
  List<Object?> get props => [];
}

class TripsInitial extends TripsState {}

class TripsLoading extends TripsState {}

class TripsLoaded extends TripsState {
  final List<Trip> allTrips;
  final List<Trip> ongoingTrips;
  final List<Trip> completedTrips;

  const TripsLoaded({
    required this.allTrips,
    required this.ongoingTrips,
    required this.completedTrips,
  });

  @override
  List<Object?> get props => [allTrips, ongoingTrips, completedTrips];
}

class TripsError extends TripsState {
  final String message;

  const TripsError(this.message);

  @override
  List<Object?> get props => [message];
}
