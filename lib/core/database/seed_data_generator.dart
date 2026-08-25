import 'dart:math';
import '../../features/fleet/domain/entities/telemetry_packet.dart';
import '../../features/geofences/domain/entities/geofence.dart';

class SeedDataGenerator {
  /// Generates deterministic seed data for 500 electric vehicles around Bangalore, India.
  /// Fixed seed Random(42) guarantees exact reproducibility across app restarts.
  static List<TelemetryPacket> generateSeedTelemetry({
    int vehicleCount = 500,
    DateTime? baseTime,
  }) {
    final rng = Random(42);
    final now = baseTime ?? DateTime.now();
    final packets = <TelemetryPacket>[];

    // Center coordinates: Bangalore (12.9716, 77.5946)
    const baseLat = 12.9716;
    const baseLng = 77.5946;

    for (var i = 1; i <= vehicleCount; i++) {
      final vid = 'EV-${i.toString().padLeft(3, '0')}';

      // Determine status category deterministically
      // 0..199: moving, 200..299: idle, 300..399: stopped, 400..499: offline
      final category = i % 4;

      late double speed;
      late bool ignition;
      late Duration pingAge;
      late double soc;
      late double temp;

      switch (category) {
        case 0: // MOVING
          speed = 15.0 + rng.nextDouble() * 55.0; // 15 to 70 km/h
          ignition = true;
          pingAge = Duration(seconds: rng.nextInt(180)); // 0-3 mins ago
          soc = 30.0 + rng.nextDouble() * 65.0;
          temp = 25.0 + rng.nextDouble() * 15.0;
          break;
        case 1: // IDLE
          speed = 0.0;
          ignition = true;
          pingAge = Duration(seconds: rng.nextInt(240));
          soc = 25.0 + rng.nextDouble() * 70.0;
          temp = 25.0 + rng.nextDouble() * 12.0;
          break;
        case 2: // STOPPED
          speed = 0.0;
          ignition = false;
          pingAge = Duration(seconds: rng.nextInt(300));
          soc = 20.0 + rng.nextDouble() * 75.0;
          temp = 22.0 + rng.nextDouble() * 10.0;
          break;
        case 3: // OFFLINE
        default:
          speed = 0.0;
          ignition = false;
          pingAge = Duration(minutes: 12 + rng.nextInt(60)); // > 10 mins ago!
          soc = 15.0 + rng.nextDouble() * 50.0;
          temp = 22.0 + rng.nextDouble() * 10.0;
          break;
      }

      // Inject specific alert conditions deterministically
      if (i == 10 || i == 50) {
        soc = 15.0; // Low Battery Warning (< 20%)
      } else if (i == 20 || i == 60) {
        soc = 8.0; // Critical Battery Escalation (< 10%)
      } else if (i == 30 || i == 70) {
        temp = 49.5; // Overheating (> 45°C)
      }

      // Location spread (+/- 0.05 degrees ~ 5km radius)
      final latOffset = (rng.nextDouble() - 0.5) * 0.1;
      final lngOffset = (rng.nextDouble() - 0.5) * 0.1;

      final eventTimestamp = now.subtract(pingAge);

      packets.add(
        TelemetryPacket(
          packetId: 'pkt_seed_${vid}_${eventTimestamp.millisecondsSinceEpoch}',
          vehicleId: vid,
          eventTimestamp: eventTimestamp,
          ingestTimestamp: now,
          latitude: baseLat + latOffset,
          longitude: baseLng + lngOffset,
          speed: speed,
          batteryLevel: soc,
          batteryTemp: temp,
          odometerKm: 5000.0 + (i * 25.0) + rng.nextInt(500),
          ignition: ignition,
          gpsAccuracy: 4.0 + rng.nextDouble() * 3.0,
        ),
      );
    }

    return packets;
  }

  /// Generates initial seed geofences around main Bangalore depots.
  static List<Geofence> generateSeedGeofences() {
    final now = DateTime.now();
    return [
      Geofence(
        id: 'gf_central_depot',
        name: 'Bangalore Central Depot',
        centerLat: 12.9716,
        centerLng: 77.5946,
        radiusMeters: 800.0,
        isActive: true,
        createdAt: now.subtract(const Duration(days: 30)),
      ),
      Geofence(
        id: 'gf_tech_park',
        name: 'Electronic City Charging Hub',
        centerLat: 12.8452,
        centerLng: 77.6602,
        radiusMeters: 600.0,
        isActive: true,
        createdAt: now.subtract(const Duration(days: 15)),
      ),
      Geofence(
        id: 'gf_north_hub',
        name: 'Hebbal Fleet Yard',
        centerLat: 13.0358,
        centerLng: 77.5970,
        radiusMeters: 500.0,
        isActive: false, // Inactive geofence test case
        createdAt: now.subtract(const Duration(days: 10)),
      ),
    ];
  }
}
