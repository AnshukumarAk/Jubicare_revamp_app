/// Well-known error codes the mobile app branches on, from the backend
/// team's v2 API §8. Anything not in this enum is surfaced as a generic
/// message so future codes don't crash the client.
enum ApiErrorCode {
  invalidCredentials,   // 401 wrong username or password
  tokenExpired,         // 401 access token expired → refresh + retry once
  signedOutRemotely,    // 401 deactivated / refresh reused → clear session
  invalidToken,         // 401 malformed / refresh-as-access
  refreshExpired,       // 401 30d elapsed → sign in again
  forbidden,            // 403 role not allowed
  notFound,             // 404
  checkInRequired,      // 409 check-out before check-in
  alreadyCheckedIn,     // 409
  alreadyCheckedOut,    // 409
  statusConflict,       // 409 refresh the record
  noFacility,           // 422 account not posted to a unit
  odometerBackwards,    // 422
  validationFailed,     // 422
  enumInvalid,          // 422
  rateLimited,          // 429
  networkUnreachable,   // client-side: no connectivity / socket error
  unknown,              // catch-all
}

ApiErrorCode _codeFromString(String? raw) {
  switch (raw) {
    case 'INVALID_CREDENTIALS': return ApiErrorCode.invalidCredentials;
    case 'TOKEN_EXPIRED':       return ApiErrorCode.tokenExpired;
    case 'SIGNED_OUT_REMOTELY': return ApiErrorCode.signedOutRemotely;
    case 'INVALID_TOKEN':       return ApiErrorCode.invalidToken;
    case 'REFRESH_EXPIRED':     return ApiErrorCode.refreshExpired;
    case 'FORBIDDEN':           return ApiErrorCode.forbidden;
    case 'NOT_FOUND':           return ApiErrorCode.notFound;
    case 'CHECK_IN_REQUIRED':   return ApiErrorCode.checkInRequired;
    case 'ALREADY_CHECKED_IN':  return ApiErrorCode.alreadyCheckedIn;
    case 'ALREADY_CHECKED_OUT': return ApiErrorCode.alreadyCheckedOut;
    case 'STATUS_CONFLICT':     return ApiErrorCode.statusConflict;
    case 'NO_FACILITY':         return ApiErrorCode.noFacility;
    case 'ODOMETER_BACKWARDS':  return ApiErrorCode.odometerBackwards;
    case 'VALIDATION_FAILED':   return ApiErrorCode.validationFailed;
    case 'ENUM_INVALID':        return ApiErrorCode.enumInvalid;
    case 'RATE_LIMITED':        return ApiErrorCode.rateLimited;
    default:                    return ApiErrorCode.unknown;
  }
}

/// Every API failure — HTTP error, server envelope, or socket problem —
/// surfaces as an ApiException so screens have one type to catch. The
/// message is safe to show inline; use `code` for branching.
class ApiException implements Exception {
  final ApiErrorCode code;
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? details;
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.details,
  });

  /// Parse the server's `{ "error": { "code": "…", "message": "…", "details": {…} } }`
  /// envelope from §8. Falls back to a generic exception if the payload
  /// isn't shaped as expected (e.g. gateway timeouts, HTML error pages).
  factory ApiException.fromEnvelope(int status, Object? body) {
    if (body is Map<String, dynamic>) {
      final err = body['error'];
      if (err is Map<String, dynamic>) {
        return ApiException(
          code:    _codeFromString(err['code'] as String?),
          message: (err['message'] as String?) ?? 'Something went wrong',
          statusCode: status,
          details: (err['details'] as Map?)?.cast<String, dynamic>(),
        );
      }
    }
    return ApiException(
      code: ApiErrorCode.unknown,
      message: 'Server responded $status without an error envelope',
      statusCode: status,
    );
  }

  factory ApiException.network(Object cause) => ApiException(
        code: ApiErrorCode.networkUnreachable,
        message: 'Cannot reach the server. Check your internet.',
        details: {'cause': cause.toString()},
      );

  @override
  String toString() => 'ApiException($code, $statusCode): $message';
}
