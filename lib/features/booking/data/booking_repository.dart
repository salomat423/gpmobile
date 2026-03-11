import '../../../core/network/api_client.dart';

class BookingRepository {
  BookingRepository(this._api);
  final ApiClient _api;

  Future<List<Map<String, dynamic>>> courts() async {
    final data = await _api.get('/courts/');
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> courtDetail(int id) async {
    final data = await _api.get('/courts/$id/');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> checkAvailability({
    required int courtId,
    required String dateIso,
  }) async {
    final data = await _api.get('/bookings/check-availability/', queryParameters: {
      'court_id': courtId,
      'date': dateIso,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> availableCoaches({
    required String dateTimeIso,
    required int duration,
  }) async {
    final data = await _api.get('/bookings/available-coaches/', queryParameters: {
      'datetime': dateTimeIso,
      'duration': duration,
    });
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> pricePreview(Map<String, dynamic> payload) async {
    final data = await _api.post('/bookings/price-preview/', data: payload);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> createBooking(Map<String, dynamic> payload) async {
    final data = await _api.post('/bookings/create/', data: payload);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> myBookings() async {
    final data = await _api.get('/bookings/');
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> bookingHistory() async {
    final data = await _api.get('/bookings/history/');
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> bookingDetail(int id) async {
    final data = await _api.get('/bookings/$id/');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> cancelBooking(int id) async {
    final data = await _api.post('/bookings/$id/cancel/');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> clientConfirmBooking(int id) async {
    final data = await _api.post('/bookings/$id/client-confirm/');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> coachSchedule({String? from, String? to}) async {
    final qp = <String, dynamic>{};
    if (from != null && from.isNotEmpty) qp['from'] = from;
    if (to != null && to.isNotEmpty) qp['to'] = to;
    final data = await _api.get('/bookings/coach/schedule/', queryParameters: qp.isEmpty ? null : qp);
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
