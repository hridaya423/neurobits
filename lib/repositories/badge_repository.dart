import 'package:neurobits/services/convex_client_service.dart';

class BadgeRepository {
  final ConvexClientService _client;

  BadgeRepository(this._client);
  
  Future<List<Map<String, dynamic>>> listAll() async {
    final result = await _client.query(name: 'badges:listAll');
    return toMapList(result);
  }

  Future<List<Map<String, dynamic>>> listMine() async {
    final result = await _client.query(name: 'badges:listMine');
    return toMapList(result);
  }
}
