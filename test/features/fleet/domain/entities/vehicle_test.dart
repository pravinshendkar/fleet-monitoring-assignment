import 'package:fleet_console/features/fleet/domain/entities/vehicle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Vehicle Entity & Status Rule Tests', () {
    final now = DateTime(2026, 8, 25, 10, 0, 0);

    test(
      '1. OFFLINE precedence: lastSeenAt > 10 mins ago overrides speed and ignition',
      () {
        final status = Vehicle.calculateStatus(
          lastSeenAt: now.subtract(const Duration(minutes: 11)),
          speed: 60.0,
          ignition: true,
          relativeTo: now,
        );
        expect(status, VehicleStatus.offline);
      },
    );

    test('2. MOVING precedence: recent ping with speed > 0', () {
      final status = Vehicle.calculateStatus(
        lastSeenAt: now.subtract(const Duration(minutes: 2)),
        speed: 25.0,
        ignition: true,
        relativeTo: now,
      );
      expect(status, VehicleStatus.moving);
    });

    test(
      '3. IDLE precedence: recent ping with speed == 0 and ignition == true',
      () {
        final status = Vehicle.calculateStatus(
          lastSeenAt: now.subtract(const Duration(minutes: 1)),
          speed: 0.0,
          ignition: true,
          relativeTo: now,
        );
        expect(status, VehicleStatus.idle);
      },
    );

    test(
      '4. STOPPED precedence: recent ping with speed == 0 and ignition == false',
      () {
        final status = Vehicle.calculateStatus(
          lastSeenAt: now.subtract(const Duration(seconds: 30)),
          speed: 0.0,
          ignition: false,
          relativeTo: now,
        );
        expect(status, VehicleStatus.stopped);
      },
    );

    test('isStale returns true when lastSeenAt is older than 10 mins', () {
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

    test('isStale returns false when lastSeenAt is recent (< 10 mins)', () {
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
}
