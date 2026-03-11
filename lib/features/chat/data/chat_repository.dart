import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';

class ChatRepository {
  ChatRepository(ApiClient client) : _dio = client.dio;

  final Dio _dio;

  Future<List<Map<String, dynamic>>> conversations() async {
    final res = await _dio.get('/api/chat/conversations/');
    final data = res.data as List<dynamic>? ?? const [];
    return data.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> startConversation(int userId) async {
    final res = await _dio.post(
      '/api/chat/conversations/start/',
      data: {'user_id': userId},
    );
    return (res.data as Map).cast<String, dynamic>();
  }

  Future<List<Map<String, dynamic>>> messages(
    int conversationId, {
    int? after,
    int limit = 50,
  }) async {
    final query = <String, dynamic>{'limit': limit};
    if (after != null) query['after'] = after;
    final res = await _dio.get(
      '/api/chat/conversations/$conversationId/messages/',
      queryParameters: query,
    );
    final data = res.data as List<dynamic>? ?? const [];
    return data.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> send(int conversationId, String text) async {
    final res = await _dio.post(
      '/api/chat/conversations/$conversationId/send/',
      data: {'text': text},
    );
    return (res.data as Map).cast<String, dynamic>();
  }

  Future<int> markRead(int conversationId) async {
    final res = await _dio.post(
      '/api/chat/conversations/$conversationId/read/',
    );
    final data = (res.data as Map).cast<String, dynamic>();
    return (data['marked_read'] as num?)?.toInt() ?? 0;
  }

  Future<int> unreadCount() async {
    final res = await _dio.get('/api/chat/unread-count/');
    final data = (res.data as Map).cast<String, dynamic>();
    return (data['unread_count'] as num?)?.toInt() ?? 0;
  }
}

