import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationService {
  static Position? _cachedPosition;
  static const String _kLastLat = 'gps_last_lat';
  static const String _kLastLng = 'gps_last_lng';
  static const String _kLastTimestamp = 'gps_last_timestamp';
  static const String _kLastAccuracy = 'gps_last_accuracy';
  static const String _kLastAltitude = 'gps_last_altitude';
  static const String _kLastAltitudeAccuracy = 'gps_last_altitude_accuracy';
  static const String _kLastHeading = 'gps_last_heading';
  static const String _kLastHeadingAccuracy = 'gps_last_heading_accuracy';
  static const String _kLastSpeed = 'gps_last_speed';
  static const String _kLastSpeedAccuracy = 'gps_last_speed_accuracy';
  static const String _kLastIsMocked = 'gps_last_is_mocked';

  static Future<Position?> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return _cachedPosition ?? await _loadPersistedPosition();

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return _cachedPosition ?? await _loadPersistedPosition();
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return _cachedPosition ?? await _loadPersistedPosition();
    }

    // 1. BEST PRACTICE: First try to get the last known position.
    // If it's less than 5 minutes old, use it immediately to save battery and time!
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) {
      final difference = DateTime.now().difference(last.timestamp);
      if (difference.inMinutes < 5) {
        _cachedPosition = last;
        await _persistPosition(last);
        return last;
      }
    }

    // 2. Otherwise request a fresh high-accuracy position.
    try {
      const settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 8),
      );
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      );
      _cachedPosition = pos;
      await _persistPosition(pos);
      return pos;
    } catch (_) {
      // If fresh request fails or times out, fallback to last known regardless of age.
      if (last != null) {
        _cachedPosition = last;
        await _persistPosition(last);
        return last;
      }
      return _cachedPosition ?? await _loadPersistedPosition();
    }
  }

  static Future<void> _persistPosition(Position position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kLastLat, position.latitude);
    await prefs.setDouble(_kLastLng, position.longitude);
    await prefs.setInt(
      _kLastTimestamp,
      position.timestamp.millisecondsSinceEpoch,
    );
    await prefs.setDouble(_kLastAccuracy, position.accuracy);
    await prefs.setDouble(_kLastAltitude, position.altitude);
    await prefs.setDouble(_kLastAltitudeAccuracy, position.altitudeAccuracy);
    await prefs.setDouble(_kLastHeading, position.heading);
    await prefs.setDouble(_kLastHeadingAccuracy, position.headingAccuracy);
    await prefs.setDouble(_kLastSpeed, position.speed);
    await prefs.setDouble(_kLastSpeedAccuracy, position.speedAccuracy);
    await prefs.setBool(_kLastIsMocked, position.isMocked);
  }

  static Future<Position?> _loadPersistedPosition() async {
    if (_cachedPosition != null) return _cachedPosition;
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_kLastLat);
    final lng = prefs.getDouble(_kLastLng);
    if (lat == null || lng == null) return null;
    final timestampMs = prefs.getInt(_kLastTimestamp);
    final timestamp = timestampMs != null
        ? DateTime.fromMillisecondsSinceEpoch(timestampMs, isUtc: true)
        : DateTime.now().toUtc();
    final position = Position(
      latitude: lat,
      longitude: lng,
      timestamp: timestamp,
      accuracy: prefs.getDouble(_kLastAccuracy) ?? 0.0,
      altitude: prefs.getDouble(_kLastAltitude) ?? 0.0,
      altitudeAccuracy: prefs.getDouble(_kLastAltitudeAccuracy) ?? 0.0,
      heading: prefs.getDouble(_kLastHeading) ?? 0.0,
      headingAccuracy: prefs.getDouble(_kLastHeadingAccuracy) ?? 0.0,
      speed: prefs.getDouble(_kLastSpeed) ?? 0.0,
      speedAccuracy: prefs.getDouble(_kLastSpeedAccuracy) ?? 0.0,
      isMocked: prefs.getBool(_kLastIsMocked) ?? false,
    );
    _cachedPosition = position;
    return position;
  }
}
