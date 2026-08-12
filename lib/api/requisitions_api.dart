import 'api_client.dart';

/// /api/requisitions/* — pharmacy stock indents. Pharmacist raises,
/// CMO / Zonal-Incharge reviews line-by-line, pharmacist confirms receipt.
class RequisitionsApi {
  final ApiClient client;
  RequisitionsApi(this.client);

  /// GET /requisitions — list with optional status / date filters. The
  /// server scopes to the caller's facility unless a specific `facility_id`
  /// is passed (admin scope).
  Future<List<Map<String, dynamic>>> list({
    String? status,
    int? facilityId,
    String? dateFrom,
    String? dateTo,
    int? limit,
  }) async {
    final res = await client.get('/requisitions', query: {
      if (status     != null) 'status':      status,
      if (facilityId != null) 'facility_id': facilityId,
      if (dateFrom   != null) 'date_from':   dateFrom,
      if (dateTo     != null) 'date_to':     dateTo,
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

  /// GET /requisitions/summary/counts — dashboard tile numbers for the
  /// CMO screen: pending, approved, partial, rejected, received.
  Future<Map<String, dynamic>> summaryCounts({int? facilityId}) async {
    final res = await client.get('/requisitions/summary/counts', query: {
      if (facilityId != null) 'facility_id': facilityId,
    });
    return (res as Map).cast<String, dynamic>();
  }

  /// GET /requisitions/{id} — full detail including line items + audit trail.
  Future<Map<String, dynamic>> detail(int id) async {
    final res = await client.get('/requisitions/$id');
    return (res as Map).cast<String, dynamic>();
  }

  /// POST /requisitions — pharmacist raises a new requisition. `lines`
  /// carries {medicine_id?, medicine_name, dosage, requested_qty}.
  Future<Map<String, dynamic>> create({
    required List<Map<String, dynamic>> lines,
    String remarks = '',
    int? facilityId,
  }) async {
    final res = await client.post('/requisitions', body: {
      'lines': lines,
      if (remarks.isNotEmpty) 'remarks': remarks,
      if (facilityId != null) 'facility_id': facilityId,
    });
    return (res as Map).cast<String, dynamic>();
  }

  /// PATCH /requisitions/{id}/review — CMO decision. `decisions` carries
  /// {requisition_line_id, approved_qty, review_note?} for each existing
  /// line, plus optional `added_lines` for lines the CMO adds themselves.
  Future<Map<String, dynamic>> review(
    int id, {
    required List<Map<String, dynamic>> decisions,
    List<Map<String, dynamic>> addedLines = const [],
    String remarks = '',
  }) async {
    final res = await client.patch('/requisitions/$id/review', body: {
      'decisions': decisions,
      if (addedLines.isNotEmpty) 'added_lines': addedLines,
      if (remarks.isNotEmpty)    'remarks': remarks,
    });
    return (res as Map).cast<String, dynamic>();
  }

  /// PATCH /requisitions/{id}/receive — pharmacist verifies delivery.
  /// `receipts` carries {requisition_line_id, received_qty}.
  Future<Map<String, dynamic>> receive(
    int id, {
    required List<Map<String, dynamic>> receipts,
    String invoicePath = '',
  }) async {
    final res = await client.patch('/requisitions/$id/receive', body: {
      'receipts': receipts,
      if (invoicePath.isNotEmpty) 'invoice_path': invoicePath,
    });
    return (res as Map).cast<String, dynamic>();
  }
}
