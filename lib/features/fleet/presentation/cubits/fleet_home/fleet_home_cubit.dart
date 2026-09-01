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
  int _currentOffset = 0;
  final int _pageSize = 50;
  bool _hasReachedMax = false;
  bool _isLoadingMore = false;

  bool get hasReachedMax => _hasReachedMax;
  bool get isLoadingMore => _isLoadingMore;

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

    _currentOffset = 0;
    _hasReachedMax = false;

    try {
      final summary = await getFleetSummaryUseCase(NoParams());
      final vehicles = await getVehiclesUseCase(
        GetVehiclesParams(
          statusFilter: _currentFilter,
          searchQuery: _currentSearchQuery,
          limit: _pageSize,
          offset: _currentOffset,
        ),
      );

      _hasReachedMax = vehicles.length < _pageSize;

      emit(
        FleetHomeLoaded(
          summary: summary,
          vehicles: vehicles,
          selectedFilter: _currentFilter,
          searchQuery: _currentSearchQuery,
        ),
      );
    } catch (e) {
      emit(FleetHomeError('Failed to load fleet data: ${e.toString()}'));
    }
  }

  Future<void> loadMore() async {
    if (state is! FleetHomeLoaded || _hasReachedMax || _isLoadingMore) return;
    
    _isLoadingMore = true;
    final currentState = state as FleetHomeLoaded;
    _currentOffset += _pageSize;

    try {
      final moreVehicles = await getVehiclesUseCase(
        GetVehiclesParams(
          statusFilter: _currentFilter,
          searchQuery: _currentSearchQuery,
          limit: _pageSize,
          offset: _currentOffset,
        ),
      );

      _hasReachedMax = moreVehicles.length < _pageSize;

      emit(
        FleetHomeLoaded(
          summary: currentState.summary,
          vehicles: [...currentState.vehicles, ...moreVehicles],
          selectedFilter: _currentFilter,
          searchQuery: _currentSearchQuery,
        ),
      );
    } catch (e) {
      // Revert offset on error
      _currentOffset -= _pageSize;
      // You could emit an error state here, but for now we'll just ignore so the list doesn't break
    } finally {
      _isLoadingMore = false;
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
