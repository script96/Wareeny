import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Thin wrapper around [Geolocator] that handles permissions and provides
/// a single one-shot fix for the current device location.
class LocationService {
  /// Returns the current GPS position, or [null] if permission is denied
  /// or the location fetch fails.
  Future<Position?> getCurrentPosition() async {
    try {
      // Check & request permission.
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        debugPrint('[LocationService] Permission denied.');
        return null;
      }

      // Try a fast last-known fix first (saves time in emergencies).
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        debugPrint('[LocationService] Using last-known position: ${last.latitude}, ${last.longitude}');
        return last;
      }

      // Otherwise get a fresh fix with a reasonable timeout.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      debugPrint('[LocationService] Fresh fix: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      debugPrint('[LocationService] Error: $e');
      return null;
    }
  }

  /// Converts a [Position] into a shareable Google Maps link.
  String toGoogleMapsLink(Position position) {
    return 'https://maps.google.com/?q=${position.latitude},${position.longitude}';
  }

  /// Formats coordinates as a plain text fallback.
  String toCoordinateText(Position position) {
    final lat = position.latitude.toStringAsFixed(6);
    final lng = position.longitude.toStringAsFixed(6);
    return '$lat, $lng';
  }
}
