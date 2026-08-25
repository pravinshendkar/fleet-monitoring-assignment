import 'package:fleet_console/core/utils/geo_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GeoUtils Tests', () {
    test(
      'calculateDistanceMeters should calculate correct distance between coordinates',
      () {
        // Distance between Bangalore (12.9716, 77.5946) and Mysore (12.2958, 76.6394) is ~125 km
        final distance = GeoUtils.calculateDistanceMeters(
          12.9716,
          77.5946,
          12.2958,
          76.6394,
        );
        expect(distance / 1000, closeTo(125.0, 10.0));
      },
    );

    test('isInsideGeofence returns true for points within radius', () {
      final isInside = GeoUtils.isInsideGeofence(
        12.9716,
        77.5946,
        12.9720,
        77.5950,
        1000.0,
      );
      expect(isInside, isTrue);
    });

    test('isInsideGeofence returns false for points outside radius', () {
      final isInside = GeoUtils.isInsideGeofence(
        12.9716,
        77.5946,
        13.5000,
        78.5000,
        1000.0,
      );
      expect(isInside, isFalse);
    });
  });
}
