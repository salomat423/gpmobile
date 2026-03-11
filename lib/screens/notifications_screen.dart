import 'package:flutter/material.dart';

import '../core/di/app_scope.dart';
import '../theme/app_theme.dart';

class _NotifType {
  final IconData icon;
  final Color color;
  final String label;

  const _NotifType(this.icon, this.color, this.label);
}

const _typeMap = <String, _NotifType>{
  'BOOKING': _NotifType(Icons.event, Colors.blue, 'Бронирование'),
  'MEMBERSHIP': _NotifType(Icons.card_membership, Colors.teal, 'Абонемент'),
  'FRIEND': _NotifType(Icons.people, Colors.purple, 'Друзья'),
  'MATCH': _NotifType(Icons.sports_tennis, Colors.orange, 'Матч'),
  'LOBBY': _NotifType(Icons.groups, Colors.indigo, 'Лобби'),
  'PROMO': _NotifType(Icons.local_offer, Colors.pink, 'Акция'),
  'NEWS': _NotifType(Icons.newspaper, Colors.cyan, 'Новости'),
  'PAYMENT': _NotifType(Icons.payment, Colors.green, 'Оплата'),
  'SYSTEM': _NotifType(Icons.settings, Colors.grey, 'Система'),
};

String _timeAgo(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  final date = DateTime.tryParse(raw);
  if (date == null) return raw;
  final diff = DateTime.now().difference(date);
  if (diff.isNegative) return 'Только что';
  if (diff.inSeconds < 60) return 'Только что';
  if (diff.inMinutes < 60) return '${diff.inMinutes} мин назад';
  if (diff.inHours < 24) return '${diff.inHours} ч назад';
  if (diff.inDays == 1) return 'Вчера';
  if (diff.inDays < 7) return '${diff.inDays} дн назад';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} нед назад';
  return '${(diff.inDays / 30).floor()} мес назад';
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _items = [];
  int _unreadCount = 0;
  bool _loading = true;
  String? _errorMsg;

  String _selectedFilter = 'all';

  final Map<String, bool> _settingsToggles = {
    for (final k in _typeMap.keys) k: true,
    'dnd': false,
    'sound': true,
    'vibration': true,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      final repo = AppScope.instance.socialRepository;

      final bool? unreadParam =
          _selectedFilter == 'unread' ? true : null;
      final String? typeParam =
          (_selectedFilter != 'all' && _selectedFilter != 'unread')
              ? _selectedFilter
              : null;

      final results = await Future.wait([
        repo.notifications(unread: unreadParam, type: typeParam),
        repo.unreadCount(),
      ]);

      if (!mounted) return;
      setState(() {
        _items = results[0] as List<Map<String, dynamic>>;
        _unreadCount = results[1] as int;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = e.toString();
        _loading = false;
      });
    }
  }

  void _setFilter(String filter) {
    if (_selectedFilter == filter) return;
    _selectedFilter = filter;
    _load();
  }

  Future<void> _markRead(int id) async {
    await AppScope.instance.socialRepository.markRead(id);
    if (!mounted) return;
    _load();
  }

  Future<void> _markAllRead() async {
    await AppScope.instance.socialRepository.markAllRead();
    if (!mounted) return;
    _load();
  }

  Future<void> _delete(int id) async {
    await AppScope.instance.socialRepository.deleteNotification(id);
    if (!mounted) return;
    _load();
  }

  Future<void> _deleteAllRead() async {
    final readItems =
        _items.where((n) => n['is_read'] == true || n['is_read'] == 1);
    for (final n in readItems) {
      final id = (n['id'] as num?)?.toInt();
      if (id != null) {
        await AppScope.instance.socialRepository.deleteNotification(id);
      }
    }
    if (!mounted) return;
    _load();
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SettingsSheet(
        toggles: Map.of(_settingsToggles),
        onChanged: (updated) => setState(() => _settingsToggles.addAll(updated)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleText =
        _unreadCount > 0 ? 'Уведомления ($_unreadCount)' : 'Уведомления';

    return Scaffold(
      appBar: AppBar(
        title: Text(titleText),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Настройки уведомлений',
            onPressed: _openSettings,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == 'read_all') _markAllRead();
              if (v == 'delete_read') _deleteAllRead();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'read_all',
                child: Text('Прочитать все'),
              ),
              PopupMenuItem(
                value: 'delete_read',
                child: Text('Удалить прочитанные'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = <String, String>{
      'all': 'Все',
      'unread': 'Непрочитанные',
      ..._typeMap.map((k, v) => MapEntry(k, v.label)),
    };

    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final key = filters.keys.elementAt(i);
          final label = filters.values.elementAt(i);
          final selected = _selectedFilter == key;
          return ChoiceChip(
            label: Text(label),
            selected: selected,
            selectedColor: AppTheme.primaryColor,
            labelStyle: TextStyle(
              color: selected ? Colors.white : AppTheme.textPrimary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 13,
            ),
            backgroundColor: AppTheme.surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: selected
                    ? AppTheme.primaryColor
                    : Colors.grey.shade300,
              ),
            ),
            onSelected: (_) => _setFilter(key),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMsg != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_errorMsg!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _load,
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_off_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Нет уведомлений',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: _items.length,
        itemBuilder: (context, i) => _NotificationCard(
          data: _items[i],
          onMarkRead: _markRead,
          onDelete: _delete,
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final Future<void> Function(int id) onMarkRead;
  final Future<void> Function(int id) onDelete;

  const _NotificationCard({
    required this.data,
    required this.onMarkRead,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final id = (data['id'] as num?)?.toInt();
    final title = (data['title'] ?? '').toString();
    final body = (data['body'] ?? '').toString();
    final type = (data['notification_type'] ?? data['type'] ?? 'SYSTEM').toString().toUpperCase();
    final isRead = data['is_read'] == true || data['is_read'] == 1;
    final createdAt = (data['created_at'] ?? '').toString();
    final actionUrl = (data['action_url'] ?? '').toString();
    final actionType = (data['action_type'] ?? '').toString();
    final hasAction = actionUrl.isNotEmpty && actionType.isNotEmpty;

    final nt = _typeMap[type] ?? const _NotifType(Icons.notifications, Colors.grey, 'Другое');

    Widget card = Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: isRead
            ? null
            : Border(left: BorderSide(color: nt.color, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: nt.color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(nt.icon, color: nt.color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                isRead ? FontWeight.w400 : FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.access_time,
                          size: 13, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Text(
                        _timeAgo(createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const Spacer(),
                      if (hasAction)
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Переход к: $actionUrl'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Перейти',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(Icons.arrow_forward_ios,
                                    size: 11, color: AppTheme.primaryColor),
                              ],
                            ),
                          ),
                        ),
                      if (!isRead && id != null)
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => onMarkRead(id),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            child: Icon(Icons.done,
                                size: 18, color: Colors.grey.shade500),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (id == null) return card;

    return Dismissible(
      key: ValueKey(id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Удалить уведомление?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Удалить',
                    style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => onDelete(id),
      child: card,
    );
  }
}

class _SettingsSheet extends StatefulWidget {
  final Map<String, bool> toggles;
  final ValueChanged<Map<String, bool>> onChanged;

  const _SettingsSheet({required this.toggles, required this.onChanged});

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late Map<String, bool> _t;

  static const _personalKeys = [
    'booking',
    'social',
    'achievement',
    'subscription',
    'financial',
  ];
  static const _generalKeys = ['news', 'tournament', 'promo', 'system'];

  @override
  void initState() {
    super.initState();
    _t = Map.of(widget.toggles);
  }

  void _applyProfile(Map<String, bool> overrides) {
    setState(() => _t.addAll(overrides));
  }

  void _profileAll() => _applyProfile({
        for (final k in _typeMap.keys) k: true,
        'dnd': false,
        'sound': true,
        'vibration': true,
      });

  void _profileImportant() => _applyProfile({
        for (final k in _typeMap.keys)
          k: ['BOOKING', 'PAYMENT', 'MEMBERSHIP'].contains(k),
        'dnd': false,
        'sound': true,
        'vibration': true,
      });

  void _profileMinimal() => _applyProfile({
        for (final k in _typeMap.keys)
          k: ['BOOKING', 'PAYMENT'].contains(k),
        'dnd': false,
        'sound': false,
        'vibration': false,
      });

  void _profileDnd() => _applyProfile({
        for (final k in _typeMap.keys) k: false,
        'dnd': true,
        'sound': false,
        'vibration': false,
      });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
            child: Row(
              children: [
                const Text(
                  'Настройки уведомлений',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    widget.onChanged(_t);
                    Navigator.pop(context);
                  },
                  child: const Text('Готово'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          _buildProfiles(),
          const Divider(height: 1),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                _sectionHeader('Личные уведомления'),
                for (final k in _personalKeys) _typeTile(k),
                _sectionHeader('Общие уведомления'),
                for (final k in _generalKeys) _typeTile(k),
                _sectionHeader('Расширенные настройки'),
                _switchTile(
                  icon: Icons.do_not_disturb_on_outlined,
                  label: 'Режим «Не беспокоить»',
                  key: 'dnd',
                ),
                _switchTile(
                  icon: Icons.volume_up_outlined,
                  label: 'Звуковые оповещения',
                  key: 'sound',
                ),
                _switchTile(
                  icon: Icons.vibration,
                  label: 'Вибрация',
                  key: 'vibration',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfiles() {
    final profiles = <(String, VoidCallback)>[
      ('Все включено', _profileAll),
      ('Только важное', _profileImportant),
      ('Минимум', _profileMinimal),
      ('Не беспокоить', _profileDnd),
    ];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        itemCount: profiles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (label, action) = profiles[i];
          return ActionChip(
            label: Text(label, style: const TextStyle(fontSize: 13)),
            backgroundColor: AppTheme.surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            onPressed: action,
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _typeTile(String typeKey) {
    final nt = _typeMap[typeKey]!;
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      secondary: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: nt.color.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(nt.icon, color: nt.color, size: 18),
      ),
      title: Text(nt.label, style: const TextStyle(fontSize: 15)),
      value: _t[typeKey] ?? true,
      activeColor: AppTheme.primaryColor,
      onChanged: (v) => setState(() => _t[typeKey] = v),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String label,
    required String key,
  }) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      secondary: Icon(icon, color: AppTheme.textSecondary),
      title: Text(label, style: const TextStyle(fontSize: 15)),
      value: _t[key] ?? false,
      activeColor: AppTheme.primaryColor,
      onChanged: (v) => setState(() => _t[key] = v),
    );
  }
}
