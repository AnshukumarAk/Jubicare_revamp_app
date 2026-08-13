import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

import 'api_errors.dart';
import 'token_store.dart';

/// HTTP client for the JubiCare backend (v2 API).
///
/// Handles:
///
/// * base URL (revamp-back.indevconsultancy.in) + `/api` prefix
/// * Bearer JWT on every authed request
/// * proactive refresh (§1.2) — access tokens rotate a few seconds early
/// * REACTIVE refresh — on 401 TOKEN_EXPIRED, run the refresh flow and
///   retry the original request once
/// * SERIALISED refresh (backend team's client note §10) — refresh
///   tokens are consumed on use; two concurrent refreshes sign the user
///   out. All refresh calls funnel through one Completer.
/// * envelope-shaped errors (§8) surfaced as [ApiException]
/// * `onSignedOutRemotely` callback so the UI can clear session +
///   route back to login without every service having to know about
///   navigation
///
/// Not a singleton — build one in main() and pass it via provider.
class ApiClient {
  final String baseUrl;
  final http.Client _http;
  final Future<void> Function()? onSignedOutRemotely;

  ApiClient({
    this.baseUrl = 'https://revamp-back.indevconsultancy.in',
    http.Client? httpClient,
    this.onSignedOutRemotely,
  }) : _http = httpClient ?? http.Client();

  /// Guards concurrent refresh attempts. When a refresh is in flight all
  /// other callers await this completer so exactly one refresh token
  /// value is consumed per rotation (backend team's client note §10).
  Completer<StoredTokens?>? _refreshInFlight;

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    // Callers pass /auth/login or /mobile/bootstrap — the client prefixes
    // /api so requirements docs and endpoints in code both read cleanly.
    final rel = path.startsWith('/') ? path : '/$path';
    final full = '$baseUrl/api$rel';
    if (query == null || query.isEmpty) return Uri.parse(full);
    final cleaned = <String, String>{
      for (final e in query.entries)
        if (e.value != null) e.key: e.value.toString(),
    };
    return Uri.parse(full).replace(queryParameters: cleaned);
  }

  Map<String, String> _headers(String? bearer) => {
        'Accept':       'application/json',
        'Content-Type': 'application/json',
        if (bearer != null) 'Authorization': 'Bearer $bearer',
      };

  Future<dynamic> get(String path, {Map<String, dynamic>? query, bool auth = true}) =>
      _send('GET', path, query: query, auth: auth);

  Future<dynamic> post(String path, {Object? body, Map<String, dynamic>? query, bool auth = true}) =>
      _send('POST', path, body: body, query: query, auth: auth);

  Future<dynamic> patch(String path, {Object? body, bool auth = true}) =>
      _send('PATCH', path, body: body, auth: auth);

  Future<dynamic> delete(String path, {Object? body, bool auth = true}) =>
      _send('DELETE', path, body: body, auth: auth);

  /// Multipart file upload (POST). Used by UploadsApi for prescription /
  /// report photos. Reuses the same token plumbing as _send — proactive
  /// refresh before the request, one reactive refresh + retry on 401
  /// TOKEN_EXPIRED.
  Future<dynamic> postMultipartFile(String path, {
    required String filePath,
    String field = 'file',
    String? contentTypeOverride,
  }) async {
    final t = await _validAccessToken();
    if (t == null) {
      throw const ApiException(
        code: ApiErrorCode.signedOutRemotely,
        message: 'You have been signed out. Please sign in again.',
      );
    }

    Future<http.Response> doSend(String bearer) async {
      final req = http.MultipartRequest('POST', _uri(path, null));
      req.headers['Accept'] = 'application/json';
      req.headers['Authorization'] = 'Bearer $bearer';
      // Infer content type from the extension — the backend allowlists
      // by declared type, and MultipartFile defaults to octet-stream
      // which would be refused.
      final lower = filePath.toLowerCase();
      final mime = contentTypeOverride ??
          (lower.endsWith('.png') ? 'image/png'
           : lower.endsWith('.webp') ? 'image/webp'
           : 'image/jpeg');
      req.files.add(await http.MultipartFile.fromPath(
        field, filePath,
        contentType: MediaType.parse(mime),
      ));
      final streamed = await req.send();
      return http.Response.fromStream(streamed);
    }

    try {
      var res = await doSend(t);
      if (res.statusCode == 401) {
        final env = _tryDecode(res.body);
        final code = env is Map && env['error'] is Map
            ? env['error']['code']?.toString() ?? ''
            : '';
        if (code == 'TOKEN_EXPIRED') {
          final rolled = await _refreshOnce();
          if (rolled != null) {
            res = await doSend(rolled.accessToken);
          }
        }
      }
      return _decode(res);
    } on SocketException catch (e) {
      throw ApiException.network(e);
    } on http.ClientException catch (e) {
      throw ApiException.network(e);
    }
  }

  Future<dynamic> _send(String method, String path,
      {Object? body, Map<String, dynamic>? query, bool auth = true}) async {
    // Proactive refresh — if we know the access token has expired, roll
    // it over BEFORE issuing the request. Cheaper than the retry path.
    String? bearer;
    if (auth) {
      final t = await _validAccessToken();
      if (t == null) {
        throw const ApiException(
          code: ApiErrorCode.signedOutRemotely,
          message: 'You have been signed out. Please sign in again.',
        );
      }
      bearer = t;
    }

    try {
      final res = await _do(method, path, body: body, query: query, bearer: bearer);
      // On 401 TOKEN_EXPIRED, refresh once and retry with the new token.
      // Anything else (invalid creds, remotely signed out, forbidden) is
      // surfaced to the caller as-is.
      if (res.statusCode == 401 && auth) {
        final env = _tryDecode(res.body);
        final code = env is Map && env['error'] is Map
            ? env['error']['code']?.toString() ?? ''
            : '';
        if (code == 'TOKEN_EXPIRED') {
          final rolled = await _refreshOnce();
          if (rolled != null) {
            final retry = await _do(method, path, body: body, query: query, bearer: rolled.accessToken);
            return _decode(retry);
          }
        }
        if (code == 'SIGNED_OUT_REMOTELY' ||
            code == 'INVALID_TOKEN' ||
            code == 'REFRESH_EXPIRED') {
          await onSignedOutRemotely?.call();
        }
      }
      return _decode(res);
    } on SocketException catch (e) {
      throw ApiException.network(e);
    } on http.ClientException catch (e) {
      throw ApiException.network(e);
    }
  }

  Future<http.Response> _do(String method, String path,
      {Object? body, Map<String, dynamic>? query, String? bearer}) {
    final uri = _uri(path, query);
    final headers = _headers(bearer);
    final encoded = body == null ? null : jsonEncode(body);
    switch (method) {
      case 'GET':    return _http.get(uri, headers: headers);
      case 'POST':   return _http.post(uri, headers: headers, body: encoded);
      case 'PATCH':  return _http.patch(uri, headers: headers, body: encoded);
      case 'DELETE': return _http.delete(uri, headers: headers, body: encoded);
      default:       throw ArgumentError('Unsupported HTTP method: $method');
    }
  }

  dynamic _decode(http.Response res) {
    final ok = res.statusCode >= 200 && res.statusCode < 300;
    if (ok) {
      if (res.body.isEmpty) return null;
      return _tryDecode(res.body);
    }
    throw ApiException.fromEnvelope(res.statusCode, _tryDecode(res.body));
  }

  dynamic _tryDecode(String body) {
    try { return jsonDecode(body); } catch (_) { return body; }
  }

  Future<String?> _validAccessToken() async {
    final t = await TokenStore.load();
    if (t == null) return null;
    if (t.refreshExpired) {
      await onSignedOutRemotely?.call();
      return null;
    }
    if (t.accessExpired) {
      final rolled = await _refreshOnce();
      return rolled?.accessToken;
    }
    return t.accessToken;
  }

  /// Run exactly one refresh-token exchange, no matter how many callers
  /// need one right now. Returns null if the session died in the process.
  ///
  /// Only DEFINITIVE auth failures (SIGNED_OUT_REMOTELY / INVALID_TOKEN /
  /// REFRESH_EXPIRED) sign the user out. Network hiccups, 5xx server
  /// blips and unexpected exceptions leave the session intact — the
  /// caller returns null and the request fails, but the counsellor
  /// stays logged in and can retry when connectivity is back.
  Future<StoredTokens?> _refreshOnce() async {
    final inflight = _refreshInFlight;
    if (inflight != null) return inflight.future;
    final completer = Completer<StoredTokens?>();
    _refreshInFlight = completer;
    try {
      final current = await TokenStore.load();
      if (current == null || current.refreshExpired) {
        // Refresh token past its 30-day life OR no token at all — this
        // one IS definitive; nothing left to reissue against.
        await onSignedOutRemotely?.call();
        completer.complete(null);
        return null;
      }
      final http.Response res;
      try {
        res = await _do('POST', '/auth/refresh',
            body: {'refresh_token': current.refreshToken});
      } on SocketException {
        // Offline. Keep the session — the next successful request will
        // trigger another refresh attempt.
        completer.complete(null);
        return null;
      } on http.ClientException {
        completer.complete(null);
        return null;
      }
      if (res.statusCode == 200) {
        final decoded = _tryDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          final rolled = _tokensFromLoginPayload(decoded, fallback: current);
          await TokenStore.save(
            accessToken:      rolled.accessToken,
            refreshToken:     rolled.refreshToken,
            accessExpiresAt:  rolled.accessExpiresAt,
            refreshExpiresAt: rolled.refreshExpiresAt,
          );
          completer.complete(rolled);
          return rolled;
        }
      }
      // Non-200 response. Sign out ONLY on definitive auth failures so a
      // 500 during backend restart doesn't kick the counsellor to login.
      final env = _tryDecode(res.body);
      final code = env is Map && env['error'] is Map
          ? (env['error']['code'] as String? ?? '')
          : '';
      final definitiveAuthFailure = res.statusCode == 401 && (
          code == 'SIGNED_OUT_REMOTELY' ||
          code == 'INVALID_TOKEN' ||
          code == 'REFRESH_EXPIRED');
      if (definitiveAuthFailure) {
        await onSignedOutRemotely?.call();
      }
      completer.complete(null);
      return null;
    } catch (_) {
      // Unexpected — parse failure, disk I/O, whatever. Don't sign out
      // for a bug in refresh handling; better to fail a single request.
      completer.complete(null);
      return null;
    } finally {
      _refreshInFlight = null;
    }
  }
}

/// Read the four token fields out of a login / refresh response. §1.1
/// shows the exact shape. If the server ever drops an `expires_at` we
/// fall back to a conservative default so the client keeps working.
StoredTokens _tokensFromLoginPayload(Map<String, dynamic> j, {StoredTokens? fallback}) {
  final now = DateTime.now();
  DateTime parse(String? raw, Duration fallbackAfter) =>
      raw == null ? now.add(fallbackAfter) : (DateTime.tryParse(raw) ?? now.add(fallbackAfter));
  return StoredTokens(
    accessToken:  (j['access_token'] as String?)  ?? fallback?.accessToken  ?? '',
    refreshToken: (j['refresh_token'] as String?) ?? fallback?.refreshToken ?? '',
    accessExpiresAt:  parse(j['access_expires_at']  as String?, const Duration(hours: 1)),
    refreshExpiresAt: parse(j['refresh_expires_at'] as String?, const Duration(days: 30)),
  );
}
