import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Per-appointment cache of `/api/appointments/{id}` full detail
/// (symptoms + vitals + counsellor_remarks + prescription lines).
///
/// The doctor Case Details screen used to go blank offline because it
/// depends on this endpoint; the queue list doesn't carry symptoms /
/// full vitals. Now the last successful detail is persisted, so the
/// doctor can open a case and edit it offline (user rule 2026-08-20
/// "app is online offline both, all users all roles all tabs").
///
/// Cap: last 100 appointments per user (LRU on write). Keys are
/// role-scoped so a shared handset doesn't leak across users.
class AppointmentDetailStore {
  static const _prefix = 'appt_detail_cache_v1';
  static const _cap = 100;

  final SharedPreferences _prefs;
  AppointmentDetailStore._(this._prefs);

  static Future<AppointmentDetailStore> open() async =>
      AppointmentDetailStore._(await SharedPreferences.getInstance());

  String _k(String userKey) => '$_prefix:$userKey';

  /// Save a single appointment detail, LRU-evicting the oldest when the
  /// per-user cap is reached.
  Future<void> save(
      String userKey, int appointmentId, Map<String, dynamic> detail) async {
    final k = _k(userKey);
    final map = _loadMap(k);
    map[appointmentId.toString()] = {
      'at': DateTime.now().toIso8601String(),
      'detail': detail,
    };
    // LRU eviction: sort by 'at', keep newest _cap.
    if (map.length > _cap) {
      final sorted = map.entries.toList()
        ..sort((a, b) {
          final ta = DateTime.tryParse('${a.value['at']}') ?? DateTime(1970);
          final tb = DateTime.tryParse('${b.value['at']}') ?? DateTime(1970);
          return tb.compareTo(ta);
        });
      map
        ..clear()
        ..addEntries(sorted.take(_cap));
    }
    await _prefs.setString(k, jsonEncode(map));
  }

  Map<String, dynamic>? load(String userKey, int appointmentId) {
    final map = _loadMap(_k(userKey));
    final entry = map[appointmentId.toString()];
    if (entry is Map && entry['detail'] is Map) {
      return (entry['detail'] as Map).cast<String, dynamic>();
    }
    return null;
  }

  Map<String, dynamic> _loadMap(String key) {
    final s = _prefs.getString(key);
    if (s == null || s.isEmpty) return {};
    try {
      final v = jsonDecode(s);
      if (v is! Map) return {};
      return v.cast<String, dynamic>();
    } catch (_) {
      return {};
    }
  }

  Future<void> clearUser(String userKey) async {
    await _prefs.remove(_k(userKey));
  }
}
