import 'api_client.dart';

/// /api/appointments/* — the clinical workflow. Registration, doctor
/// submit, lab sample/report, pharmacist dispense, counsellor test
/// payment. Most WRITE paths are also available through the offline
/// SyncService queue (kind: appointment.*); the calls here are the
/// online paths used when the network is up.
class AppointmentsApi {
  final ApiClient client;
  AppointmentsApi(this.client);

  /// GET /appointments — list with optional status (comma-separated),
  /// date range, or free-text query on patient name/code.
  Future<List<Map<String, dynamic>>> list({
    String? status,
    String? dateFrom,
    String? dateTo,
    String? q,
    int? limit,
  }) async {
    final res = await client.get('/appointments', query: {
      if (status   != null) 'status':    status,
      if (dateFrom != null) 'date_from': dateFrom,
      if (dateTo   != null) 'date_to':   dateTo,
      if (q        != null) 'q':         q,
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

  /// GET /appointments/{id} — full detail with symptoms, diagnoses,
  /// lab_tests, prescription.
  Future<Map<String, dynamic>> detail(int id) async =>
      ((await client.get('/appointments/$id')) as Map).cast<String, dynamic>();

  /// GET /appointments/queues/summary — org-wide status counters.
  Future<Map<String, dynamic>> queuesSummary() async =>
      ((await client.get('/appointments/queues/summary')) as Map).cast<String, dynamic>();

  /// GET /appointments/queues/payment — cases sitting at the counsellor's
  /// desk waiting for test-payment collection.
  Future<List<Map<String, dynamic>>> paymentQueue({int? facilityId}) async {
    final res = await client.get('/appointments/queues/payment', query: {
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

  /// GET /appointments/{id}/unpaid-tests — bill lines the counsellor
  /// shows in the "Collect Test Payment" dialog.
  Future<Map<String, dynamic>> unpaidTests(int id) async =>
      ((await client.get('/appointments/$id/unpaid-tests')) as Map)
          .cast<String, dynamic>();

  /// POST /appointments — create a new visit for an existing patient.
  /// Register-time online path (offline uses `patient.register` sync).
  Future<Map<String, dynamic>> create({
    required int patientId,
    int? facilityId,
    String? appointmentDate,
    bool pregnant = false,
    String? lmpDate,
    String? eddDate,
    bool takenPrescribedMedicine = false,
    String counsellorRemarks = '',
    num? height,
    num? weight,
    int? systolicBp,
    int? diastolicBp,
    int? bloodSugar,
    num? bodyTemp,
    num? oxygen,
    num? hemoglobin,
    String paymentType = 'Free',
    num paidAmount = 0,
    List<int> symptomIds = const [],
  }) async {
    final res = await client.post('/appointments', body: {
      'patient_id': patientId,
      if (facilityId       != null) 'facility_id':       facilityId,
      if (appointmentDate  != null) 'appointment_date':  appointmentDate,
      'pregnant': pregnant,
      if (lmpDate != null) 'lmp_date': lmpDate,
      if (eddDate != null) 'edd_date': eddDate,
      'taken_prescribed_medicine': takenPrescribedMedicine,
      if (counsellorRemarks.isNotEmpty) 'counsellor_remarks': counsellorRemarks,
      if (height       != null) 'height':       height,
      if (weight       != null) 'weight':       weight,
      if (systolicBp   != null) 'systolic_bp':  systolicBp,
      if (diastolicBp  != null) 'diastolic_bp': diastolicBp,
      if (bloodSugar   != null) 'blood_sugar':  bloodSugar,
      if (bodyTemp     != null) 'body_temp':    bodyTemp,
      if (oxygen       != null) 'oxygen':       oxygen,
      if (hemoglobin   != null) 'hemoglobin':   hemoglobin,
      'payment_type': paymentType,
      'paid_amount':  paidAmount,
      if (symptomIds.isNotEmpty) 'symptom_ids': symptomIds,
    });
    return (res as Map).cast<String, dynamic>();
  }

  /// PATCH /appointments/{id}/doctor — doctor submit. `rx` and `tests`
  /// are the standard shapes the backend accepts.
  Future<Map<String, dynamic>> doctorSubmit(
    int appointmentId, {
    String observation = '',
    String doctorRemarks = '',
    String? followUpDate,
    List<Map<String, dynamic>> diagnoses = const [],
    List<int> labTestIds = const [],
    List<Map<String, dynamic>> prescription = const [],
    bool referred = false,
    int? referralDestinationId,
    bool counselled = false,
    int? counsellingTopicId,
  }) async {
    final res = await client.patch('/appointments/$appointmentId/doctor', body: {
      if (observation.isNotEmpty)   'observation':   observation,
      if (doctorRemarks.isNotEmpty) 'doctor_remarks': doctorRemarks,
      if (followUpDate != null)     'follow_up_date': followUpDate,
      if (diagnoses.isNotEmpty)     'diagnoses':     diagnoses,
      if (labTestIds.isNotEmpty)    'lab_test_ids':  labTestIds,
      if (prescription.isNotEmpty)  'prescription':  prescription,
      'referred': referred,
      if (referralDestinationId != null) 'referral_destination_id': referralDestinationId,
      'counselled': counselled,
      if (counsellingTopicId != null) 'counselling_topic_id': counsellingTopicId,
    });
    return (res as Map).cast<String, dynamic>();
  }

  /// PATCH /appointments/{id}/dispense — pharmacist dispenses.
  /// `lines` carries {prescription_item_id, dispensed_qty, qty_change_reason?}.
  Future<Map<String, dynamic>> dispense(
    int appointmentId, {
    required List<Map<String, dynamic>> lines,
  }) async {
    final res = await client.patch('/appointments/$appointmentId/dispense', body: {
      'lines': lines,
    });
    return (res as Map).cast<String, dynamic>();
  }

  /// PATCH /appointments/{id}/collect-test-payment — counsellor stamps
  /// test payment received; server sets status → with_lab.
  Future<Map<String, dynamic>> collectTestPayment(int appointmentId) async {
    final res = await client.patch(
        '/appointments/$appointmentId/collect-test-payment');
    return (res as Map).cast<String, dynamic>();
  }

  /// PATCH /appointments/{id}/collect-consultation-fee — counsellor
  /// stamps who took the reg-time fee.
  Future<Map<String, dynamic>> collectConsultationFee(int appointmentId) async {
    final res = await client.patch(
        '/appointments/$appointmentId/collect-consultation-fee');
    return (res as Map).cast<String, dynamic>();
  }

  /// PATCH /appointments/{id}/lab-sample — lab tech records per-test
  /// sample-done + assigned handover date.
  Future<Map<String, dynamic>> labSample(
    int appointmentId, {
    required List<Map<String, dynamic>> lines,
  }) async {
    final res = await client.patch('/appointments/$appointmentId/lab-sample', body: {
      'lines': lines,
    });
    return (res as Map).cast<String, dynamic>();
  }

  /// PATCH /appointments/{id}/lab-report — lab tech uploads results.
  /// When every test has a report, server flips status → with_doctor.
  Future<Map<String, dynamic>> labReport(
    int appointmentId, {
    required List<Map<String, dynamic>> lines,
  }) async {
    final res = await client.patch('/appointments/$appointmentId/lab-report', body: {
      'lines': lines,
    });
    return (res as Map).cast<String, dynamic>();
  }
}
