import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Offline cache of the `/staff` roster used by the counsellor Register
/// form's "Assigned Doctor" dropdown (user bug 2026-08-20: "offline
/// doctor not downloading, empty dropdown → validation blocks submit").
///
/// Keyed by role + facility_id so a counsellor at facility 25 sees only
/// facility 25's doctors, and a shared handset that later logs in at a
/// different facility gets a fresh list.
class StaffCacheStore {
  static const _prefix = 'staff_cache_v1';

  final SharedPreferences _prefs;
  StaffCacheStore._(this._prefs);

  static Future<StaffCacheStore> open() async =>
      StaffCacheStore._(await SharedPreferences.getInstance());

  String _k(String role, int facilityId) => '$_prefix:$role:$facilityId';

  Future<void> save(
      String role, int facilityId, List<Map<String, dynamic>> rows) async {
    await _prefs.setString(_k(role, facilityId), jsonEncode(rows));
  }

  List<Map<String, dynamic>> load(String role, int facilityId) {
    final s = _prefs.getString(_k(role, facilityId));
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
}
