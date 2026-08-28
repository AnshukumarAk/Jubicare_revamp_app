import 'api_client.dart';

/// /api/mobile/bootstrap from v2 §2. One call to hydrate Home — plus the
/// geography cascade (/masters/blocks, /masters/villages) that the
/// bootstrap payload doesn't carry.
class BootstrapApi {
  final ApiClient client;
  BootstrapApi(this.client);

  Future<Map<String, dynamic>> fetch() async {
    final res = await client.get('/mobile/bootstrap');
    return (res as Map).cast<String, dynamic>();
  }

  /// GET /masters/blocks?district_id= → [{block_id, block_name}]
  Future<List<Map<String, dynamic>>> blocks(int districtId) async {
    final res = await client.get('/masters/blocks', query: {'district_id': districtId});
    if (res is List) {
      return [for (final r in res) if (r is Map) r.cast<String, dynamic>()];
    }
    return const [];
  }

  /// GET /masters/villages?block_id= → [{village_id, village_name}]
  Future<List<Map<String, dynamic>>> villages(int blockId) async {
    final res = await client.get('/masters/villages', query: {'block_id': blockId});
    if (res is List) {
      return [for (final r in res) if (r is Map) r.cast<String, dynamic>()];
    }
    return const [];
  }
}
