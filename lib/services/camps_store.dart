import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Offline cache for the Camps tab (online/offline parity rule): the last
/// successful GET /camps snapshot, per user. Reads fall back here when the
/// network call fails; every successful fetch overwrites it.
class CampsStore {
  static const _prefix = 'camps_cache_v1';

  final SharedPreferences _prefs;
  CampsStore._(this._prefs);

  static Future<CampsStore> open() async =>
      CampsStore._(await SharedPreferences.getInstance());

  String _k(String userKey) => '$_prefix:$userKey';

  Future<void> save(String userKey, List<Map<String, dynamic>> rows) async {
    await _prefs.setString(_k(userKey), jsonEncode(rows));
  }

  List<Map<String, dynamic>> load(String userKey) {
    final s = _prefs.getString(_k(userKey));
    if (s == null || s.isEmpty) return const [];
    try {
      final v = jsonDecode(s);
      if (v is! List) return const [];
      return [
        for (final e in v)
          if (e is Map) e.cast<String, dynamic>(),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> clearUser(String userKey) => _prefs.remove(_k(userKey));
}
