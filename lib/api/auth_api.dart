import 'api_client.dart';
import 'token_store.dart';

/// /api/auth/* endpoints from v2 §1.
class AuthApi {
  final ApiClient client;
  AuthApi(this.client);

  /// Sign in with username + password. Persists tokens + returns the
  /// user profile the app displays.
  Future<LoginResult> login(String username, String password) async {
    final res = await client.post('/auth/login', body: {
      'username': username, 'password': password,
    }, auth: false);
    if (res is! Map<String, dynamic>) {
      throw StateError('Unexpected login payload shape');
    }
    final tokens = _tokensFromPayload(res);
    await TokenStore.save(
      accessToken:      tokens.accessToken,
      refreshToken:     tokens.refreshToken,
      accessExpiresAt:  tokens.accessExpiresAt,
      refreshExpiresAt: tokens.refreshExpiresAt,
    );
    // The user block sits under `user` (v2 shape) but the older APK also
    // reads flat fields at the top level; either is fine.
    final userBlock = (res['user'] as Map?)?.cast<String, dynamic>() ?? res;
    return LoginResult(tokens: tokens, user: userBlock);
  }

  Future<Map<String, dynamic>> me() async {
    final res = await client.get('/auth/me');
    return (res as Map).cast<String, dynamic>();
  }

  /// Ends THIS device's session on the server. The client-side cleanup
  /// (clearing TokenStore + AuthPersistence) is the caller's job — this
  /// method just informs the server.
  ///
  /// The refresh token goes in the body because it is the only thing that
  /// identifies which handset is signing out. Without it the server falls
  /// back to ending every session on the account, and a counsellor signing
  /// out here would sign themselves out of their other phone too — mid-form,
  /// with "This session was ended elsewhere" and whatever they had typed
  /// gone (user 2026-09-26, camp form).
  Future<void> logout() async {
    try {
      final t = await TokenStore.load();
      await client.post('/auth/logout', body: {
        if (t != null) 'refresh_token': t.refreshToken,
      });
    } finally {
      await TokenStore.clear();
    }
  }

  Future<void> changePassword({required String oldPassword, required String newPassword}) async {
    await client.post('/auth/change-password', body: {
      'old_password': oldPassword, 'new_password': newPassword,
    });
  }
}

class LoginResult {
  final StoredTokens tokens;
  final Map<String, dynamic> user;
  const LoginResult({required this.tokens, required this.user});
}

StoredTokens _tokensFromPayload(Map<String, dynamic> j) {
  final now = DateTime.now();
  DateTime parse(String? raw, Duration fallback) =>
      raw == null ? now.add(fallback) : (DateTime.tryParse(raw) ?? now.add(fallback));
  return StoredTokens(
    accessToken:      (j['access_token']  as String?) ?? '',
    refreshToken:     (j['refresh_token'] as String?) ?? '',
    accessExpiresAt:  parse(j['access_expires_at']  as String?, const Duration(hours: 1)),
    refreshExpiresAt: parse(j['refresh_expires_at'] as String?, const Duration(days: 30)),
  );
}
