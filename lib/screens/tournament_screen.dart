import 'package:flutter/material.dart';

import '../core/di/app_scope.dart';
import '../theme/app_theme.dart';

class TournamentScreen extends StatefulWidget {
  const TournamentScreen({super.key});

  @override
  State<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late Future<List<Map<String, dynamic>>> _allFuture;
  late Future<List<Map<String, dynamic>>> _myFuture;

  String _statusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _reload();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _reload() {
    _allFuture = AppScope.instance.tournamentRepository
        .list()
        .catchError((_) => <Map<String, dynamic>>[]);
    _myFuture = AppScope.instance.tournamentRepository
        .my()
        .catchError((_) => <Map<String, dynamic>>[]);
  }

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> items) {
    if (_statusFilter == 'ALL') return items;
    return items.where((t) {
      final s = (t['status'] ?? '').toString().toUpperCase();
      return s == _statusFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Турниры'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppTheme.accentColor,
          labelColor: isDark ? AppTheme.accentColor : AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          tabs: const [
            Tab(text: 'Все турниры'),
            Tab(text: 'Мои турниры'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildAllTab(theme, isDark),
          _buildMyTab(theme, isDark),
        ],
      ),
    );
  }

  // ─── All tournaments ────────────────────────────────────────

  Widget _buildAllTab(ThemeData theme, bool isDark) {
    return Column(
      children: [
        _buildFilterRow(isDark),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _allFuture,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return _emptyState(
                    'Не удалось загрузить турниры', Icons.wifi_off_rounded);
              }
              final items = _applyFilter(snap.data ?? []);
              if (items.isEmpty) {
                return _emptyState(
                    'Турниров пока нет', Icons.emoji_events_outlined);
              }
              return RefreshIndicator(
                onRefresh: () async => setState(_reload),
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: items.length,
                  itemBuilder: (_, i) =>
                      _TournamentCard(item: items[i], onTap: () => _openDetail(items[i])),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterRow(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _chip('ALL', 'Все', isDark),
          const SizedBox(width: 8),
          _chip('REGISTRATION_OPEN', 'Регистрация', isDark),
          const SizedBox(width: 8),
          _chip('UPCOMING', 'Скоро', isDark),
          const SizedBox(width: 8),
          _chip('IN_PROGRESS', 'Идёт', isDark),
          const SizedBox(width: 8),
          _chip('COMPLETED', 'Завершён', isDark),
        ],
      ),
    );
  }

  Widget _chip(String value, String label, bool isDark) {
    final selected = _statusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _statusFilter = value),
      selectedColor: AppTheme.primaryColor,
      backgroundColor:
          isDark ? Colors.white10 : Colors.grey.shade100,
      labelStyle: TextStyle(
        color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  // ─── My tournaments ─────────────────────────────────────────

  Widget _buildMyTab(ThemeData theme, bool isDark) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _myFuture,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _emptyState(
              'Не удалось загрузить', Icons.wifi_off_rounded);
        }
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return _emptyState(
              'Вы пока не участвуете\nни в одном турнире',
              Icons.emoji_events_outlined);
        }
        return RefreshIndicator(
          onRefresh: () async => setState(_reload),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: items.length,
            itemBuilder: (_, i) =>
                _TournamentCard(item: items[i], onTap: () => _openDetail(items[i])),
          ),
        );
      },
    );
  }

  Widget _emptyState(String text, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  // ─── Detail sheet ───────────────────────────────────────────

  void _openDetail(Map<String, dynamic> tournament) {
    final id = tournament['id'];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TournamentDetailSheet(
        tournament: tournament,
        onRegister: id != null
            ? () async {
                Navigator.pop(context);
                await _doRegister(id is int ? id : int.tryParse(id.toString()) ?? 0);
              }
            : null,
        onCancel: id != null
            ? () async {
                Navigator.pop(context);
                await _doCancelRegistration(id is int ? id : int.tryParse(id.toString()) ?? 0);
              }
            : null,
      ),
    );
  }

  Future<void> _doRegister(int id) async {
    try {
      await AppScope.instance.tournamentRepository.register(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Вы зарегистрированы на турнир!')),
      );
      setState(_reload);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  Future<void> _doCancelRegistration(int id) async {
    try {
      await AppScope.instance.tournamentRepository.cancelRegistration(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Регистрация отменена')),
      );
      setState(_reload);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }
}

// ═══════════════════════════════════════════════════════════════
//  Tournament card
// ═══════════════════════════════════════════════════════════════

class _TournamentCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const _TournamentCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final name = (item['name'] ?? item['title'] ?? 'Турнир').toString();
    final status = (item['status'] ?? '').toString().toUpperCase();
    final sportType = (item['sport_type'] ?? '').toString();
    final format = (item['format'] ?? item['play_format'] ?? '').toString();
    final dateStr = (item['start_date'] ?? item['date'] ?? '').toString();
    final entryFee = item['entry_fee'];
    final maxParticipants = item['max_participants'];
    final currentParticipants = item['current_participants'] ?? item['participants_count'] ?? 0;
    final imageUrl = (item['image'] ?? item['image_url'] ?? '').toString();
    final prizePool = item['prize_pool'];
    final isRegistered = item['is_registered'] == true;

    final statusInfo = _statusMeta(status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header image / gradient
            _buildCardHeader(imageUrl, statusInfo, isDark, isRegistered),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 10),

                  // Info pills row
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (dateStr.isNotEmpty)
                        _infoPill(Icons.calendar_today_rounded, _formatDate(dateStr), isDark),
                      if (sportType.isNotEmpty)
                        _infoPill(_sportIcon(sportType), _sportLabel(sportType), isDark),
                      if (format.isNotEmpty)
                        _infoPill(Icons.group_rounded, _formatLabel(format), isDark),
                      if (maxParticipants != null)
                        _infoPill(
                          Icons.people_alt_rounded,
                          '$currentParticipants / $maxParticipants',
                          isDark,
                        ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Bottom row: price / prize
                  Row(
                    children: [
                      if (entryFee != null) ...[
                        Text(
                          '${_fmtNum(entryFee)} тг',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'вступительный',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                      const Spacer(),
                      if (prizePool != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.emoji_events_rounded, size: 14, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(
                                '${_fmtNum(prizePool)} тг',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.amber,
                                ),
                              ),
                            ],
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
  }

  Widget _buildCardHeader(
      String imageUrl, _StatusMeta meta, bool isDark, bool isRegistered) {
    return SizedBox(
      height: 120,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl.isNotEmpty)
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _gradientFallback(meta),
            )
          else
            _gradientFallback(meta),

          // Status badge
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: meta.color.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                meta.label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),

          if (isRegistered)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.green.shade700.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 13, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'Участвую',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _gradientFallback(_StatusMeta meta) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, meta.color.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.emoji_events_rounded, size: 44, color: Colors.white38),
      ),
    );
  }

  Widget _infoPill(IconData icon, String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey.shade700)),
        ],
      ),
    );
  }

  static _StatusMeta _statusMeta(String status) {
    switch (status) {
      case 'REGISTRATION_OPEN':
        return _StatusMeta('Регистрация открыта', Colors.green);
      case 'UPCOMING':
        return _StatusMeta('Скоро', Colors.blue);
      case 'IN_PROGRESS':
        return _StatusMeta('Идёт сейчас', Colors.orange);
      case 'COMPLETED':
        return _StatusMeta('Завершён', Colors.grey);
      case 'CANCELLED':
        return _StatusMeta('Отменён', Colors.red);
      default:
        return _StatusMeta('Турнир', AppTheme.primaryColor);
    }
  }

  static String _formatDate(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    const months = [
      '', 'янв', 'фев', 'мар', 'апр', 'май', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }

  static String _fmtNum(dynamic v) {
    final n = double.tryParse(v.toString()) ?? 0;
    if (n == n.roundToDouble()) return n.toInt().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ');
    return n.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ');
  }

  static IconData _sportIcon(String s) {
    switch (s.toUpperCase()) {
      case 'PADEL':
        return Icons.sports_tennis_rounded;
      case 'SQUASH':
        return Icons.sports_handball_rounded;
      case 'PING_PONG':
        return Icons.sports_cricket_rounded;
      default:
        return Icons.sports_rounded;
    }
  }

  static String _sportLabel(String s) {
    switch (s.toUpperCase()) {
      case 'PADEL':
        return 'Падел';
      case 'SQUASH':
        return 'Сквош';
      case 'PING_PONG':
        return 'Пинг-понг';
      default:
        return s;
    }
  }

  static String _formatLabel(String f) {
    switch (f.toUpperCase()) {
      case 'ONE_VS_ONE':
        return '1 на 1';
      case 'TWO_VS_TWO':
        return '2 на 2';
      case 'ROUND_ROBIN':
        return 'Круговой';
      case 'SINGLE_ELIMINATION':
        return 'Олимпийская';
      case 'DOUBLE_ELIMINATION':
        return 'Двойное выбывание';
      default:
        return f;
    }
  }
}

class _StatusMeta {
  final String label;
  final Color color;
  _StatusMeta(this.label, this.color);
}

// ═══════════════════════════════════════════════════════════════
//  Detail bottom sheet
// ═══════════════════════════════════════════════════════════════

class _TournamentDetailSheet extends StatelessWidget {
  final Map<String, dynamic> tournament;
  final VoidCallback? onRegister;
  final VoidCallback? onCancel;

  const _TournamentDetailSheet({
    required this.tournament,
    this.onRegister,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final name = (tournament['name'] ?? tournament['title'] ?? 'Турнир').toString();
    final description = (tournament['description'] ?? '').toString();
    final status = (tournament['status'] ?? '').toString().toUpperCase();
    final sportType = (tournament['sport_type'] ?? '').toString();
    final format = (tournament['format'] ?? tournament['play_format'] ?? '').toString();
    final startDate = (tournament['start_date'] ?? tournament['date'] ?? '').toString();
    final endDate = (tournament['end_date'] ?? '').toString();
    final entryFee = tournament['entry_fee'];
    final prizePool = tournament['prize_pool'];
    final maxP = tournament['max_participants'];
    final curP = tournament['current_participants'] ?? tournament['participants_count'] ?? 0;
    final rules = (tournament['rules'] ?? '').toString();
    final location = (tournament['location'] ?? tournament['venue'] ?? '').toString();
    final imageUrl = (tournament['image'] ?? tournament['image_url'] ?? '').toString();
    final isRegistered = tournament['is_registered'] == true;
    final registrationOpen = status == 'REGISTRATION_OPEN';
    final meta = _TournamentCard._statusMeta(status);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  // Image
                  if (imageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        imageUrl,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    )
                  else
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.primaryColor, meta.color],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Icon(Icons.emoji_events_rounded, size: 48, color: Colors.white38),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Status chip
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: meta.color,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        meta.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Title
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Info grid
                  _detailGrid(isDark, sportType, format, startDate, endDate,
                      maxP, curP, location),

                  // Prize & Fee
                  if (entryFee != null || prizePool != null) ...[
                    const SizedBox(height: 16),
                    _prizeSection(isDark, entryFee, prizePool),
                  ],

                  // Description
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Описание',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                      ),
                    ),
                  ],

                  // Rules
                  if (rules.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Правила',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      rules,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),

                  // Action buttons
                  if (registrationOpen && !isRegistered && onRegister != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onRegister,
                        icon: const Icon(Icons.how_to_reg_rounded),
                        label: Text(
                          entryFee != null
                              ? 'Зарегистрироваться  •  ${_TournamentCard._fmtNum(entryFee)} тг'
                              : 'Зарегистрироваться',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),

                  if (isRegistered && registrationOpen && onCancel != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onCancel,
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Отменить регистрацию'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],

                  if (isRegistered)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, color: Colors.green.shade600, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Вы зарегистрированы',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailGrid(bool isDark, String sportType, String format,
      String startDate, String endDate, dynamic maxP, dynamic curP, String location) {
    final items = <_GridItem>[];
    if (startDate.isNotEmpty) {
      items.add(_GridItem(Icons.calendar_today_rounded, 'Начало', _TournamentCard._formatDate(startDate)));
    }
    if (endDate.isNotEmpty) {
      items.add(_GridItem(Icons.event_rounded, 'Окончание', _TournamentCard._formatDate(endDate)));
    }
    if (sportType.isNotEmpty) {
      items.add(_GridItem(
        _TournamentCard._sportIcon(sportType),
        'Вид спорта',
        _TournamentCard._sportLabel(sportType),
      ));
    }
    if (format.isNotEmpty) {
      items.add(_GridItem(Icons.group_rounded, 'Формат', _TournamentCard._formatLabel(format)));
    }
    if (maxP != null) {
      items.add(_GridItem(Icons.people_alt_rounded, 'Участники', '$curP / $maxP'));
    }
    if (location.isNotEmpty) {
      items.add(_GridItem(Icons.location_on_rounded, 'Место', location));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.map((g) => _gridCell(isDark, g)).toList(),
    );
  }

  Widget _gridCell(bool isDark, _GridItem g) {
    return Container(
      width: 155,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(g.icon, size: 18, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(g.title, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                Text(
                  g.value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _prizeSection(bool isDark, dynamic entryFee, dynamic prizePool) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [Colors.amber.shade900.withValues(alpha: 0.3), Colors.orange.shade900.withValues(alpha: 0.2)]
              : [Colors.amber.shade50, Colors.orange.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.amber.withValues(alpha: isDark ? 0.3 : 0.4),
        ),
      ),
      child: Row(
        children: [
          if (entryFee != null)
            Expanded(
              child: Column(
                children: [
                  const Icon(Icons.confirmation_number_rounded, color: Colors.amber, size: 22),
                  const SizedBox(height: 4),
                  Text(
                    '${_TournamentCard._fmtNum(entryFee)} тг',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.amber),
                  ),
                  Text('Взнос', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
          if (entryFee != null && prizePool != null)
            Container(
              width: 1,
              height: 40,
              color: Colors.amber.withValues(alpha: 0.3),
            ),
          if (prizePool != null)
            Expanded(
              child: Column(
                children: [
                  const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 22),
                  const SizedBox(height: 4),
                  Text(
                    '${_TournamentCard._fmtNum(prizePool)} тг',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.amber),
                  ),
                  Text('Призовой фонд', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GridItem {
  final IconData icon;
  final String title;
  final String value;
  _GridItem(this.icon, this.title, this.value);
}
