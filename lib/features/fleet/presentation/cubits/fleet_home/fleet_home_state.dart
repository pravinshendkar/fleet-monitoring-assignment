import 'package:equatable/equatable.dart';
import 'package:fleet_console/features/fleet/domain/entities/fleet_summary.dart';
import 'package:fleet_console/features/fleet/domain/entities/vehicle.dart';

abstract class FleetHomeState extends Equatable {
  const FleetHomeState();

  @override
  List<Object?> get props => [];
}

class FleetHomeInitial extends FleetHomeState {}

class FleetHomeLoading extends FleetHomeState {}

class FleetHomeLoaded extends FleetHomeState {
  final FleetSummary summary;
  final List<Vehicle> vehicles;
  final VehicleStatus? selectedFilter; // null means 'All'
  final String searchQuery;

  const FleetHomeLoaded({
    required this.summary,
    required this.vehicles,
    this.selectedFilter,
    this.searchQuery = '',
  });

  FleetHomeLoaded copyWith({
    FleetSummary? summary,
    List<Vehicle>? vehicles,
    VehicleStatus? selectedFilter,
    bool clearFilter = false,
    String? searchQuery,
  }) {
    return FleetHomeLoaded(
      summary: summary ?? this.summary,
      vehicles: vehicles ?? this.vehicles,
      selectedFilter: clearFilter
          ? null
          : (selectedFilter ?? this.selectedFilter),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [summary, vehicles, selectedFilter, searchQuery];
}

class FleetHomeError extends FleetHomeState {
  final String message;

  const FleetHomeError(this.message);

  @override
  List<Object?> get props => [message];
}
