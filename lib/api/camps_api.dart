import 'api_client.dart';

/// /api/camps endpoints. Camps are the outreach visits the counsellor
/// schedules — the shell's Camps tab lists upcoming ones and lets the
/// counsellor add new entries.
class CampsApi {
  final ApiClient client;
  CampsApi(this.client);

  /// GET /camps — every camp for the caller's facility (or all camps
  /// for admin roles). Server-side filters: `date_from`, `date_to`,
  /// `facility_id`, `limit`.
  Future<List<Map<String, dynamic>>> list({
    String? dateFrom,
    String? dateTo,
    int? facilityId,
    int? limit,
  }) async {
    final res = await client.get('/camps', query: {
      if (dateFrom   != null) 'date_from':   dateFrom,
      if (dateTo     != null) 'date_to':     dateTo,
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

  /// POST /camps — record a new camp. Server pins `facility_id` to the
  /// caller's own facility when omitted.
  Future<Map<String, dynamic>> create({
    required String campName,
    required String campType, // Community / School / Workplace / Health Awareness
    required int villageId,
    required String campDate, // yyyy-mm-dd
    String venue = '',
    int? attendees,
    String services = '',
    String notes = '',
    int? facilityId,
  }) async {
    final res = await client.post('/camps', body: {
      'camp_name': campName,
      'camp_type': campType,
      'village_id': villageId,
      'camp_date':  campDate,
      if (venue.isNotEmpty)   'venue':    venue,
      if (attendees != null)  'attendees': attendees,
      if (services.isNotEmpty) 'services': services,
      if (notes.isNotEmpty)   'notes':    notes,
      if (facilityId != null) 'facility_id': facilityId,
    });
    return (res as Map).cast<String, dynamic>();
  }
}
