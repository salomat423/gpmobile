import '../../../core/network/api_client.dart';

class ChatRepository {
  ChatRepository(this._api);
  final ApiClient _api;

  Future<List<Map<String, dynamic>>> conversations() async {
    final data = await _api.get('/chat/conversations/');
    if (data is List) return data.cast<Map<String, dynamic>>();
    return const [];
  }

  Future<Map<String, dynamic>> startConversation(int userId) async {
    final data = await _api.post('/chat/conversations/start/', data: {'user_id': userId});
    return (data as Map).cast<String, dynamic>();
  }

  Future<List<Map<String, dynamic>>> messages(
    int conversationId, {
    int? after,
    int limit = 50,
  }) async {
    final qp = <String, dynamic>{'limit': limit};
    if (after != null) qp['after'] = after;
    final data = await _api.get(
      '/chat/conversations/$conversationId/messages/',
      queryParameters: qp,
    );
    if (data is List) return data.cast<Map<String, dynamic>>();
    return const [];
  }

  Future<Map<String, dynamic>> send(int conversationId, String text) async {
    final data = await _api.post(
      '/chat/conversations/$conversationId/send/',
      data: {'text': text},
    );
    return (data as Map).cast<String, dynamic>();
  }

  Future<int> markRead(int conversationId) async {
    final data = await _api.post('/chat/conversations/$conversationId/read/');
    if (data is Map) {
      return ((data as Map).cast<String, dynamic>()['marked_read'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  Future<int> unreadCount() async {
    final data = await _api.get('/chat/unread-count/');
    if (data is Map) {
      return ((data as Map).cast<String, dynamic>()['unread_count'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }
}
