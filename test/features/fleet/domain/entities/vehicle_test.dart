import 'package:fleet_console/features/fleet/data/models/vehicle_model.dart';
import 'package:fleet_console/features/fleet/domain/entities/signal_reading.dart';
import 'package:fleet_console/features/fleet/domain/entities/vehicle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Vehicle.calculateStatus() business rules', () {
    final now = DateTime(2026, 8, 25, 10, 0, 0);

    test('1. stale (>10 min) → OFFLINE regardless of speed and ignition', () {
      final status = Vehicle.calculateStatus(
        lastSeenAt: now.subtract(const Duration(minutes: 11)),
        speed: 60.0,
        ignition: true,
        relativeTo: now,
      );
      expect(status, VehicleStatus.offline);
    });

    test('2. speed > 0 → MOVING', () {
      final status = Vehicle.calculateStatus(
        lastSeenAt: now.subtract(const Duration(minutes: 2)),
        speed: 25.0,
        ignition: true,
        relativeTo: now,
      );
      expect(status, VehicleStatus.moving);
    });

    test('3. speed == 0, ignition on → IDLE', () {
      final status = Vehicle.calculateStatus(
        lastSeenAt: now.subtract(const Duration(minutes: 1)),
        speed: 0.0,
        ignition: true,
        relativeTo: now,
      );
      expect(status, VehicleStatus.idle);
    });

    test('4. speed == 0, ignition off → STOPPED', () {
      final status = Vehicle.calculateStatus(
        lastSeenAt: now.subtract(const Duration(seconds: 30)),
        speed: 0.0,
        ignition: false,
        relativeTo: now,
      );
      expect(status, VehicleStatus.stopped);
    });
  });

  group('Vehicle.isStale', () {
    test('returns true when lastSeenAt is older than 10 mins', () {
      final staleVehicle = Vehicle(
        id: 'v1',
        name: 'EV-01',
        status: VehicleStatus.offline,
        lastLatitude: 12.9716,
        lastLongitude: 77.5946,
        lastSoc: 40.0,
        lastSeenAt: DateTime.now().subtract(const Duration(minutes: 11)),
        ignition: false,
      );
      expect(staleVehicle.isStale, isTrue);
    });

    test('returns false when lastSeenAt is recent (< 10 mins)', () {
      final recentVehicle = Vehicle(
        id: 'v2',
        name: 'EV-02',
        status: VehicleStatus.moving,
        lastLatitude: 12.9716,
        lastLongitude: 77.5946,
        lastSoc: 85.0,
        lastSeenAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ignition: true,
      );
      expect(recentVehicle.isStale, isFalse);
    });
  });

  group('VehicleModel timestamp conversion', () {
    // Helper: simulates the DuckDB round-trip for timestamps.
    // Storage path: DateTime → .toUtc().toIso8601String() → DuckDB strips Z
    // Read path: naive UTC string → parseUtcDateTime appends Z → parses as UTC
    String duckdbTimestamp(DateTime dt) =>
        dt.toUtc().toIso8601String().replaceAll('Z', '');

    test('fromMap converts stale stored status to offline', () {
      final map = {
        'vehicle_id': 'EV-099',
        'name': 'EV-099',
        'status': 'moving',
        'last_latitude': 12.9716,
        'last_longitude': 77.5946,
        'last_soc': 50.0,
        'last_seen_at': duckdbTimestamp(
          DateTime.now().subtract(const Duration(minutes: 15)),
        ),
        'ignition': true,
      };

      final vehicle = VehicleModel.fromMap(map);
      expect(vehicle.status, equals(VehicleStatus.offline));
    });

    test('fromMap preserves non-stale stored status', () {
      final map = {
        'vehicle_id': 'EV-100',
        'name': 'EV-100',
        'status': 'moving',
        'last_latitude': 12.9716,
        'last_longitude': 77.5946,
        'last_soc': 50.0,
        'last_seen_at': duckdbTimestamp(
          DateTime.now().subtract(const Duration(minutes: 2)),
        ),
        'ignition': true,
      };

      final vehicle = VehicleModel.fromMap(map);
      expect(vehicle.status, equals(VehicleStatus.moving));
    });

    test('generated historical timestamps remain in the past', () {
      final now = DateTime.now();
      // Simulate what the seed generator produces: now.subtract(pingAge)
      final historicalTs = now.subtract(const Duration(minutes: 3));
      // Simulate the storage path: .toUtc().toIso8601String()
      final storedString = historicalTs.toUtc().toIso8601String();

      // Simulate the read path: parseUtcDateTime
      final parsed = VehicleModel.parseUtcDateTime(storedString);

      // The parsed time should be in the past
      final diff = DateTime.now().difference(parsed);
      expect(
        diff.isNegative,
        isFalse,
        reason: 'Parsed timestamp must not be in the future',
      );
      expect(
        diff.inMinutes,
        greaterThanOrEqualTo(2),
        reason: 'Should be approximately 3 minutes ago',
      );
    });

    test('naive datetime string without timezone treated as UTC', () {
      // DuckDB TIMESTAMP columns return naive strings like '2026-08-25 08:30:00'
      final utcNow = DateTime.now().toUtc();
      final naiveStr =
          '${utcNow.year}-${utcNow.month.toString().padLeft(2, '0')}-${utcNow.day.toString().padLeft(2, '0')} '
          '${utcNow.hour.toString().padLeft(2, '0')}:${utcNow.minute.toString().padLeft(2, '0')}:${utcNow.second.toString().padLeft(2, '0')}';

      final parsed = VehicleModel.parseUtcDateTime(naiveStr);
      final diff = DateTime.now().difference(parsed);

      // Should be very close to now (within 2 seconds), not offset by timezone
      expect(
        diff.inSeconds.abs(),
        lessThan(2),
        reason: 'Naive UTC string should parse to approximately now',
      );
    });
  });

  group('SignalReading.ageString', () {
    test('never returns negative ago strings', () {
      final futureSignal = SignalReading(
        label: 'SOC',
        displayValue: '80%',
        timestamp: DateTime.now().add(const Duration(minutes: 5)),
        verdict: SignalVerdict.normal,
      );

      expect(futureSignal.ageString, equals('Just now'));
      expect(futureSignal.ageString.contains('-'), isFalse);
    });
  });
}
