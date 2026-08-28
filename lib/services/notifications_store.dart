import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Per-user notification history (user 2026-08-19: "saved notification
/// user wise, user can see notification later"). Every notification the
/// app shows or receives is appended here; the bell sheet lists them.
///
/// Storage: SharedPreferences, newest first, capped at 50 per user.
/// `lastSeen` per user powers the unread badge dot.
class NotificationsStore {
  static const _prefix = 'notif_history_v1';
  static const _cap = 50;
  static const _kActiveUser = 'notif_active_user_key';

  /// Active user's key — set at login / app start so [add] (called from
  /// singleton services without a BuildContext) knows whose history to
  /// append to. Cleared on logout. Also persisted to SharedPreferences so
  /// the background FCM handler in a fresh isolate can still find it when
  /// the app is killed (user rule 2026-08-20 "save notification when user
  /// inside app, outside app, or kill app").
  static String? currentUserKey;

  /// Set + persist so the background isolate can recover the same user.
  static Future<void> setCurrentUser(String? key) async {
    currentUserKey = key;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (key == null || key.isEmpty) {
        await prefs.remove(_kActiveUser);
      } else {
        await prefs.setString(_kActiveUser, key);
      }
    } catch (_) {/* best-effort */}
  }

  /// Resolve the active-user key. In-memory first (main isolate); falls
  /// back to SharedPreferences (background isolate, freshly spun up).
  static Future<String?> _resolveUserKey() async {
    if (currentUserKey != null && currentUserKey!.isNotEmpty) {
      return currentUserKey;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getString(_kActiveUser);
      if (v != null && v.isNotEmpty) {
        currentUserKey = v;
        return v;
      }
    } catch (_) {}
    return null;
  }

  /// [id] — FCM messageId, used to dedupe the same push arriving through
  /// two paths (background isolate save + tray-tap save — user 2026-08-26
  /// "saving two times when outside app / killed").
  /// [targetUid] — the backend user id the push was addressed to (rides
  /// in the FCM data payload). When it doesn't match the ACTIVE user the
  /// push is dropped, so a shared handset never files the previous
  /// user's notifications under the new login (user 2026-08-26).
  static Future<void> add({required String title, required String body,
      String? id, String? targetUid}) async {
    final key = await _resolveUserKey();
    if (key == null || key.isEmpty) return;
    if (targetUid != null && targetUid.isNotEmpty && targetUid != key) {
      return; // addressed to a different user of this handset
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final k = '$_prefix:$key:items';
      final list = _decode(prefs.getString(k));
      // Dedupe 1: same FCM messageId already stored.
      if (id != null && id.isNotEmpty &&
          list.any((e) => e['id'] == id)) {
        return;
      }
      // Dedupe 2: identical title+body stored within the last 10 minutes
      // (covers double sends with no messageId).
      final now = DateTime.now();
      for (final e in list.take(10)) {
        if (e['title'] == title && e['body'] == body) {
          final at = DateTime.tryParse('${e['at']}');
          if (at != null && now.difference(at).inMinutes < 10) return;
        }
      }
      list.insert(0, {
        'title': title,
        'body': body,
        if (id != null && id.isNotEmpty) 'id': id,
        'at': now.toIso8601String(),
      });
      while (list.length > _cap) {
        list.removeLast();
      }
      await prefs.setString(k, jsonEncode(list));
    } catch (_) {/* history is a courtesy */}
  }

  static Future<List<Map<String, dynamic>>> list() async {
    final key = currentUserKey;
    if (key == null || key.isEmpty) return const [];
    try {
      final prefs = await SharedPreferences.getInstance();
      return _decode(prefs.getString('$_prefix:$key:items'));
    } catch (_) {
      return const [];
    }
  }

  /// Items newer than the last time the bell sheet was opened.
  static Future<int> unreadCount() async {
    final key = currentUserKey;
    if (key == null || key.isEmpty) return 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = DateTime.tryParse(
          prefs.getString('$_prefix:$key:seen') ?? '');
      final items = _decode(prefs.getString('$_prefix:$key:items'));
      if (seen == null) return items.length;
      var n = 0;
      for (final e in items) {
        final at = DateTime.tryParse('${e['at']}');
        if (at != null && at.isAfter(seen)) n++;
      }
      return n;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> markSeen() async {
    final key = currentUserKey;
    if (key == null || key.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          '$_prefix:$key:seen', DateTime.now().toIso8601String());
    } catch (_) {/* ignore */}
  }

  static List<Map<String, dynamic>> _decode(String? s) {
    if (s == null || s.isEmpty) return [];
    try {
      final v = jsonDecode(s);
      if (v is! List) return [];
      return [
        for (final e in v)
          if (e is Map) e.cast<String, dynamic>(),
      ];
    } catch (_) {
      return [];
    }
  }
}
