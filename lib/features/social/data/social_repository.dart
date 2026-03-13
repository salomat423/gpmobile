import '../../../core/network/api_client.dart';

class SocialRepository {
  SocialRepository(this._api);
  final ApiClient _api;

  Future<List<Map<String, dynamic>>> listLobbies({
    String? status,
    String? format,
    Object? elo,
  }) async {
    final qp = <String, dynamic>{};
    if (status != null && status.isNotEmpty) qp['status'] = status;
    if (format != null && format.isNotEmpty) qp['format'] = format;
    if (elo != null) qp['elo'] = elo;
    final data = await _api.get('/lobby/', queryParameters: qp.isEmpty ? null : qp);
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> createLobby(Map<String, dynamic> payload) async {
    final data = await _api.post('/lobby/', data: payload);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> lobbyDetail(int id) async {
    final data = await _api.get('/lobby/$id/');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> joinLobby(int id) async {
    final data = await _api.post('/lobby/$id/join/');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> leaveLobby(int id) async {
    final data = await _api.post('/lobby/$id/leave/');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> myLobbies() async {
    final data = await _api.get('/lobby/my/');
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> lobbyProposals(int id) async {
    final data = await _api.get('/lobby/$id/proposals/');
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> propose(int id, Map<String, dynamic> payload) async {
    final data = await _api.post('/lobby/$id/proposals/', data: payload);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> vote(int id, int proposalId) async {
    final data = await _api.post('/lobby/$id/proposals/$proposalId/vote/');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> acceptProposal(int id, int proposalId) async {
    final data = await _api.post('/lobby/$id/proposals/$proposalId/accept/');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> assignTeams(int id, Map<String, dynamic> teams) async {
    final data = await _api.post('/lobby/$id/assign-teams/', data: {'teams': teams});
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> bookLobby(int id) async {
    final data = await _api.post('/lobby/$id/book/');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> myExtras(int id) async {
    final data = await _api.get('/lobby/$id/my-extras/');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> addMyExtras(int id, List<Map<String, dynamic>> services) async {
    final data = await _api.post('/lobby/$id/my-extras/', data: {'services': services});
    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> removeMyExtra(int id, int extraId) async {
    await _api.delete('/lobby/$id/my-extras/$extraId/');
  }

  Future<Map<String, dynamic>> payShare(
    int id,
    String paymentMethod, {
    bool? useMembership,
  }) async {
    final payload = <String, dynamic>{'payment_method': paymentMethod};
    if (useMembership != null) payload['use_membership'] = useMembership;
    final data = await _api.post('/lobby/$id/pay-share/', data: payload);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> paymentStatus(int id) async {
    final data = await _api.get('/lobby/$id/payment-status/');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> closeLobby(int id) async {
    final data = await _api.post('/lobby/$id/close/');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> friends() async {
    final data = await _api.get('/friends/');
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> sendFriendRequest(int toUserId) async {
    final data = await _api.post('/friends/send/', data: {'to_user_id': toUserId});
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> incomingRequests() async {
    final data = await _api.get('/friends/requests/');
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> outgoingRequests() async {
    final data = await _api.get('/friends/requests/outgoing/');
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> respondRequest(int requestId, String action) async {
    final data = await _api.post('/friends/respond/', data: {'request_id': requestId, 'action': action});
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> cancelRequest(int requestId) async {
    final data = await _api.post('/friends/cancel/', data: {'request_id': requestId});
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> removeFriend(int userId) async {
    final data = await _api.post('/friends/remove/', data: {'user_id': userId});
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> friendsFeed({int limit = 20}) async {
    final data = await _api.get('/friends/feed/', queryParameters: {'limit': limit});
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> matches({bool all = false, String? status}) async {
    final qp = <String, dynamic>{};
    if (all) qp['all'] = 1;
    if (status != null) qp['status'] = status;
    final data = await _api.get(
      '/gamification/matches/',
      queryParameters: qp.isEmpty ? null : qp,
    );
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> confirmMatch(int matchId, {required bool accept}) async {
    final data = await _api.post(
      '/gamification/matches/$matchId/confirm/',
      data: {'accept': accept},
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> createMatch({
    required List<int> teamA,
    required List<int> teamB,
    required String score,
    required String winnerTeam,
    int? court,
  }) async {
    final payload = <String, dynamic>{
      'team_a': teamA,
      'team_b': teamB,
      'score': score,
      'winner_team': winnerTeam,
    };
    if (court != null) payload['court'] = court;
    final data = await _api.post('/gamification/matches/create/', data: payload);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> leaderboard({int limit = 50}) async {
    final data = await _api.get('/gamification/leaderboard/', queryParameters: {'limit': limit});
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> notifications({bool? unread, String? type}) async {
    final qp = <String, dynamic>{};
    if (unread != null) qp['unread'] = unread;
    if (type != null && type.isNotEmpty) qp['type'] = type;
    final data = await _api.get('/notifications/', queryParameters: qp.isEmpty ? null : qp);
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<int> unreadCount() async {
    final data = await _api.get('/notifications/unread-count/');
    return (Map<String, dynamic>.from(data as Map)['unread_count'] as num?)?.toInt() ?? 0;
  }

  Future<Map<String, dynamic>> markRead(int id) async {
    final data = await _api.post('/notifications/$id/read/');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> markAllRead() async {
    final data = await _api.post('/notifications/read-all/');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> deleteNotification(int id) async {
    await _api.delete('/notifications/$id/');
  }
}
