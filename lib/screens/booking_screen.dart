import 'package:flutter/material.dart';

import '../core/di/app_scope.dart';
import '../core/config/app_config.dart';
import '../theme/app_theme.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late Future<List<Map<String, dynamic>>> _courtsFuture;
  late Future<List<Map<String, dynamic>>> _bookingsFuture;
  late Future<List<Map<String, dynamic>>> _membershipsFuture;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _reloadAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _reloadAll() {
    _courtsFuture = AppScope.instance.bookingRepository.courts();
    _bookingsFuture = AppScope.instance.bookingRepository.myBookings();
    _membershipsFuture = AppScope.instance.membershipRepository.myMemberships();
  }

  void _openCourtSheet(Map<String, dynamic> court) {
    final courtId = (court['id'] as num?)?.toInt();
    if (courtId == null) return;

    final name = (court['name'] ?? 'Корт').toString();
    final courtType = (court['court_type'] ?? '').toString();
    final price = (court['price_per_hour'] ?? '—').toString();
    final description = (court['description'] ?? '').toString();
    final imageUrl = court['image']?.toString() ?? court['image_url']?.toString();
    final isActive = court['is_active'] == true;

    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay(hour: DateTime.now().hour + 1, minute: 0);
    int duration = 60;
    String paymentMethod = 'KASPI';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return DraggableScrollableSheet(
            initialChildSize: 0.88,
            maxChildSize: 0.92,
            minChildSize: 0.5,
            builder: (ctx, scrollCtrl) => Container(
              decoration: BoxDecoration(
                color: Theme.of(ctx).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: ListView(
                controller: scrollCtrl,
                padding: EdgeInsets.zero,
                children: [
                  // --- Photo ---
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    child: SizedBox(
                      height: 220,
                      width: double.infinity,
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl.startsWith('http') ? imageUrl : '${AppConfig.baseUrl}$imageUrl',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _courtPlaceholder(isDark),
                            )
                          : _courtPlaceholder(isDark),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isActive ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isActive ? 'Доступен' : 'Недоступен',
                                style: TextStyle(color: isActive ? Colors.green : Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (courtType.isNotEmpty)
                          Text(courtType, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(description, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                        ],
                        const SizedBox(height: 8),
                        Text('$price тг/час', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.primaryColor)),

                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 12),
                        const Text('Выберите дату и время', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: _outlinedSelect(
                                icon: Icons.calendar_today,
                                label: '${selectedDate.day}.${selectedDate.month.toString().padLeft(2, '0')}.${selectedDate.year}',
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: ctx,
                                    initialDate: selectedDate,
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now().add(const Duration(days: 60)),
                                  );
                                  if (picked != null) setSheetState(() => selectedDate = picked);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _outlinedSelect(
                                icon: Icons.access_time,
                                label: '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                                onTap: () async {
                                  final picked = await showTimePicker(context: ctx, initialTime: selectedTime);
                                  if (picked != null) setSheetState(() => selectedTime = picked);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text('Длительность: ', style: TextStyle(fontWeight: FontWeight.w600)),
                            ChoiceChip(
                              label: const Text('60 мин'),
                              selected: duration == 60,
                              onSelected: (_) => setSheetState(() => duration = 60),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('90 мин'),
                              selected: duration == 90,
                              onSelected: (_) => setSheetState(() => duration = 90),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('120 мин'),
                              selected: duration == 120,
                              onSelected: (_) => setSheetState(() => duration = 120),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: paymentMethod,
                          decoration: InputDecoration(
                            labelText: 'Способ оплаты',
                            filled: true,
                            fillColor: Colors.grey.withValues(alpha: 0.08),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'KASPI', child: Text('Kaspi')),
                            DropdownMenuItem(value: 'CARD', child: Text('Карта')),
                            DropdownMenuItem(value: 'CASH', child: Text('Наличные')),
                          ],
                          onChanged: (v) { if (v != null) setSheetState(() => paymentMethod = v); },
                        ),

                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: isActive ? () => _bookCourt(ctx, courtId, selectedDate, selectedTime, duration, paymentMethod) : null,
                            child: const Text('Забронировать', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _bookCourt(BuildContext ctx, int courtId, DateTime date, TimeOfDay time, int duration, String paymentMethod) async {
    final start = DateTime(date.year, date.month, date.day, time.hour, time.minute).toUtc();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(ctx);
    final payload = {
      'court': courtId,
      'start_time': start.toIso8601String(),
      'duration': duration,
      'payment_method': paymentMethod,
    };
    try {
      final preview = await AppScope.instance.bookingRepository.pricePreview({
        'court_id': courtId,
        'start_time': payload['start_time'],
        'duration': duration,
      });
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Подтвердить бронь'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Сумма: ${preview['total'] ?? '-'} тг'),
              if (preview['discount'] != null) Text('Скидка: ${preview['discount']}'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
            ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Подтвердить')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      final result = await AppScope.instance.bookingRepository.createBooking(payload);
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Бронь создана #${result['id'] ?? ''}')),
      );
      setState(_reloadAll);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _cancelBooking(Map<String, dynamic> booking) async {
    final id = (booking['id'] as num?)?.toInt();
    if (id == null) return;
    try {
      await AppScope.instance.bookingRepository.cancelBooking(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Бронирование отменено')));
      setState(_reloadAll);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _freezeOrUnfreeze(Map<String, dynamic> item) async {
    final id = (item['id'] as num?)?.toInt();
    if (id == null) return;
    final frozen = item['is_frozen'] == true;
    try {
      if (frozen) {
        await AppScope.instance.membershipRepository.unfreeze(id);
      } else {
        await AppScope.instance.membershipRepository.freeze(id);
      }
      if (!mounted) return;
      setState(_reloadAll);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? AppTheme.accentColor : AppTheme.primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Бронирование'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: activeColor,
          indicatorColor: activeColor,
          tabs: const [
            Tab(text: 'Корты'),
            Tab(text: 'Мои брони'),
            Tab(text: 'Абонементы'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildCourtsGrid(),
          _buildMyBookings(),
          _buildMemberships(),
        ],
      ),
    );
  }

  Widget _buildCourtsGrid() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _courtsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return _errorWidget(snapshot.error, () => setState(_reloadAll));
        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return const Center(child: Text('Кортов не найдено', style: TextStyle(color: Colors.grey)));
        }
        return RefreshIndicator(
          onRefresh: () async => setState(_reloadAll),
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.78,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) => _buildCourtCard(items[i]),
          ),
        );
      },
    );
  }

  Widget _buildCourtCard(Map<String, dynamic> court) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = (court['name'] ?? 'Корт').toString();
    final courtType = (court['court_type'] ?? '').toString();
    final price = (court['price_per_hour'] ?? '—').toString();
    final imageUrl = court['image']?.toString() ?? court['image_url']?.toString();
    final isActive = court['is_active'] == true;

    return GestureDetector(
      onTap: () => _openCourtSheet(court),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: SizedBox(
                width: double.infinity,
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl.startsWith('http') ? imageUrl : '${AppConfig.baseUrl}$imageUrl',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _courtPlaceholder(isDark),
                      )
                    : _courtPlaceholder(isDark),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (courtType.isNotEmpty) Text(courtType, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$price тг', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.primaryColor)),
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(color: isActive ? Colors.green : Colors.red, shape: BoxShape.circle),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyBookings() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _bookingsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return _errorWidget(snapshot.error, () => setState(_reloadAll));
        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.event_busy, size: 56, color: Colors.grey.withValues(alpha: 0.4)),
                const SizedBox(height: 8),
                const Text('Нет активных бронирований', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => setState(_reloadAll),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final b = items[i];
              final courtName = (b['court_name'] ?? b['court'] ?? '-').toString();
              final startTime = (b['start_time'] ?? '').toString();
              final status = (b['status'] ?? '').toString();
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 4, height: 44,
                      decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(courtName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(startTime, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          Text(status, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _cancelBooking(b),
                      child: const Text('Отмена', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMemberships() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _membershipsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return _errorWidget(snapshot.error, () => setState(_reloadAll));
        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return Center(
            child: ElevatedButton(
              onPressed: () async {
                final types = await AppScope.instance.membershipRepository.types();
                if (types.isEmpty || !mounted) return;
                final firstType = (types.first['id'] as num?)?.toInt();
                if (firstType == null) return;
                await AppScope.instance.membershipRepository.buy(firstType);
                if (!mounted) return;
                setState(_reloadAll);
              },
              child: const Text('Купить первый доступный абонемент'),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => setState(_reloadAll),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final m = items[i];
              final frozen = m['is_frozen'] == true;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text((m['membership_type_name'] ?? m['type_name'] ?? 'Абонемент').toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('До: ${m['end_date'] ?? '-'}  •  Часы: ${m['hours_remaining'] ?? '-'}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _freezeOrUnfreeze(m),
                      child: Text(frozen ? 'Разморозить' : 'Заморозить'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _errorWidget(Object? e, VoidCallback retry) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Ошибка загрузки'),
          const SizedBox(height: 8),
          Text(e.toString(), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: retry, child: const Text('Повторить')),
        ],
      ),
    );
  }
}

Widget _courtPlaceholder(bool isDark) {
  return Container(
    color: isDark ? Colors.grey[800] : Colors.grey[200],
    child: Center(
      child: Icon(Icons.sports_tennis, size: 40, color: isDark ? Colors.white38 : Colors.grey[400]),
    ),
  );
}

Widget _outlinedSelect({required IconData icon, required String label, required VoidCallback onTap}) {
  return OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 18),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
