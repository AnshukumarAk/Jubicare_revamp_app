import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// Persistent login (rule 2026-08-05): stores a flag + the logged-in role
/// so the next app launch skips the login screen and lands the user
/// directly on their role shell. Cleared on explicit logout.
///
/// From 0.21+ (backend wiring, 2026-08-11) also caches the /auth/login
/// `user` block so AppState can render facility name / state / district
/// before /auth/me returns.
///
/// Storage layout:
///   `logged_in`   → "yes" | "no"
///   `role`        → "counselor" | "doctor" | "pharmacist"
///   `username`    → what the user typed
///   `mmu_id`      → optional MMU tag for counsellor location tracking
///   `backend_user`→ JSON blob of the last-known /auth/login user object
class AuthPersistence {
  static const _kLoggedIn    = 'logged_in';
  static const _kRole        = 'role';
  static const _kUsername    = 'username';
  static const _kMmuId       = 'mmu_id';
  static const _kBackendUser = 'backend_user';

  /// Save the logged-in session after a successful login.
  static Future<void> save({
    required Role role,
    required String username,
    String? mmuId,
    Map<String, dynamic>? backendUser,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLoggedIn, 'yes');
    await p.setString(_kRole,     role.name);
    await p.setString(_kUsername, username);
    if (mmuId == null) {
      await p.remove(_kMmuId);
    } else {
      await p.setString(_kMmuId, mmuId);
    }
    if (backendUser == null) {
      await p.remove(_kBackendUser);
    } else {
      await p.setString(_kBackendUser, jsonEncode(backendUser));
    }
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kLoggedIn);
    await p.remove(_kRole);
    await p.remove(_kUsername);
    await p.remove(_kMmuId);
    await p.remove(_kBackendUser);
  }

  /// Read the stored session. Returns null when the flag is unset or the
  /// stored role can't be matched to a known Role — main.dart treats that
  /// as "not logged in" and falls back to the splash / login flow.
  static Future<StoredSession?> load() async {
    final p = await SharedPreferences.getInstance();
    if ((p.getString(_kLoggedIn) ?? 'no') != 'yes') return null;
    final roleName = p.getString(_kRole);
    if (roleName == null) return null;
    Role? role;
    for (final r in Role.values) {
      if (r.name == roleName) { role = r; break; }
    }
    if (role == null) return null;
    Map<String, dynamic>? backendUser;
    final raw = p.getString(_kBackendUser);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) backendUser = decoded.cast<String, dynamic>();
      } catch (_) { /* stale cache */ }
    }
    return StoredSession(
      role:        role,
      username:    p.getString(_kUsername) ?? role.fullName,
      mmuId:       p.getString(_kMmuId),
      backendUser: backendUser,
    );
  }
}

/// Restored session read at app start.
class StoredSession {
  final Role role;
  final String username;
  final String? mmuId;
  final Map<String, dynamic>? backendUser;
  const StoredSession({
    required this.role,
    required this.username,
    this.mmuId,
    this.backendUser,
  });
}
