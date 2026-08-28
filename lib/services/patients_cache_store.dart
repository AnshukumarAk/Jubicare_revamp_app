import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Offline cache for the shared patient / queue list (user bug 2026-08-20
/// "online download data → close app → offline → registered patient not
/// showing"). CounsellorState.patients used to live only in memory, so
/// every app restart wiped it and the Home tab was empty until the next
/// online refresh.
///
/// Same per-user isolation rule as the other stores — keyed by
/// `{role}_{userId}` so a shared handset never leaks Anshu's cache into
/// Divya's login.
class PatientsCacheStore {
  static const _prefix = 'patients_cache_v1';

  final SharedPreferences _prefs;
  PatientsCacheStore._(this._prefs);

  static Future<PatientsCacheStore> open() async =>
      PatientsCacheStore._(await SharedPreferences.getInstance());

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

  Future<void> clearUser(String userKey) async {
    await _prefs.remove(_k(userKey));
  }
}
