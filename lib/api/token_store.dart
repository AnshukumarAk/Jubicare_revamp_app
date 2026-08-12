import 'package:shared_preferences/shared_preferences.dart';

/// Persistent JWT storage for the JubiCare backend (v2 API §1).
///
/// Access token: 1 h. Refresh token: 30 d, ROTATED on every use — so the
/// value returned by /api/auth/refresh must replace the previous refresh
/// token straight away. Presenting a consumed refresh returns 401
/// SIGNED_OUT_REMOTELY and kills the session on the server.
///
/// Everything is stored via SharedPreferences alongside the existing
/// `logged_in` flag from AuthPersistence — same storage backend, so
/// clearing one clears the other on logout.
class TokenStore {
  static const _kAccessToken       = 'jwt_access_token';
  static const _kRefreshToken      = 'jwt_refresh_token';
  static const _kAccessExpiresAt   = 'jwt_access_expires_at';
  static const _kRefreshExpiresAt  = 'jwt_refresh_expires_at';

  /// Persist a login/refresh response.
  static Future<void> save({
    required String accessToken,
    required String refreshToken,
    required DateTime accessExpiresAt,
    required DateTime refreshExpiresAt,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kAccessToken,      accessToken);
    await p.setString(_kRefreshToken,     refreshToken);
    await p.setString(_kAccessExpiresAt,  accessExpiresAt.toIso8601String());
    await p.setString(_kRefreshExpiresAt, refreshExpiresAt.toIso8601String());
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kAccessToken);
    await p.remove(_kRefreshToken);
    await p.remove(_kAccessExpiresAt);
    await p.remove(_kRefreshExpiresAt);
  }

  static Future<StoredTokens?> load() async {
    final p = await SharedPreferences.getInstance();
    final access  = p.getString(_kAccessToken);
    final refresh = p.getString(_kRefreshToken);
    if (access == null || refresh == null) return null;
    return StoredTokens(
      accessToken:      access,
      refreshToken:     refresh,
      accessExpiresAt:  DateTime.tryParse(p.getString(_kAccessExpiresAt)  ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      refreshExpiresAt: DateTime.tryParse(p.getString(_kRefreshExpiresAt) ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class StoredTokens {
  final String accessToken;
  final String refreshToken;
  final DateTime accessExpiresAt;
  final DateTime refreshExpiresAt;
  const StoredTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.accessExpiresAt,
    required this.refreshExpiresAt,
  });

  /// Access token is stale when it's within a 30-second window of its
  /// stated expiry — refresh proactively so an in-flight request never
  /// bounces on 401 TOKEN_EXPIRED for a race we could have avoided.
  bool get accessExpired => DateTime.now().isAfter(
        accessExpiresAt.subtract(const Duration(seconds: 30)));

  bool get refreshExpired => DateTime.now().isAfter(refreshExpiresAt);
}
