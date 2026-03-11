import '../../../core/network/api_client.dart';

class MembershipRepository {
  MembershipRepository(this._api);
  final ApiClient _api;

  Future<List<Map<String, dynamic>>> types() async {
    final data = await _api.get('/memberships/plans/');
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> buy(int planId, {String paymentMethod = 'KASPI'}) async {
    final data = await _api.post('/memberships/purchase/', data: {
      'plan_id': planId,
      'payment_method': paymentMethod,
    });
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
