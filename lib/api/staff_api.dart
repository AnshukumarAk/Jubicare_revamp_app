import 'api_client.dart';

/// /api/staff — the roster the counsellor reads to populate the
/// "Assigned Doctor" dropdown, and admin roles use to CRUD MMU staff.
class StaffApi {
  final ApiClient client;
  StaffApi(this.client);

  /// GET /staff — list staff optionally filtered by role and facility.
  /// Counsellor's Register form calls `list(role: 'doctor', facilityId: myFac)`
  /// to fill the doctor dropdown from real backend rows.
  Future<List<Map<String, dynamic>>> list({
    String? role,
    int? facilityId,
    bool? isActive,
    int? limit,
  }) async {
    final res = await client.get('/staff', query: {
      if (role       != null) 'role':        role,
      if (facilityId != null) 'facility_id': facilityId,
      if (isActive   != null) 'is_active':   isActive,
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
