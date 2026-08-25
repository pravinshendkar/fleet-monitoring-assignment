import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/trip.dart';
import '../cubits/trips/trips_cubit.dart';
import '../cubits/trips/trips_state.dart';

class TripsView extends StatefulWidget {
  const TripsView({super.key});

  @override
  State<TripsView> createState() => _TripsViewState();
}

class _TripsViewState extends State<TripsView> {
  int _selectedTab = 0; // 0: All, 1: In Progress, 2: Completed

  @override
  void initState() {
    super.initState();
    context.read<TripsCubit>().loadTrips();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.route, color: Colors.indigo),
            SizedBox(width: 8),
            Text('Fleet Trips', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<TripsCubit>().loadTrips(),
          ),
        ],
        elevation: 0.5,
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment<int>(
                        value: 0,
                        label: Text('All Trips'),
                        icon: Icon(Icons.clear_all, size: 18),
                      ),
                      ButtonSegment<int>(
                        value: 1,
                        label: Text('In Progress'),
                        icon: Icon(Icons.directions_run, size: 18),
                      ),
                      ButtonSegment<int>(
                        value: 2,
                        label: Text('Completed'),
                        icon: Icon(Icons.check_circle_outline, size: 18),
                      ),
                    ],
                    selected: {_selectedTab},
                    onSelectionChanged: (Set<int> newSelection) {
                      setState(() {
                        _selectedTab = newSelection.first;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          // Main Trips List
          Expanded(
            child: BlocBuilder<TripsCubit, TripsState>(
              builder: (context, state) {
                if (state is TripsLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is TripsError) {
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
                          Text(state.message, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () =>
                                context.read<TripsCubit>().loadTrips(),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (state is TripsLoaded) {
                  final list = _selectedTab == 0
                      ? state.allTrips
                      : (_selectedTab == 1
                            ? state.ongoingTrips
                            : state.completedTrips);

                  if (list.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.builder(
                    itemCount: list.length,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    itemBuilder: (context, index) {
                      final trip = list[index];
                      return _buildTripCard(context, trip);
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

  Widget _buildTripCard(BuildContext context, Trip trip) {
    final isCompleted = trip.status == TripStatus.completed;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isCompleted
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.blue.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Vehicle ID & Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isCompleted ? Icons.check_circle : Icons.navigation,
                      color: isCompleted ? Colors.green : Colors.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Vehicle: ${trip.vehicleId}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                _buildStatusChip(trip.status),
              ],
            ),
            const SizedBox(height: 12),

            // Route: Start Geofence -> End Geofence
            Row(
              children: [
                const Icon(Icons.trip_origin, size: 16, color: Colors.blue),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${trip.startGeofenceId} → ${trip.endGeofenceId ?? 'In Progress...'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Time Row
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Started: ${_formatTime(trip.startTime)}${trip.endTime != null ? ' | Ended: ${_formatTime(trip.endTime!)}' : ''}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Key Metrics Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetricItem(
                  icon: Icons.straighten,
                  label: 'Distance',
                  value: '${trip.distanceKm.toStringAsFixed(1)} km',
                ),
                _buildMetricItem(
                  icon: Icons.speed,
                  label: 'Max Speed',
                  value: '${trip.maxSpeedKmh.toStringAsFixed(0)} km/h',
                ),
                _buildMetricItem(
                  icon: Icons.battery_charging_full,
                  label: 'SOC Used',
                  value: '${trip.averageSocUsed.toStringAsFixed(1)}%',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildStatusChip(TripStatus status) {
    final isCompleted = status == TripStatus.completed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isCompleted
            ? Colors.green.withValues(alpha: 0.12)
            : Colors.blue.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isCompleted ? 'COMPLETED' : 'IN_PROGRESS',
        style: TextStyle(
          color: isCompleted ? Colors.green[800] : Colors.blue[900],
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.route_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No Trips Found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Trips will be automatically logged when vehicles exit and enter confirmed geofences.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} (${dt.day}/${dt.month})';
  }
}
