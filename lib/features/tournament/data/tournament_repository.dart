import '../../../core/network/api_client.dart';

class TournamentRepository {
  TournamentRepository(this._api);
  final ApiClient _api;

  Future<List<Map<String, dynamic>>> list({
    String? status,
    String? sportType,
  }) async {
    final qp = <String, dynamic>{};
    if (status != null && status.isNotEmpty) qp['status'] = status;
    if (sportType != null && sportType.isNotEmpty) qp['sport_type'] = sportType;
    final data = await _api.get(
      '/tournaments/',
      queryParameters: qp.isEmpty ? null : qp,
    );
    return (data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> detail(int id) async {
    final data = await _api.get('/tournaments/$id/');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> register(int id) async {
    final data = await _api.post('/tournaments/$id/register/');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> cancelRegistration(int id) async {
    final data = await _api.post('/tournaments/$id/cancel-registration/');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> my() async {
    final data = await _api.get('/tournaments/my/');
    return (data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}
