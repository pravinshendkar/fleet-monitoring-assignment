import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/geofence.dart';
import '../cubits/geofences/geofences_cubit.dart';
import '../cubits/geofences/geofences_state.dart';
import '../widgets/geofence_form_dialog.dart';

class GeofencesView extends StatefulWidget {
  const GeofencesView({super.key});

  @override
  State<GeofencesView> createState() => _GeofencesViewState();
}

class _GeofencesViewState extends State<GeofencesView> {
  @override
  void initState() {
    super.initState();
    context.read<GeofencesCubit>().loadGeofences();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.map, color: Colors.blue),
            SizedBox(width: 8),
            Text('Geofences', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Geofence',
            onPressed: () => _showCreateDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<GeofencesCubit>().loadGeofences(),
          ),
        ],
        elevation: 0.5,
      ),
      body: BlocBuilder<GeofencesCubit, GeofencesState>(
        builder: (context, state) {
          if (state is GeofencesLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is GeofencesError) {
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
                          context.read<GeofencesCubit>().loadGeofences(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (state is GeofencesLoaded) {
            if (state.geofences.isEmpty) {
              return _buildEmptyState();
            }

            return ListView.builder(
              itemCount: state.geofences.length,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              itemBuilder: (context, index) {
                final geofence = state.geofences[index];
                return _buildGeofenceCard(context, geofence);
              },
            );
          }

          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context),
        icon: const Icon(Icons.add_location_alt),
        label: const Text('New Geofence'),
      ),
    );
  }

  Widget _buildGeofenceCard(BuildContext context, Geofence geofence) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: geofence.isActive
              ? Colors.blue.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: geofence.isActive
                            ? Colors.blue.withValues(alpha: 0.1)
                            : Colors.grey.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.pin_drop,
                        color: geofence.isActive ? Colors.blue : Colors.grey,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          geofence.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'ID: ${geofence.id}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                _buildStatusChip(geofence.isActive),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Icon(Icons.my_location, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Center: ${geofence.centerLat.toStringAsFixed(4)}, ${geofence.centerLng.toStringAsFixed(4)}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
            ),
            const SizedBox(height: 4),

            Row(
              children: [
                Icon(Icons.radar, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Radius: ${geofence.radiusMeters.toStringAsFixed(0)} meters',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // SQL Live Vehicle Count Chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.directions_car,
                        size: 14,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${geofence.activeVehicleCount} vehicles inside',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),

                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      tooltip: 'Edit Geofence',
                      onPressed: () => _showEditDialog(context, geofence),
                    ),
                    if (geofence.isActive)
                      IconButton(
                        icon: const Icon(
                          Icons.block,
                          size: 20,
                          color: Colors.red,
                        ),
                        tooltip: 'Deactivate Geofence',
                        onPressed: () => _confirmDeactivate(context, geofence),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.green.withValues(alpha: 0.12)
            : Colors.grey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isActive ? 'ACTIVE' : 'INACTIVE',
        style: TextStyle(
          color: isActive ? Colors.green[800] : Colors.grey[700],
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context) async {
    final cubit = context.read<GeofencesCubit>();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const GeofenceFormDialog(),
    );

    if (result != null) {
      await cubit.createGeofence(
        name: result['name'] as String,
        lat: result['lat'] as double,
        lng: result['lng'] as double,
        radiusMeters: result['radius'] as double,
      );
    }
  }

  void _showEditDialog(BuildContext context, Geofence geofence) async {
    final cubit = context.read<GeofencesCubit>();
    final result = await showDialog<Geofence>(
      context: context,
      builder: (_) => GeofenceFormDialog(geofence: geofence),
    );

    if (result != null) {
      await cubit.updateGeofence(result);
    }
  }

  void _confirmDeactivate(BuildContext context, Geofence geofence) async {
    final cubit = context.read<GeofencesCubit>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate Geofence?'),
        content: Text(
          'Deactivating "${geofence.name}" will stop future transition detection for this area while preserving historical trip data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await cubit.deactivateGeofence(geofence.id);
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No Geofences Found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Create geofences to track vehicle entries, exits, and trip generation.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
