import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Offline cache for the Attend tab (user rule 2026-08-18: "every role
/// attendance should be fully functional offline").
///
/// What it holds, all keyed PER USER (rule 2026-08-16 — no cross-user
/// leakage; Anshu's rows must never render under Divya's login):
///  * `today`   — the server-shaped row from /attendance/today (or the
///    locally-built equivalent when the check-in happened offline)
///  * `history` — the last /attendance list fetch (server-shaped rows)
///  * `anchors` — /camps/anchors for the user's facility, so the GPS
///    location snap works with no signal
///
/// Reads fall back to this store whenever the network calls fail; every
/// successful fetch overwrites it. SharedPreferences is fine for the
/// volume involved (≤ ~30 rows of JSON).
class AttendanceStore {
  static const _prefix = 'attend_cache_v1';

  final SharedPreferences _prefs;
  AttendanceStore._(this._prefs);

  static Future<AttendanceStore> open() async =>
      AttendanceStore._(await SharedPreferences.getInstance());

  String _k(String userKey, String part) => '$_prefix:$userKey:$part';

  // ── snapshots (today + history + anchors) ─────────────────────────

  Future<void> saveToday(String userKey, Map<String, dynamic>? row) async {
    final k = _k(userKey, 'today');
    if (row == null) {
      await _prefs.remove(k);
    } else {
      await _prefs.setString(k, jsonEncode(row));
    }
  }

  Map<String, dynamic>? loadToday(String userKey) {
    final s = _prefs.getString(_k(userKey, 'today'));
    if (s == null || s.isEmpty) return null;
    try {
      final v = jsonDecode(s);
      return v is Map ? v.cast<String, dynamic>() : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveHistory(
      String userKey, List<Map<String, dynamic>> rows) async {
    await _prefs.setString(_k(userKey, 'history'), jsonEncode(rows));
  }

  List<Map<String, dynamic>> loadHistory(String userKey) =>
      _loadList(_k(userKey, 'history'));

  Future<void> saveAnchors(
      String userKey, List<Map<String, dynamic>> rows) async {
    await _prefs.setString(_k(userKey, 'anchors'), jsonEncode(rows));
  }

  List<Map<String, dynamic>> loadAnchors(String userKey) =>
      _loadList(_k(userKey, 'anchors'));

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

  /// Wipe one user's cached attendance (called on logout alongside the
  /// CounsellorState reset so a fresh login starts clean).
  Future<void> clearUser(String userKey) async {
    for (final part in const ['today', 'history', 'anchors']) {
      await _prefs.remove(_k(userKey, part));
    }
  }
}
