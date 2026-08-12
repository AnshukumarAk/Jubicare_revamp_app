import 'api_client.dart';

/// /api/queues/* endpoints (v2 §5).
///
/// The tile counts and their drilldown lists come from the SAME query on
/// the server so they can never disagree. Every list carries a `total`
/// that matches the tile even after `?limit=` cuts the response.
class QueuesApi {
  final ApiClient client;
  QueuesApi(this.client);

  /// One call to fill every Home KPI tile.
  Future<Map<String, dynamic>> tiles({int? facilityId}) async {
    final res = await client.get('/queues/summary/tiles',
        query: {if (facilityId != null) 'facility_id': facilityId});
    return (res as Map).cast<String, dynamic>();
  }

  Future<QueueList> doctorQueue({int? facilityId, DateTime? updatedSince, int? limit}) =>
      _list('/queues/doctor', facilityId, updatedSince, limit);

  Future<QueueList> doctorAttended({int? facilityId, DateTime? updatedSince, int? limit}) =>
      _list('/queues/doctor/attended', facilityId, updatedSince, limit);

  Future<QueueList> doctorPast7Days({int? facilityId, DateTime? updatedSince, int? limit}) =>
      _list('/queues/doctor/past-7-days', facilityId, updatedSince, limit);

  Future<QueueList> labQueue({int? facilityId, DateTime? updatedSince, int? limit}) =>
      _list('/queues/lab', facilityId, updatedSince, limit);

  Future<QueueList> pharmaQueue({int? facilityId, DateTime? updatedSince, int? limit}) =>
      _list('/queues/pharmacist', facilityId, updatedSince, limit);

  Future<QueueList> pharmaPast7Days({int? facilityId, DateTime? updatedSince, int? limit}) =>
      _list('/queues/pharmacist/past-7-days', facilityId, updatedSince, limit);

  Future<QueueList> counsellorPast7Days({int? facilityId, DateTime? updatedSince, int? limit}) =>
      _list('/queues/counsellor/past-7-days', facilityId, updatedSince, limit);

  Future<QueueList> pendingPayment({int? facilityId, DateTime? updatedSince, int? limit}) =>
      _list('/queues/counsellor/pending-payment', facilityId, updatedSince, limit);

  Future<QueueList> _list(String path, int? facilityId, DateTime? updatedSince, int? limit) async {
    final res = await client.get(path, query: {
      if (facilityId    != null) 'facility_id':    facilityId,
      if (updatedSince  != null) 'updated_since':  updatedSince.toUtc().toIso8601String(),
      if (limit         != null) 'limit':          limit,
    });
    final m = (res as Map).cast<String, dynamic>();
    return QueueList(
      items: [ for (final r in (m['items'] as List? ?? const []))
                if (r is Map) r.cast<String, dynamic>() ],
      total: (m['total'] as num?)?.toInt() ?? 0,
      count: (m['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class QueueList {
  final List<Map<String, dynamic>> items;
  final int total, count;
  const QueueList({required this.items, required this.total, required this.count});
}
