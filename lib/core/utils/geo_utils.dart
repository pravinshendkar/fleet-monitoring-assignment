import 'dart:math';

class GeoUtils {
  /// Calculates distance in meters between two lat/lng coordinates using the Haversine formula.
  static double calculateDistanceMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadiusMeters = 6371000.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusMeters * c;
  }

  /// Returns true if coordinate (lat, lng) is within [radiusMeters] of (centerLat, centerLng).
  static bool isInsideGeofence(
    double lat,
    double lng,
    double centerLat,
    double centerLng,
    double radiusMeters,
  ) {
    final distance = calculateDistanceMeters(lat, lng, centerLat, centerLng);
    return distance <= radiusMeters;
  }

  static double _toRadians(double degree) {
    return degree * pi / 180.0;
  }
}
