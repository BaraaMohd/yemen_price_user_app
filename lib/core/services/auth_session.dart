import 'package:shared_preferences/shared_preferences.dart';

class AuthSession {
  AuthSession._();

  static const String roleMerchant = 'merchant';
  static const String roleMinistry = 'ministry';

  static const String _kStoreName = 'store_name';
  static const String _kPhone = 'phone';
  static const String _kRole = 'role';
  static const String _kLat = 'lat';
  static const String _kLng = 'lng';
  static const String _kRating = 'rating';

  static Future<void> saveFromUser(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kStoreName, (userData[_kStoreName] ?? '').toString());
    await prefs.setString(_kPhone, (userData[_kPhone] ?? '').toString());
    await prefs.setString(_kRole, (userData[_kRole] ?? roleMerchant).toString());

    final lat = (userData[_kLat] as num?)?.toDouble() ?? 0.0;
    final lng = (userData[_kLng] as num?)?.toDouble() ?? 0.0;
    final rating = (userData[_kRating] as num?)?.toDouble() ?? 5.0;
    await prefs.setDouble(_kLat, lat);
    await prefs.setDouble(_kLng, lng);
    await prefs.setDouble(_kRating, rating);
  }

  static Future<Map<String, dynamic>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      _kStoreName: prefs.getString(_kStoreName) ?? '',
      _kPhone: prefs.getString(_kPhone) ?? '',
      _kRole: (prefs.getString(_kRole) ?? '').toLowerCase(),
      _kLat: prefs.getDouble(_kLat) ?? 0.0,
      _kLng: prefs.getDouble(_kLng) ?? 0.0,
      _kRating: prefs.getDouble(_kRating) ?? 5.0,
    };
  }

  static Future<String> role() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_kRole) ?? '').toLowerCase();
  }

  static Future<bool> hasMerchantSession() async {
    final s = await load();
    return s[_kRole] == roleMerchant &&
        (s[_kStoreName] as String).isNotEmpty &&
        (s[_kPhone] as String).isNotEmpty;
  }

  static Future<void> updateRating(double rating) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kRating, rating);
  }

  static Future<void> clearAuthOnly() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kStoreName);
    await prefs.remove(_kPhone);
    await prefs.remove(_kRole);
    await prefs.remove(_kLat);
    await prefs.remove(_kLng);
    await prefs.remove(_kRating);
  }
}
