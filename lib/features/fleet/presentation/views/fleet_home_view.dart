import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../app/di/dependency_provider.dart';
import '../../../alerts/presentation/cubits/alerts/alerts_cubit.dart';
import '../../../alerts/presentation/views/alerts_view.dart';
import '../../../geofences/presentation/cubits/geofences/geofences_cubit.dart';
import '../../../geofences/presentation/views/geofences_view.dart';
import '../../../trips/presentation/cubits/trips/trips_cubit.dart';
import '../../../trips/presentation/views/trips_view.dart';
import '../../domain/entities/fleet_summary.dart';
import '../../domain/entities/vehicle.dart';
import '../cubits/fleet_home/fleet_home_cubit.dart';
import '../cubits/fleet_home/fleet_home_state.dart';
import '../cubits/vehicle_detail/vehicle_detail_cubit.dart';
import '../widgets/vehicle_card.dart';
import 'vehicle_detail_view.dart';

class FleetHomeView extends StatefulWidget {
  const FleetHomeView({super.key});

  @override
  State<FleetHomeView> createState() => _FleetHomeViewState();
}

class _FleetHomeViewState extends State<FleetHomeView> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    context.read<FleetHomeCubit>().loadFleetData();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<FleetHomeCubit>().loadMore();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _navigateToTrips(BuildContext context) {
    final container = DependencyProvider.of(context);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => TripsCubit(
            tripRepository: container.tripRepository,
            vehicleRepository: container.vehicleRepository,
            getAllTripsUseCase: container.getAllTripsUseCase,
          ),
          child: const TripsView(),
        ),
      ),
    );
  }

  void _navigateToGeofences(BuildContext context) {
    final container = DependencyProvider.of(context);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => GeofencesCubit(
            geofenceRepository: container.geofenceRepository,
            vehicleRepository: container.vehicleRepository,
            createGeofenceUseCase: container.createGeofenceUseCase,
            updateGeofenceUseCase: container.updateGeofenceUseCase,
            deactivateGeofenceUseCase: container.deactivateGeofenceUseCase,
          ),
          child: const GeofencesView(),
        ),
      ),
    );
  }

  void _navigateToAlerts(BuildContext context) {
    final container = DependencyProvider.of(context);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => AlertsCubit(
            alertRepository: container.alertRepository,
            vehicleRepository: container.vehicleRepository,
            updateAlertStatusUseCase: container.updateAlertStatusUseCase,
            undoAlertDismissalUseCase: container.undoAlertDismissalUseCase,
          ),
          child: const AlertsView(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.directions_car_filled, color: Colors.blue),
            SizedBox(width: 8),
            Text(
              'Fleet Console',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_outlined),
            tooltip: 'Alerts',
            onPressed: () => _navigateToAlerts(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => context.read<FleetHomeCubit>().refresh(),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Navigation Menu',
            onSelected: (value) {
              if (value == 'trips') {
                _navigateToTrips(context);
              } else if (value == 'geofences') {
                _navigateToGeofences(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'trips',
                child: Row(
                  children: [
                    Icon(Icons.route_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Trips'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'geofences',
                child: Row(
                  children: [
                    Icon(Icons.map_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Geofences'),
                  ],
                ),
              ),
            ],
          ),
        ],
        elevation: 0.5,
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by Vehicle ID or Name...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              context.read<FleetHomeCubit>().setSearchQuery('');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 12,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    context.read<FleetHomeCubit>().setSearchQuery(value);
                  },
                ),
                const SizedBox(height: 12),

                // Live SQL Filter Chips
                BlocBuilder<FleetHomeCubit, FleetHomeState>(
                  builder: (context, state) {
                    FleetSummary? summary;
                    VehicleStatus? currentFilter;

                    if (state is FleetHomeLoaded) {
                      summary = state.summary;
                      currentFilter = state.selectedFilter;
                    }

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip(
                            label: 'All',
                            count: summary?.totalVehicles ?? 0,
                            isSelected: currentFilter == null,
                            onSelected: (_) {
                              context.read<FleetHomeCubit>().setFilter(null);
                            },
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            label: 'Moving',
                            count: summary?.movingCount ?? 0,
                            isSelected: currentFilter == VehicleStatus.moving,
                            color: Colors.green,
                            onSelected: (_) {
                              context.read<FleetHomeCubit>().setFilter(
                                VehicleStatus.moving,
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            label: 'Idle',
                            count: summary?.idleCount ?? 0,
                            isSelected: currentFilter == VehicleStatus.idle,
                            color: Colors.orange,
                            onSelected: (_) {
                              context.read<FleetHomeCubit>().setFilter(
                                VehicleStatus.idle,
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            label: 'Stopped',
                            count: summary?.stoppedCount ?? 0,
                            isSelected: currentFilter == VehicleStatus.stopped,
                            color: Colors.blueGrey,
                            onSelected: (_) {
                              context.read<FleetHomeCubit>().setFilter(
                                VehicleStatus.stopped,
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            label: 'Offline',
                            count: summary?.offlineCount ?? 0,
                            isSelected: currentFilter == VehicleStatus.offline,
                            color: Colors.red,
                            onSelected: (_) {
                              context.read<FleetHomeCubit>().setFilter(
                                VehicleStatus.offline,
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Main Fleet Body List
          Expanded(
            child: BlocBuilder<FleetHomeCubit, FleetHomeState>(
              builder: (context, state) {
                if (state is FleetHomeLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is FleetHomeError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            state.message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 15),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () =>
                                context.read<FleetHomeCubit>().refresh(),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (state is FleetHomeLoaded) {
                  if (state.vehicles.isEmpty) {
                    return _buildEmptyState(state.selectedFilter);
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    itemCount: state.vehicles.length +
                        (context.watch<FleetHomeCubit>().isLoadingMore ? 1 : 0),
                    padding: const EdgeInsets.only(top: 8, bottom: 24),
                    itemBuilder: (context, index) {
                      if (index >= state.vehicles.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final vehicle = state.vehicles[index];
                      return VehicleCard(
                        vehicle: vehicle,
                        onTap: () {
                          final container = DependencyProvider.of(context);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => BlocProvider(
                                create: (_) => VehicleDetailCubit(
                                  vehicleId: vehicle.id,
                                  getVehicleDetailsUseCase:
                                      container.getVehicleDetailsUseCase,
                                  vehicleRepository:
                                      container.vehicleRepository,
                                ),
                                child: VehicleDetailView(vehicleId: vehicle.id),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required int count,
    required bool isSelected,
    Color? color,
    required ValueChanged<bool> onSelected,
  }) {
    final activeColor = color ?? Colors.blue;

    return FilterChip(
      selected: isSelected,
      onSelected: onSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : Colors.black87,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.25)
                  : activeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : activeColor,
              ),
            ),
          ),
        ],
      ),
      selectedColor: activeColor,
      backgroundColor: Colors.grey[100],
      checkmarkColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    );
  }

  Widget _buildEmptyState(VehicleStatus? filter) {
    String message = 'No vehicles match the selected criteria.';
    if (filter != null) {
      message = 'No ${filter.name.toUpperCase()} vehicles found in the fleet.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No Vehicles Found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
