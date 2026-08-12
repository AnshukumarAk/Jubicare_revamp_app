import 'api_client.dart';

/// /api/mobile/bootstrap from v2 §2. One call to hydrate Home.
class BootstrapApi {
  final ApiClient client;
  BootstrapApi(this.client);

  Future<Map<String, dynamic>> fetch() async {
    final res = await client.get('/mobile/bootstrap');
    return (res as Map).cast<String, dynamic>();
  }
}
