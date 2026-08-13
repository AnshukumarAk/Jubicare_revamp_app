import 'api_client.dart';

/// /api/attendance/* endpoints (v2 §7).
///
/// The server enforces the Check-In-first rule. The mobile app's local
/// guard still matches so users get the same error message without a
/// round-trip.
class AttendanceApi {
  final ApiClient client;
  AttendanceApi(this.client);

  Future<Map<String, dynamic>> today() async {
    final res = await client.get('/attendance/today');
    return (res as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> checkIn({
    int? campAnchorId,
    String? location,
    String? photoKey,
    double? latitude,
    double? longitude,
    int? startKm,
    String? notes,
  }) async {
    final res = await client.post('/attendance/check-in', body: {
      if (campAnchorId != null) 'camp_anchor_id': campAnchorId,
      if (location    != null) 'location':       location,
      if (photoKey    != null) 'photo_key':      photoKey,
      if (latitude    != null) 'latitude':       latitude,
      if (longitude   != null) 'longitude':      longitude,
      if (startKm     != null) 'start_km':       startKm,
      if (notes       != null) 'notes':          notes,
    });
    return (res as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> checkOut({
    String? photoKey,
    double? latitude,
    double? longitude,
    int? endKm,
    num? collection,
    String? notes,
  }) async {
    final res = await client.post('/attendance/check-out', body: {
      if (photoKey  != null) 'photo_key':  photoKey,
      if (latitude  != null) 'latitude':   latitude,
      if (longitude != null) 'longitude':  longitude,
      if (endKm     != null) 'end_km':     endKm,
      if (collection!= null) 'collection': collection,
      if (notes     != null) 'notes':      notes,
    });
    return (res as Map).cast<String, dynamic>();
  }

  /// GET /attendance — historical rows for the caller (or a specific user
  /// when the API supports admin scope). Params are ISO dates (yyyy-mm-dd).
  Future<List<Map<String, dynamic>>> list({
    String? dateFrom,
    String? dateTo,
    int? userId,
    int? limit,
  }) async {
    final res = await client.get('/attendance', query: {
      if (dateFrom != null) 'date_from': dateFrom,
      if (dateTo   != null) 'date_to':   dateTo,
      if (userId   != null) 'user_id':   userId,
      if (limit    != null) 'limit':     limit,
    });
    if (res is List) {
      return [ for (final r in res) if (r is Map) r.cast<String, dynamic>() ];
    }
    if (res is Map) {
      final items = (res['items'] as List?) ?? const [];
      return [ for (final r in items) if (r is Map) r.cast<String, dynamic>() ];
    }
    return const [];
  }

  /// GET /attendance/open — currently open shift for the caller, or null
  /// if the last shift is already closed / none exists.
  Future<Map<String, dynamic>?> openShift() async {
    final res = await client.get('/attendance/open');
    if (res is Map) return res.cast<String, dynamic>();
    return null;
  }
}
