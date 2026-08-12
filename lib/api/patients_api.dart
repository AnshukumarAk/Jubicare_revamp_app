import 'api_client.dart';

/// Patient + appointment endpoints (v2 §5–§6).
class PatientsApi {
  final ApiClient client;
  PatientsApi(this.client);

  Future<Map<String, dynamic>> get(int id) async =>
      ((await client.get('/patients/$id')) as Map).cast<String, dynamic>();

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
