import 'api_client.dart';

/// Patient + appointment endpoints (v2 §5–§6).
class PatientsApi {
  final ApiClient client;
  PatientsApi(this.client);

  /// GET /patients — filter/search over the org's patient roster.
  /// Every param is optional; server defaults `facility_id` to the
  /// caller's own facility if omitted. Returns the standard list
  /// shape {items, total, count, filters}.
  Future<PatientList> list({
    String? q,
    int? facilityId,
    int? stateId,
    int? districtId,
    int? blockId,
    int? villageId,
    String? gender,
    String? facilityType,
    String? visitedFrom,
    String? visitedTo,
    int? limit,
    int? offset,
  }) async {
    final res = await client.get('/patients', query: {
      if (q != null && q.isNotEmpty) 'q': q,
      if (facilityId    != null) 'facility_id':   facilityId,
      if (stateId       != null) 'state_id':      stateId,
      if (districtId    != null) 'district_id':   districtId,
      if (blockId       != null) 'block_id':      blockId,
      if (villageId     != null) 'village_id':    villageId,
      if (gender        != null) 'gender':        gender,
      if (facilityType  != null) 'facility_type': facilityType,
      if (visitedFrom   != null) 'visited_from':  visitedFrom,
      if (visitedTo     != null) 'visited_to':    visitedTo,
      if (limit         != null) 'limit':         limit,
      if (offset        != null) 'offset':        offset,
    });
    final m = (res as Map).cast<String, dynamic>();
    return PatientList(
      items: [ for (final r in (m['items'] as List? ?? const []))
                 if (r is Map) r.cast<String, dynamic>() ],
      total: (m['total'] as num?)?.toInt() ?? 0,
      count: (m['count'] as num?)?.toInt() ?? 0,
    );
  }

  /// GET /patients/summary/counts — same filters as `list`, returns
  /// {patients, male, female, other, visits}.
  Future<Map<String, dynamic>> summaryCounts({
    String? q,
    int? facilityId,
    int? stateId,
    int? districtId,
    int? blockId,
    int? villageId,
    String? gender,
    String? facilityType,
    String? visitedFrom,
    String? visitedTo,
  }) async {
    final res = await client.get('/patients/summary/counts', query: {
      if (q != null && q.isNotEmpty) 'q': q,
      if (facilityId    != null) 'facility_id':   facilityId,
      if (stateId       != null) 'state_id':      stateId,
      if (districtId    != null) 'district_id':   districtId,
      if (blockId       != null) 'block_id':      blockId,
      if (villageId     != null) 'village_id':    villageId,
      if (gender        != null) 'gender':        gender,
      if (facilityType  != null) 'facility_type': facilityType,
      if (visitedFrom   != null) 'visited_from':  visitedFrom,
      if (visitedTo     != null) 'visited_to':    visitedTo,
    });
    return (res as Map).cast<String, dynamic>();
  }

  /// GET /patients/{id} — single row + previous_prescriptions +
  /// a light appointments list (id + date + status + primary diagnosis).
  Future<Map<String, dynamic>> get(int id) async =>
      ((await client.get('/patients/$id')) as Map).cast<String, dynamic>();

  /// GET /patients/{id}/history — the full visit history in one
  /// request. Every visit carries its diagnoses, lab_tests, prescription.
  Future<Map<String, dynamic>> history(int id) async =>
      ((await client.get('/patients/$id/history')) as Map).cast<String, dynamic>();

  /// DELETE /patients/{id} — soft delete. `reason` is stored on the
  /// row's delete_reason column and is required by the DB CHECK.
  Future<void> delete(int id, {required String reason}) async {
    await client.delete('/patients/$id', body: {'reason': reason});
  }

  Future<Map<String, dynamic>> reAppointment(
    int patientId, {
    int? parentAppointmentId,
    required String appointmentDate,
    String paymentType = 'Free',
    num paidAmount = 0,
    String counsellorRemarks = '',
  }) async {
    final res = await client.post('/patients/$patientId/re-appointment', body: {
      if (parentAppointmentId != null) 'parent_appointment_id': parentAppointmentId,
      'appointment_date':    appointmentDate,
      'payment_type':        paymentType,
      'paid_amount':         paidAmount,
      'counsellor_remarks':  counsellorRemarks,
    });
    return (res as Map).cast<String, dynamic>();
  }
}

class PatientList {
  final List<Map<String, dynamic>> items;
  final int total, count;
  const PatientList({required this.items, required this.total, required this.count});
}
