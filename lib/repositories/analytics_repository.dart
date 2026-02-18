import 'package:neurobits/services/convex_client_service.dart';

class AnalyticsRepository {
  final ConvexClientService _client;

  AnalyticsRepository(this._client);

  Future<Map<String, dynamic>> getUserPerformanceVector() async {
    final result = await _client.query(
      name: 'analytics:getUserPerformanceVector',
    );
    return toMap(result);
  }
}
