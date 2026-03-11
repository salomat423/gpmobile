import 'package:flutter/material.dart';
import 'dart:async';
import '../core/di/app_scope.dart';
import '../theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> friend;
  final int? conversationId;

  const ChatScreen({super.key, required this.friend, this.conversationId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  int? _conversationId;
  int? _lastMessageId;
  int? _myUserId;
  bool _loading = true;
  bool _sending = false;
  Timer? _pollTimer;
  Timer? _readStatusTimer;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _readStatusTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initChat() async {
    try {
      final me = await AppScope.instance.authRepository.me();
      _myUserId = (me['id'] as num?)?.toInt();

      final friendId = (widget.friend['id'] as num?)?.toInt();

      if (widget.conversationId != null) {
        _conversationId = widget.conversationId;
      } else if (friendId != null) {
        final conv = await AppScope.instance.chatRepository.startConversation(friendId);
        _conversationId = (conv['id'] as num?)?.toInt();
      }

      if (_conversationId != null) {
        final msgs = await AppScope.instance.chatRepository.messages(_conversationId!, limit: 50);
        if (mounted) {
          setState(() => _applyMessages(msgs));
        }
        await AppScope.instance.chatRepository.markRead(_conversationId!);
        _startPolling();
        _startReadStatusRefresh();
      }
    } catch (_) {
      // пустой чат
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Polling новых сообщений — каждые 2 сек
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_conversationId == null) return;
      try {
        final msgs = await AppScope.instance.chatRepository
            .messages(_conversationId!, after: _lastMessageId, limit: 50);
        if (msgs.isNotEmpty && mounted) {
          final hadCompanionMessage = msgs.any((m) {
            final senderId = (m['sender_id'] as num?)?.toInt();
            return _myUserId != null && senderId != _myUserId;
          });
          setState(() {
            _applyMessages(msgs);
            // Если собеседник написал — он видел наши предыдущие сообщения
            if (hadCompanionMessage) {
              _markOurMessagesAsRead();
            }
          });
          await AppScope.instance.chatRepository.markRead(_conversationId!);
        }
      } catch (_) {}
    });
  }

  // Обновление статуса прочитанности — каждые 8 сек (полный refresh последних сообщений)
  void _startReadStatusRefresh() {
    _readStatusTimer?.cancel();
    _readStatusTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      if (_conversationId == null) return;
      try {
        final msgs = await AppScope.instance.chatRepository
            .messages(_conversationId!, limit: 50);
        if (msgs.isNotEmpty && mounted) {
          setState(() => _refreshReadStatus(msgs));
        }
      } catch (_) {}
    });
  }

  void _applyMessages(List<Map<String, dynamic>> raw) {
    for (final m in raw) {
      final id = (m['id'] as num?)?.toInt();
      if (id == null) continue;
      final existingIdx = _messages.indexWhere((e) => e['id'] == id);
      final createdAt = DateTime.tryParse((m['created_at'] ?? '').toString())?.toLocal();
      final senderId = (m['sender_id'] as num?)?.toInt();
      final isMe = _myUserId != null && senderId == _myUserId;
      final isRead = m['is_read'] == true;

      final entry = {
        'id': id,
        'text': (m['text'] ?? '').toString(),
        'isMe': isMe,
        'isRead': isRead,
        'time': createdAt != null
            ? '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}'
            : '',
        'date': createdAt != null
            ? '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}'
            : '',
      };

      if (existingIdx >= 0) {
        _messages[existingIdx] = entry;
      } else {
        _messages.add(entry);
      }
      if (_lastMessageId == null || id > _lastMessageId!) {
        _lastMessageId = id;
      }
    }
    // Сортировка по id (хронологический порядок)
    _messages.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
  }

  void _refreshReadStatus(List<Map<String, dynamic>> raw) {
    for (final m in raw) {
      final id = (m['id'] as num?)?.toInt();
      if (id == null) continue;
      final idx = _messages.indexWhere((e) => e['id'] == id);
      if (idx >= 0 && m['is_read'] == true) {
        _messages[idx] = {..._messages[idx], 'isRead': true};
      }
    }
  }

  void _markOurMessagesAsRead() {
    for (var i = 0; i < _messages.length; i++) {
      if (_messages[i]['isMe'] == true) {
        _messages[i] = {..._messages[i], 'isRead': true};
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _conversationId == null || _sending) return;

    setState(() => _sending = true);
    _messageController.clear();

    try {
      final res = await AppScope.instance.chatRepository.send(_conversationId!, text);
      final createdAt = DateTime.tryParse((res['created_at'] ?? '').toString())?.toLocal();
      final id = (res['id'] as num?)?.toInt();
      final senderId = (res['sender_id'] as num?)?.toInt();

      setState(() {
        _messages.add({
          'id': id,
          'text': (res['text'] ?? '').toString(),
          'isMe': _myUserId != null && senderId == _myUserId,
          'isRead': res['is_read'] == true,
          'time': createdAt != null
              ? '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}'
              : '',
          'date': createdAt != null
              ? '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}'
              : '',
        });
        if (id != null && (_lastMessageId == null || id > _lastMessageId!)) {
          _lastMessageId = id;
        }
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось отправить сообщение')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final friendName = (widget.friend['name'] ?? '').toString();
    final friendAvatar = (widget.friend['avatar'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
              backgroundImage: friendAvatar.isNotEmpty ? NetworkImage(friendAvatar) : null,
              onBackgroundImageError: friendAvatar.isNotEmpty ? (_, __) {} : null,
              child: friendAvatar.isEmpty
                  ? Text(
                      friendName.isNotEmpty ? friendName[0].toUpperCase() : '?',
                      style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(friendName.isNotEmpty ? friendName : 'Диалог',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Text('личные сообщения',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? const Center(
                          child: Text(
                            'Начните диалог с сообщением',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                          reverse: true,
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[_messages.length - 1 - index];
                            // Показывать дату-разделитель
                            final prevMsg = index < _messages.length - 1
                                ? _messages[_messages.length - 2 - index]
                                : null;
                            final showDate = prevMsg == null ||
                                _dayLabel(msg) != _dayLabel(prevMsg);
                            return Column(
                              children: [
                                if (showDate) _buildDateSeparator(msg),
                                _buildMessageBubble(msg, isDark),
                              ],
                            );
                          },
                        ),
                ),
                _buildMessageInput(isDark, theme),
              ],
            ),
    );
  }

  Widget _buildDateSeparator(Map<String, dynamic> msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Expanded(child: Divider(color: Colors.grey.withValues(alpha: 0.3))),
        const SizedBox(width: 8),
        Text(
          _dayLabel(msg),
          style: TextStyle(
              fontSize: 12, color: Colors.grey.withValues(alpha: 0.7)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: Colors.grey.withValues(alpha: 0.3))),
      ]),
    );
  }

  String _dayLabel(Map<String, dynamic> msg) {
    final date = (msg['date'] ?? '').toString();
    if (date.isEmpty) return '';
    final dt = DateTime.tryParse(date);
    if (dt == null) return date;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    if (msgDay == today) return 'Сегодня';
    if (msgDay == yesterday) return 'Вчера';
    const months = ['', 'янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
    final label = '${dt.day} ${months[dt.month]}';
    return dt.year != now.year ? '$label ${dt.year}' : label;
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isDark) {
    final isMe = msg['isMe'] == true;
    final isRead = msg['isRead'] == true;
    final text = (msg['text'] ?? '').toString();
    final time = (msg['time'] ?? '').toString();

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 2,
          bottom: 2,
          left: isMe ? 48 : 0,
          right: isMe ? 0 : 48,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isMe
              ? AppTheme.primaryColor
              : (isDark ? Colors.white12 : Colors.grey[200]),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: TextStyle(
                color: isMe
                    ? Colors.white
                    : (isDark ? Colors.white : Colors.black87),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe ? Colors.white60 : Colors.grey,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  _buildReadTick(isRead),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Один тик — отправлено, два синих тика — прочитано
  Widget _buildReadTick(bool isRead) {
    if (isRead) {
      return Stack(
        children: [
          const Icon(Icons.check_rounded, size: 13, color: Colors.lightBlueAccent),
          Padding(
            padding: const EdgeInsets.only(left: 5),
            child: const Icon(Icons.check_rounded, size: 13, color: Colors.lightBlueAccent),
          ),
        ],
      );
    } else {
      return Stack(
        children: [
          Icon(Icons.check_rounded, size: 13, color: Colors.white.withValues(alpha: 0.55)),
          Padding(
            padding: const EdgeInsets.only(left: 5),
            child: Icon(Icons.check_rounded, size: 13, color: Colors.white.withValues(alpha: 0.55)),
          ),
        ],
      );
    }
  }

  Widget _buildMessageInput(bool isDark, ThemeData theme) {
    return Container(
      padding: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: MediaQuery.of(context).padding.bottom + 10,
          top: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5))
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey[100],
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                maxLines: 4,
                minLines: 1,
                maxLength: 4000,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                    null,
                decoration: const InputDecoration(
                  hintText: 'Сообщение...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
                onSubmitted: (_) => _sendMessage(),
                textInputAction: TextInputAction.newline,
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: AppTheme.primaryColor,
            child: _sending
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
          ),
        ],
      ),
    );
  }
}
