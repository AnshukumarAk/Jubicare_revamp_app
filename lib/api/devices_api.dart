import 'api_client.dart';

/// /api/devices/* — daily device status reports (BP monitor, glucometer,
/// etc.) plus the historical log. The counsellor's Devices tab writes
/// today's report and reads the last few days for the audit trail.
class DevicesApi {
  final ApiClient client;
  DevicesApi(this.client);

  /// GET /devices/status — every device's status on `date` (defaults
  /// to today). Returns one row per device with `{device_id,
  /// device_name, status, reported_by, status_date}`.
  Future<List<Map<String, dynamic>>> status({String? date, int? facilityId}) async {
    final res = await client.get('/devices/status', query: {
      if (date       != null) 'date':        date,
      if (facilityId != null) 'facility_id': facilityId,
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

  /// POST /devices/status — submit a bulk status report for a single
  /// date. Each line carries `{device_id, status}` where status is one
  /// of Working / Not Working / Not Applicable / Purchase Requested.
  Future<Map<String, dynamic>> submitStatus({
    required String date, // yyyy-mm-dd
    required List<Map<String, dynamic>> lines,
    int? facilityId,
  }) async {
    final res = await client.post('/devices/status', body: {
      'status_date': date,
      'lines': lines,
      if (facilityId != null) 'facility_id': facilityId,
    });
    return (res as Map).cast<String, dynamic>();
  }

  /// GET /devices/history — per-device timeline. `date_from` / `date_to`
  /// bracket it; without them the server returns everything.
  Future<List<Map<String, dynamic>>> history({
    String? dateFrom,
    String? dateTo,
    int? deviceId,
    int? facilityId,
    int? limit,
  }) async {
    final res = await client.get('/devices/history', query: {
      if (dateFrom   != null) 'date_from':   dateFrom,
      if (dateTo     != null) 'date_to':     dateTo,
      if (deviceId   != null) 'device_id':   deviceId,
      if (facilityId != null) 'facility_id': facilityId,
      if (limit      != null) 'limit':       limit,
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
}
