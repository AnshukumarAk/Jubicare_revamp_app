import 'api_client.dart';

/// /api/mobile/sync/{pull,push,kinds} from v2 §3–4.
class SyncApi {
  final ApiClient client;
  SyncApi(this.client);

  Future<PullResponse> pull({DateTime? updatedSince, int? perPage}) async {
    final res = await client.get('/mobile/sync/pull', query: {
      if (updatedSince != null) 'updated_since': updatedSince.toUtc().toIso8601String(),
      if (perPage != null) 'per_page': perPage,
    });
    return PullResponse.fromJson((res as Map).cast<String, dynamic>());
  }

  /// Send a batch of offline actions. Server applies each independently
  /// and returns per-action results — the batch is not a transaction.
  Future<PushResponse> push(List<SyncAction> actions, {String? clientBatchId}) async {
    final res = await client.post('/mobile/sync/push', body: {
      if (clientBatchId != null) 'client_batch_id': clientBatchId,
      'actions': [ for (final a in actions) a.toJson() ],
    });
    return PushResponse.fromJson((res as Map).cast<String, dynamic>());
  }

  Future<KindsResponse> kinds() async {
    final res = await client.get('/mobile/sync/kinds');
    return KindsResponse.fromJson((res as Map).cast<String, dynamic>());
  }
}

class PullResponse {
  final List<Map<String, dynamic>> patients;
  final List<Map<String, dynamic>> appointments;
  final List<Map<String, dynamic>> attendance;
  final List<Map<String, dynamic>> requisitions;
  final String cursor;
  final bool hasMore;

  const PullResponse({
    required this.patients,
    required this.appointments,
    required this.attendance,
    required this.requisitions,
    required this.cursor,
    required this.hasMore,
  });

  factory PullResponse.fromJson(Map<String, dynamic> j) => PullResponse(
        patients:     _list(j['patients']),
        appointments: _list(j['appointments']),
        attendance:   _list(j['attendance']),
        requisitions: _list(j['requisitions']),
        cursor:  (j['cursor']  as String?) ?? '',
        hasMore: (j['has_more'] as bool?)  ?? false,
      );
}

List<Map<String, dynamic>> _list(dynamic v) =>
    v is List ? [for (final e in v) if (e is Map) e.cast<String, dynamic>()] : const [];

class SyncAction {
  final String clientActionId;
  final String kind;
  final Map<String, dynamic> payload;
  const SyncAction({required this.clientActionId, required this.kind, required this.payload});

  Map<String, dynamic> toJson() => {
        'client_action_id': clientActionId,
        'kind':             kind,
        'payload':          payload,
      };
}

class PushResponse {
  final int applied, rejected, failed;
  final List<SyncActionResult> results;
  const PushResponse({
    required this.applied,
    required this.rejected,
    required this.failed,
    required this.results,
  });
  factory PushResponse.fromJson(Map<String, dynamic> j) => PushResponse(
        applied:  (j['applied']  as int?) ?? 0,
        rejected: (j['rejected'] as int?) ?? 0,
        failed:   (j['failed']   as int?) ?? 0,
        results: [
          for (final r in (j['results'] as List? ?? const []))
            if (r is Map) SyncActionResult.fromJson(r.cast<String, dynamic>()),
        ],
      );
}

class SyncActionResult {
  final String clientActionId;
  final String status;         // 'applied' | 'rejected' | 'failed'
  final bool retry;            // §4 rule 4 — drop vs keep
  final int? serverId;
  final Map<String, dynamic>? result;
  final String? code;
  final String? message;

  const SyncActionResult({
    required this.clientActionId,
    required this.status,
    required this.retry,
    this.serverId,
    this.result,
    this.code,
    this.message,
  });

  factory SyncActionResult.fromJson(Map<String, dynamic> j) => SyncActionResult(
        clientActionId: (j['client_action_id'] as String?) ?? '',
        status:         (j['status']           as String?) ?? 'failed',
        retry:          (j['retry']            as bool?)   ?? (j['status'] == 'failed'),
        serverId:       (j['server_id']        as num?)?.toInt(),
        result:         (j['result'] as Map?)?.cast<String, dynamic>(),
        code:           j['code']    as String?,
        message:        j['message'] as String?,
      );

  bool get isApplied  => status == 'applied';
  bool get isRejected => status == 'rejected';
  bool get isFailed   => status == 'failed';
}

class KindsResponse {
  final List<String> kinds;
  final List<String> aliases;
  final List<String> allowedForYou;
  const KindsResponse({required this.kinds, required this.aliases, required this.allowedForYou});

  factory KindsResponse.fromJson(Map<String, dynamic> j) => KindsResponse(
        kinds:         _strs(j['kinds']),
        aliases:       _strs(j['aliases']),
        allowedForYou: _strs(j['allowed_for_you']),
      );
}

List<String> _strs(dynamic v) =>
    v is List ? [for (final e in v) if (e != null) e.toString()] : const [];
