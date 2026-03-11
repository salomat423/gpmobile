import '../../../core/network/api_client.dart';

class MembershipRepository {
  MembershipRepository(this._api);
  final ApiClient _api;

  Future<List<Map<String, dynamic>>> types() async {
    final data = await _api.get('/memberships/types/');
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> buy(int typeId) async {
    final data = await _api.post('/memberships/buy/$typeId/');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> myMemberships() async {
    final data = await _api.get('/memberships/my/');
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> freeze(int id) async {
    final data = await _api.post('/memberships/my/$id/freeze/');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> unfreeze(int id) async {
    final data = await _api.post('/memberships/my/$id/unfreeze/');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> membershipHistory(int id) async {
    final data = await _api.get('/memberships/my/$id/history/');
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
