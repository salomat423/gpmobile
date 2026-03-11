import 'package:flutter/material.dart';
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
  final List<Map<String, dynamic>> _messages = [];
  int? _conversationId;
  int? _lastMessageId;
  int? _myUserId;
  bool _loading = true;
  bool _sending = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageController.dispose();
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
        _applyNewMessages(msgs);
        await AppScope.instance.chatRepository.markRead(_conversationId!);
        _startPolling();
      }
    } catch (_) {
      // ignore for now, UI покажет просто пустой чат
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_conversationId == null) return;
      try {
        final msgs = await AppScope.instance.chatRepository
            .messages(_conversationId!, after: _lastMessageId, limit: 50);
        if (msgs.isNotEmpty && mounted) {
          setState(() {
            _applyNewMessages(msgs);
          });
          await AppScope.instance.chatRepository.markRead(_conversationId!);
        }
      } catch (_) {
        // тихо игнорим ошибки polling
      }
    });
  }

  void _applyNewMessages(List<Map<String, dynamic>> raw) {
    for (final m in raw) {
      final id = (m['id'] as num?)?.toInt();
      if (id == null) continue;
      if (_messages.any((e) => e['id'] == id)) continue;
      final createdAt = DateTime.tryParse((m['created_at'] ?? '').toString())?.toLocal();
      final senderId = (m['sender_id'] as num?)?.toInt();
      _messages.add({
        'id': id,
        'text': (m['text'] ?? '').toString(),
        'isMe': _myUserId != null && senderId == _myUserId,
        'time': createdAt != null
            ? '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}'
            : '',
      });
      _lastMessageId = id;
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _conversationId == null || _sending) return;

    setState(() {
      _sending = true;
    });
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
          'time': createdAt != null
              ? '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}'
              : '',
        });
        if (id != null) _lastMessageId = id;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось отправить сообщение')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: NetworkImage(widget.friend['avatar']),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.friend['name'],
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(
                  widget.friend['status'] == 'online' ? 'В сети' : 'Был(а) недавно',
                  style: TextStyle(fontSize: 11, color: widget.friend['status'] == 'online' ? AppTheme.accentColor : Colors.grey),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.info_outline), onPressed: () {}),
        ],
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
                          padding: const EdgeInsets.all(16),
                          reverse: true, // Последние сообщения внизу
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[_messages.length - 1 - index];
                            return _buildMessageBubble(msg, isDark);
                          },
                        ),
                ),
                _buildMessageInput(isDark, theme),
              ],
            ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isDark) {
    final isMe = msg['isMe'];
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe
              ? AppTheme.primaryColor
              : (isDark ? Colors.white10 : Colors.grey[200]),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              msg['text'],
              style: TextStyle(
                color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              msg['time'],
              style: TextStyle(
                fontSize: 10,
                color: isMe ? Colors.white60 : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput(bool isDark, ThemeData theme) {
    return Container(
      padding: EdgeInsets.only(
          left: 16, right: 16, bottom: MediaQuery.of(context).padding.bottom + 10, top: 10
      ),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))
        ],
      ),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryColor), onPressed: () {}),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey[100],
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'Сообщение...',
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: AppTheme.primaryColor,
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}