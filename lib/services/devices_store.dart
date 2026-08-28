import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Offline cache for the Devices tab (user rule 2026-08-20 "user can
/// update device status offline; when online data will be sent").
///
/// Two lists, keyed PER USER (same isolation rule as [AttendanceStore]):
///   * `devices` — the master `/devices/status` list for the picker
///   * `history` — the last `/devices/history` fetch (last year), used
///     to compute `_lockedThisMonth` + carry-forward previous status
///
/// On a successful API load the store is overwritten; on the next
/// offline load the tab hydrates from here so the counsellor can still
/// pick statuses. Submit already goes through [SyncService]'s offline
/// queue, so the mutation waits for connectivity all by itself.
class DevicesStore {
  static const _prefix = 'devices_cache_v1';

  final SharedPreferences _prefs;
  DevicesStore._(this._prefs);

  static Future<DevicesStore> open() async =>
      DevicesStore._(await SharedPreferences.getInstance());

  String _k(String userKey, String part) => '$_prefix:$userKey:$part';

  Future<void> saveDevices(
      String userKey, List<Map<String, dynamic>> rows) async {
    await _prefs.setString(_k(userKey, 'devices'), jsonEncode(rows));
  }

  List<Map<String, dynamic>> loadDevices(String userKey) =>
      _loadList(_k(userKey, 'devices'));

  Future<void> saveHistory(
      String userKey, List<Map<String, dynamic>> rows) async {
    await _prefs.setString(_k(userKey, 'history'), jsonEncode(rows));
  }

  List<Map<String, dynamic>> loadHistory(String userKey) =>
      _loadList(_k(userKey, 'history'));

  List<Map<String, dynamic>> _loadList(String key) {
    final s = _prefs.getString(key);
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
    for (final part in const ['devices', 'history']) {
      await _prefs.remove(_k(userKey, part));
    }
  }
}
