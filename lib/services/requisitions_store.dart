import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Offline cache of the pharmacist `/requisitions` list. Without this
/// the Stock tab was empty on every offline app-open (user rule
/// 2026-08-20 "everything works online and offline"). Per-user keyed
/// like the other stores so a shared handset stays isolated.
class RequisitionsStore {
  static const _prefix = 'requisitions_cache_v1';

  final SharedPreferences _prefs;
  RequisitionsStore._(this._prefs);

  static Future<RequisitionsStore> open() async =>
      RequisitionsStore._(await SharedPreferences.getInstance());

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
