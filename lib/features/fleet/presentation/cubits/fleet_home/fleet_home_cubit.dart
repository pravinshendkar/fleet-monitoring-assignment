import 'dart:async';
import 'package:fleet_console/core/usecases/usecase.dart';
import 'package:fleet_console/features/fleet/domain/entities/vehicle.dart';
import 'package:fleet_console/features/fleet/domain/repositories/vehicle_repository.dart';
import 'package:fleet_console/features/fleet/domain/usecases/get_fleet_summary.dart';
import 'package:fleet_console/features/fleet/domain/usecases/get_vehicles.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'fleet_home_state.dart';

class FleetHomeCubit extends Cubit<FleetHomeState> {
  final GetFleetSummaryUseCase getFleetSummaryUseCase;
  final GetVehiclesUseCase getVehiclesUseCase;
  final VehicleRepository vehicleRepository;
  StreamSubscription? _dbSubscription;

  VehicleStatus? _currentFilter;
  String _currentSearchQuery = '';

  FleetHomeCubit({
    required this.getFleetSummaryUseCase,
    required this.getVehiclesUseCase,
    required this.vehicleRepository,
  }) : super(FleetHomeInitial()) {
    _listenToDatabaseChanges();
  }

  void _listenToDatabaseChanges() {
    _dbSubscription = vehicleRepository.watchDatabaseChanges().listen((_) {
      refresh();
    });
  }

  Future<void> loadFleetData({
    VehicleStatus? filter,
    bool clearFilter = false,
    String? searchQuery,
  }) async {
    if (state is! FleetHomeLoaded) {
      emit(FleetHomeLoading());
    }

    if (clearFilter) {
      _currentFilter = null;
    } else if (filter != null) {
      _currentFilter = filter;
    }

    if (searchQuery != null) {
      _currentSearchQuery = searchQuery;
    }

    try {
      final summary = await getFleetSummaryUseCase(NoParams());
      final vehicles = await getVehiclesUseCase(
        GetVehiclesParams(
          statusFilter: _currentFilter,
          searchQuery: _currentSearchQuery,
          limit: 500,
        ),
      );

      emit(FleetHomeLoaded(
        summary: summary,
        vehicles: vehicles,
        selectedFilter: _currentFilter,
        searchQuery: _currentSearchQuery,
      ));
    } catch (e) {
      emit(FleetHomeError('Failed to load fleet data: ${e.toString()}'));
    }
  }

  Future<void> setFilter(VehicleStatus? filter) async {
    final clear = filter == null;
    await loadFleetData(filter: filter, clearFilter: clear);
  }

  Future<void> setSearchQuery(String query) async {
    await loadFleetData(searchQuery: query);
  }

  Future<void> refresh() async {
    await loadFleetData();
  }

  @override
  Future<void> close() {
    _dbSubscription?.cancel();
    return super.close();
  }
}
