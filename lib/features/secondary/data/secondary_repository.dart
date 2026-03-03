import '../../../core/network/api_client.dart';

class SecondaryRepository {
  SecondaryRepository(this._api);
  final ApiClient _api;

  Future<List<Map<String, dynamic>>> news({String? category}) async {
    final data = await _api.get('/news/', queryParameters: category == null ? null : {'category': category});
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> newsDetail(int id) async {
    final data = await _api.get('/news/$id/');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> promotions() async {
    final data = await _api.get('/marketing/promos/');
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> validatePromo(String code) async {
    final data = await _api.get('/marketing/validate-promo/', queryParameters: {'code': code});
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> services() async {
    final data = await _api.get('/inventory/services/');
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> gymQr() async {
    final data = await _api.get('/gym/qr/generate/');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> gymCheckin() async {
    final data = await _api.post('/gym/checkin/');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> gymVisits() async {
    final data = await _api.get('/gym/visits/');
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> personalTraining() async {
    final data = await _api.get('/gym/personal-training/');
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> createPersonalTraining(Map<String, dynamic> payload) async {
    final data = await _api.post('/gym/personal-training/', data: payload);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> personalTrainingDetail(int id) async {
    final data = await _api.get('/gym/personal-training/$id/');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> updatePersonalTraining(int id, Map<String, dynamic> payload) async {
    final data = await _api.patch('/gym/personal-training/$id/', data: payload);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> deletePersonalTraining(int id) async {
    await _api.delete('/gym/personal-training/$id/');
  }

  Future<List<Map<String, dynamic>>> financeHistory() async {
    final data = await _api.get('/finance/history/');
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> paymentSessionStatus(String sessionId) async {
    final data = await _api.get('/payments/session/$sessionId/status/');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> clubSettings() async {
    final data = await _api.get('/core/settings/');
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> closedDays({String? from, String? to}) async {
    final qp = <String, dynamic>{};
    if (from != null && from.isNotEmpty) qp['from'] = from;
    if (to != null && to.isNotEmpty) qp['to'] = to;
    final data = await _api.get('/core/closed-days/', queryParameters: qp.isEmpty ? null : qp);
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
