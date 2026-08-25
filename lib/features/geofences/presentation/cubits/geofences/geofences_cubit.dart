import 'dart:async';
import 'package:fleet_console/features/fleet/domain/repositories/vehicle_repository.dart';
import 'package:fleet_console/features/geofences/domain/entities/geofence.dart';
import 'package:fleet_console/features/geofences/domain/repositories/geofence_repository.dart';
import 'package:fleet_console/features/geofences/domain/usecases/create_geofence.dart';
import 'package:fleet_console/features/geofences/domain/usecases/deactivate_geofence.dart';
import 'package:fleet_console/features/geofences/domain/usecases/update_geofence.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'geofences_state.dart';

class GeofencesCubit extends Cubit<GeofencesState> {
  final GeofenceRepository geofenceRepository;
  final VehicleRepository vehicleRepository;
  final CreateGeofenceUseCase createGeofenceUseCase;
  final UpdateGeofenceUseCase updateGeofenceUseCase;
  final DeactivateGeofenceUseCase deactivateGeofenceUseCase;

  StreamSubscription? _dbSubscription;

  GeofencesCubit({
    required this.geofenceRepository,
    required this.vehicleRepository,
    required this.createGeofenceUseCase,
    required this.updateGeofenceUseCase,
    required this.deactivateGeofenceUseCase,
  }) : super(GeofencesInitial()) {
    _listenToDatabaseChanges();
  }

  void _listenToDatabaseChanges() {
    _dbSubscription = vehicleRepository.watchDatabaseChanges().listen((_) {
      loadGeofences();
    });
  }

  Future<void> loadGeofences() async {
    if (state is! GeofencesLoaded) {
      emit(GeofencesLoading());
    }

    try {
      final list = await geofenceRepository.getGeofences();
      emit(GeofencesLoaded(list));
    } catch (e) {
      emit(GeofencesError('Failed to load geofences: ${e.toString()}'));
    }
  }

  Future<void> createGeofence({
    required String name,
    required double lat,
    required double lng,
    required double radiusMeters,
  }) async {
    try {
      final geofence = Geofence(
        id: 'geo_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        centerLat: lat,
        centerLng: lng,
        radiusMeters: radiusMeters,
        isActive: true,
        createdAt: DateTime.now(),
      );

      await createGeofenceUseCase(geofence);
      await loadGeofences();
    } catch (e) {
      emit(GeofencesError('Failed to create geofence: ${e.toString()}'));
      await loadGeofences();
    }
  }

  Future<void> updateGeofence(Geofence geofence) async {
    try {
      await updateGeofenceUseCase(geofence);
      await loadGeofences();
    } catch (e) {
      emit(GeofencesError('Failed to update geofence: ${e.toString()}'));
      await loadGeofences();
    }
  }

  Future<void> deactivateGeofence(String geofenceId) async {
    try {
      await deactivateGeofenceUseCase(
        DeactivateGeofenceParams(geofenceId: geofenceId, isActive: false),
      );
      await loadGeofences();
    } catch (e) {
      emit(GeofencesError('Failed to deactivate geofence: ${e.toString()}'));
      await loadGeofences();
    }
  }

  @override
  Future<void> close() {
    _dbSubscription?.cancel();
    return super.close();
  }
}
